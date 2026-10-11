# shellcheck shell=bash
# Shared by run.sh (Linux container) and run-native.sh (macOS, Windows via
# Git Bash, native Linux). Sourced, not executed. Callers must cd to the repo
# root first; every path here is relative to it.
#
# Two jobs, both about continuing a game on another machine:
#   - Saves live in saves/, a clone of a separate private repo, pulled before
#     a session and committed + pushed after it.
#   - A save only loads with the same mod files and engine version it was
#     made with, so check both against what the repo pins before launching.
#
# DOOMTAINER_SKIP_CHECKS=1 skips the mod and engine checks (e.g. to try a new
# mod before updating mods.sha256).

SAVES_DIR="saves"
MODS_MANIFEST="mods.sha256"
MODS_CACHE=".mods-verified"

warn() { echo "Warning: $*" >&2; }
die() { echo "Error: $*" >&2; exit 1; }

# Launch arguments from the `command:` block in docker-compose.yml, one per
# line, with container paths mapped to the repo folders they're mounted from.
# The prefix to map to is $1 (the repo dir for native engines).
compose_args() {
    local prefix="$1"
    awk '/^    command: >/{f=1;next} f&&/^      /{print} f&&!/^      /{f=0}' docker-compose.yml \
        | tr -s ' \t\r' '\n' | sed '/^$/d' \
        | sed -e "s#^/games/iwads#$prefix/original_wads#" \
              -e "s#^/games/maps#$prefix/map_wads#" \
              -e "s#^/games/mods#$prefix/mods#"
}

# Repo-relative paths of the WAD/mod files the launch command loads.
game_files() {
    compose_args "." | sed -n 's#^\./##p'
}

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

# "size mtime" of a file; GNU stat (Linux, Git Bash) or BSD stat (macOS).
file_stamp() {
    stat -c '%s %Y' "$1" 2>/dev/null || stat -f '%z %m' "$1"
}

# Hash a file, reusing the last result while its size and mtime are unchanged
# (the mods are ~1 GB, several seconds to hash on every launch).
cached_sha256() {
    local file="$1" stamp hash
    stamp="$(file_stamp "$file")"
    if [ -f "$MODS_CACHE" ]; then
        hash="$(awk -F'\t' -v f="$file" -v s="$stamp" '$1==f && $2==s {print $3}' "$MODS_CACHE")"
        if [ -n "$hash" ]; then echo "$hash"; return; fi
    fi
    hash="$(sha256_of "$file")"
    { [ -f "$MODS_CACHE" ] && awk -F'\t' -v f="$file" '$1!=f' "$MODS_CACHE"
      printf '%s\t%s\t%s\n' "$file" "$stamp" "$hash"; } > "$MODS_CACHE.tmp"
    mv "$MODS_CACHE.tmp" "$MODS_CACHE"
    echo "$hash"
}

# Fail unless every file the launch command loads exists and matches
# mods.sha256, and mods.sha256 lists exactly those files.
check_game_files() {
    local file expected actual failed=0
    [ "${DOOMTAINER_SKIP_CHECKS:-}" = 1 ] && { warn "skipping mod checks"; return 0; }
    [ -f "$MODS_MANIFEST" ] || die "$MODS_MANIFEST is missing; run scripts/update-mods-manifest.sh"

    while IFS= read -r file; do
        if [ ! -e "$file" ]; then
            echo "Missing: $file" >&2; failed=1; continue
        fi
        expected="$(awk -v f="$file" '{h=$1; sub(/^[^ ]+  /, "")} $0==f {print h}' "$MODS_MANIFEST")"
        if [ -z "$expected" ]; then
            echo "Not in $MODS_MANIFEST: $file" >&2; failed=1; continue
        fi
        actual="$(cached_sha256 "$file")"
        if [ "$actual" != "$expected" ]; then
            echo "Different file than the other machines use: $file" >&2; failed=1
        fi
    done < <(game_files)

    # A manifest entry the command no longer loads means one of the two
    # wasn't updated after a mod change.
    while IFS= read -r file; do
        game_files | grep -qxF "$file" || { echo "In $MODS_MANIFEST but not loaded: $file" >&2; failed=1; }
    done < <(grep -v '^#' "$MODS_MANIFEST" | sed 's/^[^ ]*  //')

    if [ "$failed" -ne 0 ]; then
        echo "Saves only load with the same mod files, so this machine would make saves the" >&2
        echo "others can't load. Copy the WAD/mod folders from a machine that matches, or, if" >&2
        echo "you changed the mod list on purpose, run scripts/update-mods-manifest.sh and commit." >&2
        echo "DOOMTAINER_SKIP_CHECKS=1 launches anyway." >&2
        exit 1
    fi
}

