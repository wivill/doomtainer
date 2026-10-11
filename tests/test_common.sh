#!/bin/bash
# Tests for lib/common.sh: launch-argument parsing, the mod manifest check and
# its hash cache, the engine version check, and save syncing against a local
# bare repo standing in for GitHub. No engine, Docker or network needed, so it
# runs on the Linux, macOS and Windows (Git Bash) CI runners alike.
#
# Usage: tests/test_common.sh

# The library is sourced from a computed path (SC1090), and the `bash -c`
# snippets get their values as positional arguments on purpose (SC2016).
# shellcheck disable=SC1090,SC2016

set -uo pipefail

LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   - $1"; }
not_ok() { fail=$((fail + 1)); echo "FAIL - $1"; }
check() {  # description, command...
    local desc="$1"; shift
    if "$@" >"$WORK/out" 2>&1; then ok "$desc"; else not_ok "$desc"; sed 's/^/       /' "$WORK/out"; fi
}
check_fails() {  # description, command...
    local desc="$1"; shift
    if "$@" >"$WORK/out" 2>&1; then not_ok "$desc (succeeded)"; else ok "$desc"; fi
}

# Run a command inside a fresh subshell with the library loaded, from the
# fake repo ($REPO). die() exits, so the subshell keeps it contained.
in_repo() {
    (cd "$REPO" && . "$LIB" && "$@")
}

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# --- A fake doomtainer checkout ----------------------------------------------
REPO="$WORK/repo"
mkdir -p "$REPO/original_wads" "$REPO/mods/sub" "$REPO/engines/uzdoom"
cat > "$REPO/docker-compose.yml" <<'EOF'
services:
  uzdoom:
    command: >
      -iwad /games/iwads/DOOM.WAD
      -file
      /games/mods/a.pk3
      /games/mods/sub/b.wad
    other: value
EOF
echo 'ARG UZDOOM_VERSION=5.0.3' > "$REPO/engines/uzdoom/Dockerfile"
echo doom > "$REPO/original_wads/DOOM.WAD"
echo a > "$REPO/mods/a.pk3"
echo b > "$REPO/mods/sub/b.wad"

expected_args="-iwad
/x/original_wads/DOOM.WAD
-file
/x/mods/a.pk3
/x/mods/sub/b.wad"
check "compose_args maps container paths to the given prefix" \
    test "$(in_repo compose_args /x)" = "$expected_args"

check "compose_args tolerates CRLF line endings" bash -c '
    cd "$1" && sed "s/\$/\r/" docker-compose.yml > dc && mv dc docker-compose.yml &&
    . "$2" && test "$(compose_args /x)" = "$3"' _ "$REPO" "$LIB" "$expected_args"

check "game_files lists repo-relative game files" \
    test "$(in_repo game_files)" = "$(printf 'original_wads/DOOM.WAD\nmods/a.pk3\nmods/sub/b.wad')"

# --- Mod manifest ------------------------------------------------------------
write_manifest() {
    (cd "$REPO" && . "$LIB" && {
        echo "# comment"
        for f in original_wads/DOOM.WAD mods/a.pk3 mods/sub/b.wad; do
            printf '%s  %s\n' "$(sha256_of "$f")" "$f"
        done
    } > mods.sha256)
}
write_manifest
check "matching files pass" in_repo check_game_files
check "the hash cache was written" test -s "$REPO/.mods-verified"
check "a second run (cached) still passes" in_repo check_game_files

echo changed > "$REPO/mods/a.pk3"
check_fails "a changed mod fails (cache invalidated by size/mtime)" in_repo check_game_files
check "DOOMTAINER_SKIP_CHECKS=1 skips the mod check" \
    env DOOMTAINER_SKIP_CHECKS=1 bash -c 'cd "$1" && . "$2" && check_game_files' _ "$REPO" "$LIB"
echo a > "$REPO/mods/a.pk3"
write_manifest

