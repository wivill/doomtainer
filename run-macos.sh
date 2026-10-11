#!/bin/bash
# Native macOS launcher. Docker on macOS runs inside a Linux VM with no GPU,
# display or audio passthrough, so here the engine runs natively (UZDoom,
# Metal via MoltenVK) against the same WAD/mod folders the container uses.
#
# The launch arguments are read from the `command:` block in
# docker-compose.yml so the mod list stays defined in one place. Container
# paths (/games/...) are mapped back to the repo folders below.

set -euo pipefail

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"

UZDOOM_BIN="${UZDOOM_BIN:-/Applications/UZDoom.app/Contents/MacOS/uzdoom}"

if [ ! -x "$UZDOOM_BIN" ]; then
    echo "Error: UZDoom not found at $UZDOOM_BIN" >&2
    echo "Install it from https://github.com/UZDoom/UZDoom/releases (MacOS-UZDoom-Release-ARM64.dmg)," >&2
    echo "or set UZDOOM_BIN to the engine binary." >&2
    exit 1
fi

# 1. Extract the args from docker-compose.yml and map container paths to repo paths.
ARGS=()
while IFS= read -r arg; do
    arg="${arg//\/games\/iwads/$REPO_DIR/original_wads}"
    arg="${arg//\/games\/maps/$REPO_DIR/map_wads}"
    arg="${arg//\/games\/mods/$REPO_DIR/mods}"
    ARGS+=("$arg")
done < <(awk '/^    command: >/{f=1;next} f&&/^      /{print} f&&!/^      /{f=0}' docker-compose.yml | tr -s ' \t' '\n' | sed '/^$/d')

if [ ${#ARGS[@]} -eq 0 ]; then
    echo "Error: could not read the command block from docker-compose.yml" >&2
    exit 1
fi

# 2. Fail early on missing files instead of letting the engine fall back silently.
missing=0
for arg in "${ARGS[@]}"; do
    case "$arg" in
        "$REPO_DIR"/*)
            if [ ! -e "$arg" ]; then
                echo "Missing: ${arg#"$REPO_DIR"/}" >&2
                missing=1
            fi
            ;;
    esac
done
if [ "$missing" -ne 0 ]; then
    echo "Copy your WADs/mods into original_wads/, map_wads/ and mods/ (see README)." >&2
    exit 1
fi

# 3. Keep config and saves in the repo, separate from the container's
# uzdoom.ini so each machine keeps its own video, mouse and key settings.
mkdir -p savegames

exec "$UZDOOM_BIN" \
    -config "$REPO_DIR/config/uzdoom-macos.ini" \
    -savedir "$REPO_DIR/savegames" \
    "${ARGS[@]}" \
    "$@"