# The engine version every machine must run: the one the container builds.
expected_engine_version() {
    sed -n 's/^ARG UZDOOM_VERSION=//p' engines/uzdoom/Dockerfile
}

# Compare a native engine's reported version ($1, empty if unknown) with the
# pinned one. Unknown only warns, since not every build reports it.
check_engine_version() {
    local actual="$1" expected
    [ "${DOOMTAINER_SKIP_CHECKS:-}" = 1 ] && return 0
    expected="$(expected_engine_version)"
    if [ -z "$actual" ] || [ "$actual" = "0.0.0" ]; then
        warn "couldn't read the engine version; make sure it's UZDoom $expected or saves may not load elsewhere."
    elif [ "$actual" != "$expected" ]; then
        die "this engine is UZDoom $actual but the other machines use $expected, so saves may not
load across them. Install $expected (or bump UZDOOM_VERSION in engines/uzdoom/Dockerfile
for every machine). DOOMTAINER_SKIP_CHECKS=1 launches anyway."
    fi
}

# Is saves/ a clone of the saves repo (vs. a plain local folder)?
saves_is_repo() {
    [ -d "$SAVES_DIR/.git" ]
}

# Commit whatever changed in saves/ (new saves, or leftovers from a session
# whose push never ran). Returns 0 even when there was nothing to commit.
saves_commit() {
    saves_is_repo || return 0
    git -C "$SAVES_DIR" add -A
    if ! git -C "$SAVES_DIR" diff --cached --quiet; then
        git -C "$SAVES_DIR" commit -q -m "Saves from $(hostname -s 2>/dev/null || hostname), $(date '+%Y-%m-%d %H:%M')"
    fi
}

# Before a session: get the latest saves from the other machines.
saves_pull() {
    mkdir -p "$SAVES_DIR"
    if ! saves_is_repo; then
        warn "$SAVES_DIR/ isn't a clone of the saves repo, so saves stay on this machine (see README)."
        return 0
    fi
    saves_commit
    if ! git -C "$SAVES_DIR" fetch -q origin; then
        warn "couldn't reach the saves repo (offline?). Playing on this machine's copy; it may be behind."
        return 0
    fi
    if ! git -C "$SAVES_DIR" merge -q --ff-only '@{u}' 2>/dev/null; then
        die "saves/ has commits the remote doesn't, and the remote has commits this machine doesn't
(two machines played without syncing). Saves are binary and can't be merged. Inspect with
    git -C saves log --oneline --graph --all
and keep one side, e.g. 'git -C saves reset --hard origin/main' to take the remote's."
    fi
    # Push anything committed earlier that never made it out.
    if [ -n "$(git -C "$SAVES_DIR" rev-list '@{u}..HEAD')" ]; then
        git -C "$SAVES_DIR" push -q || warn "couldn't push earlier saves; will retry next launch."
    fi
}

# After a session: publish the new saves.
saves_push() {
    saves_is_repo || return 0
    saves_commit
    [ -n "$(git -C "$SAVES_DIR" rev-list '@{u}..HEAD' 2>/dev/null)" ] || return 0
    if git -C "$SAVES_DIR" push -q; then
        echo "Saves pushed."
    else
        warn "couldn't push saves (offline?). They're committed locally and will be pushed on the next launch."
    fi
}
