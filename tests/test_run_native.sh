#!/bin/bash
# End-to-end test of run-native.sh with a fake engine that records its
# arguments and writes a save. Proves the platform detection, path handling
# (C:/... paths on Windows), mod check, and save pull/push work together on
# each OS the CI matrix covers.
#
# Usage: tests/test_run_native.sh

set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

fail() { echo "FAIL - $*"; exit 1; }

# A checkout with the real launcher and library, fake game files.
REPO="$WORK/repo"
mkdir -p "$REPO/lib" "$REPO/config" "$REPO/engines/uzdoom" "$REPO/original_wads" "$REPO/mods"
cp "$SRC/run-native.sh" "$REPO/"
cp "$SRC/lib/common.sh" "$REPO/lib/"
cp "$SRC/config/shared.cfg" "$REPO/config/"
cp "$SRC/engines/uzdoom/Dockerfile" "$REPO/engines/uzdoom/"
cat > "$REPO/docker-compose.yml" <<'EOF'
services:
  uzdoom:
    command: >
      -iwad /games/iwads/DOOM.WAD
      -file /games/mods/a.pk3
EOF
echo doom > "$REPO/original_wads/DOOM.WAD"
echo a > "$REPO/mods/a.pk3"
# shellcheck source=lib/common.sh
(cd "$REPO" && . lib/common.sh && for f in original_wads/DOOM.WAD mods/a.pk3; do
    printf '%s  %s\n' "$(sha256_of "$f")" "$f"; done > mods.sha256)

# The saves remote, with one save from "another machine".
git init -q --bare "$WORK/saves.git"
git clone -q "$WORK/saves.git" "$WORK/seed" 2>/dev/null
(cd "$WORK/seed" && echo remote > save00.zds && git add . && git commit -q -m seed && git push -q origin HEAD)
git clone -q "$WORK/saves.git" "$REPO/saves"

# Fake engine: record the args, check the remote save arrived, write a save.
cat > "$WORK/uzdoom" <<'EOF'
#!/bin/bash
printf '%s\n' "$@" > "$ARGS_OUT"
savedir=""
while [ $# -gt 0 ]; do [ "$1" = -savedir ] && savedir="$2"; shift; done
[ -n "$savedir" ] || exit 3
[ "$(cat "$savedir/save00.zds")" = remote ] || exit 4
echo session > "$savedir/save01.zds"
EOF
chmod +x "$WORK/uzdoom"
export ARGS_OUT="$WORK/args"

UZDOOM_BIN="$WORK/uzdoom" "$REPO/run-native.sh" +map E1M1 || fail "run-native.sh exited $?"

args="$(cat "$ARGS_OUT")"
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) platform=windows; prefix="$(cd "$REPO" && pwd -W)" ;;
    Darwin) platform=macos; prefix="$REPO" ;;
    *) platform=linux; prefix="$REPO" ;;
esac
for want in "-config" "$prefix/config/uzdoom-$platform.ini" "-savedir" "$prefix/saves" \
            "-exec" "$prefix/config/shared.cfg" "$prefix/original_wads/DOOM.WAD" \
            "$prefix/mods/a.pk3" "+map" "E1M1"; do
    grep -qxF -- "$want" <<<"$args" || fail "engine wasn't given '$want'; got:"$'\n'"$args"
done
echo "ok   - engine got the expected arguments ($platform)"

[ "$(git --git-dir="$WORK/saves.git" show HEAD:save01.zds)" = session ] \
    || fail "the session's save wasn't pushed"
echo "ok   - the remote save was pulled before, and the new save pushed after"

echo changed > "$REPO/mods/a.pk3"
if UZDOOM_BIN="$WORK/uzdoom" "$REPO/run-native.sh" >/dev/null 2>&1; then
    fail "launched with a mod that doesn't match mods.sha256"
fi
echo "ok   - refuses to launch with a mismatched mod"