rm "$REPO/mods/sub/b.wad"
check_fails "a missing mod fails" in_repo check_game_files
echo b > "$REPO/mods/sub/b.wad"

echo "$(printf '0%.0s' {1..64})  mods/old.pk3" >> "$REPO/mods.sha256"
check_fails "a manifest entry the command no longer loads fails" in_repo check_game_files
write_manifest

grep -v 'b.wad' "$REPO/mods.sha256" > "$WORK/m" && mv "$WORK/m" "$REPO/mods.sha256"
check_fails "a loaded file missing from the manifest fails" in_repo check_game_files
write_manifest

rm "$REPO/mods.sha256"
check_fails "a missing manifest fails" in_repo check_game_files
write_manifest

# --- Engine version ----------------------------------------------------------
check "the pinned version is read from the Dockerfile" test "$(in_repo expected_engine_version)" = 5.0.3
check "a matching engine version passes" in_repo check_engine_version 5.0.3
check_fails "a different engine version fails" in_repo check_engine_version 5.0.2
check "an unknown engine version only warns" in_repo check_engine_version ""
check "a 0.0.0 (unstamped) engine version only warns" in_repo check_engine_version 0.0.0

# --- Save syncing ------------------------------------------------------------
REMOTE="$WORK/saves.git"
git init -q --bare -b main "$REMOTE"
seed="$WORK/seed"
git clone -q "$REMOTE" "$seed" 2>/dev/null
(cd "$seed" && git checkout -q -b main 2>/dev/null; echo first > save00.zds && git add . && git commit -q -m seed && git push -q -u origin main)

check "a plain saves/ folder only warns" in_repo saves_pull
check "saves_push is a no-op without a saves repo" in_repo saves_push
rm -rf "$REPO/saves"

# A second machine, sharing the same remote.
OTHER="$WORK/other"
mkdir -p "$OTHER"
cp -R "$REPO/." "$OTHER/"
git clone -q "$REMOTE" "$REPO/saves"
git clone -q "$REMOTE" "$OTHER/saves"

echo second > "$REPO/saves/save00.zds"
echo new > "$REPO/saves/save01.zds"
check "saves_push commits and pushes a session's saves" in_repo saves_push
check "the remote has them" test "$(git --git-dir="$REMOTE" show main:save01.zds)" = new

check "saves_pull brings them to the other machine" bash -c 'cd "$1" && . "$2" && saves_pull' _ "$OTHER" "$LIB"
check "the other machine sees the new save" test "$(cat "$OTHER/saves/save01.zds")" = new

# Leftovers from a session whose push never ran are committed and pushed on
# the next launch.
echo leftover > "$OTHER/saves/save02.zds"
check "saves_pull commits and pushes leftovers" bash -c 'cd "$1" && . "$2" && saves_pull' _ "$OTHER" "$LIB"
check "the remote has the leftover" test "$(git --git-dir="$REMOTE" show main:save02.zds)" = leftover

# Both machines played without syncing: must stop, not pick a side.
echo mine > "$REPO/saves/save03.zds"
(cd "$REPO" && . "$LIB" && saves_commit)
echo theirs > "$OTHER/saves/save04.zds"
(cd "$OTHER" && . "$LIB" && saves_push) >/dev/null
check_fails "diverged saves stop the launch" in_repo saves_pull
check "the local commit survives the refusal" test "$(cat "$REPO/saves/save03.zds")" = mine
git -C "$REPO/saves" reset -q --hard origin/main

# Offline: unreachable remote warns and keeps going.
git -C "$REPO/saves" remote set-url origin "$WORK/nowhere.git"
check "an unreachable remote only warns on pull" in_repo saves_pull
echo offline > "$REPO/saves/save05.zds"
check "an unreachable remote only warns on push" in_repo saves_push
check "the offline save is committed locally" git -C "$REPO/saves" log -1 --format=%s -- save05.zds

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
