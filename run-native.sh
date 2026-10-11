#!/bin/bash
# Native launcher for machines where the container can't run: macOS (Docker
# runs in a Linux VM with no GPU, display or audio passthrough), Windows
# (from Git Bash, or run-windows.cmd), and Linux without Docker. The engine
# runs natively against the same WAD/mod folders the container uses.
#
# The launch arguments are read from the `command:` block in
# docker-compose.yml so the mod list stays defined in one place. Saves are
# synced through saves/ and the mod files and engine version are checked
# first, so a game can be continued on any machine (see lib/common.sh).
#
# Overrides: UZDOOM_BIN (engine binary), UZDOOM_INI (config file).

set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=lib/common.sh
. lib/common.sh

# 1. Platform defaults. Each OS keeps its own ini (video, mouse and pad
# settings differ per machine); shared settings go in config/shared.cfg.
case "$(uname -s)" in
    Darwin)
        platform=macos
        default_bin=/Applications/UZDoom.app/Contents/MacOS/uzdoom
        ;;
    MINGW*|MSYS*|CYGWIN*)
        platform=windows
        default_bin=""
        for candidate in \
            "${LOCALAPPDATA:-}/Programs/UZDoom/uzdoom.exe" \
            "/c/Program Files/UZDoom/uzdoom.exe" \
            "/c/Games/UZDoom/uzdoom.exe"; do
            if [ -x "$candidate" ]; then default_bin="$candidate"; break; fi
        done
        [ -n "$default_bin" ] || default_bin="$(command -v uzdoom.exe || true)"
        ;;
    *)
        platform=linux
        default_bin="$(command -v uzdoom || true)"
        ;;
esac
UZDOOM_BIN="${UZDOOM_BIN:-$default_bin}"
UZDOOM_INI="${UZDOOM_INI:-config/uzdoom-$platform.ini}"

if [ -z "$UZDOOM_BIN" ] || [ ! -x "$UZDOOM_BIN" ]; then
    echo "Error: UZDoom not found${UZDOOM_BIN:+ at $UZDOOM_BIN}." >&2
    echo "Install it from https://github.com/UZDoom/UZDoom/releases, or set UZDOOM_BIN to the engine binary." >&2
    exit 1
fi

# The engine is a native program: on Windows give it C:/... paths rather than
# Git Bash's /c/... ones.
if [ "$platform" = windows ]; then
    REPO_DIR="$(pwd -W)"
else
    REPO_DIR="$(pwd)"
fi

# 2. Engine version, where the build reports it.
engine_version=""
case "$platform" in
    macos)
        # Only inside an app bundle; PlistBuddy reports a missing file on stdout.
        plist="${UZDOOM_BIN%/MacOS/*}/Info.plist"
        if [ -f "$plist" ]; then
            engine_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist" 2>/dev/null || true)"
        fi
        ;;
    windows)
        # ProductVersion is the git tag (e.g. 5.0.3), possibly with a suffix.
        engine_version="$(powershell.exe -NoProfile -Command \
            "(Get-Item -LiteralPath '$(cygpath -w "$UZDOOM_BIN")').VersionInfo.ProductVersion" 2>/dev/null \
            | tr -d '\r' | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' || true)"
        ;;
esac
# Anything but X.Y.Z (an error message, an empty field) counts as unknown.
engine_version="$(printf '%s\n' "$engine_version" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+$' || true)"
check_engine_version "$engine_version"

# 3. Same mod files as the other machines, then the latest saves.
check_game_files
saves_pull

ARGS=()
while IFS= read -r arg; do ARGS+=("$arg"); done < <(compose_args "$REPO_DIR")
[ ${#ARGS[@]} -gt 0 ] || die "could not read the command block from docker-compose.yml"

# 4. Play, then publish the session's saves. A trap handler (not an ignored
# signal) lets Ctrl+C stop the engine without skipping the push.
trap 'true' INT
status=0
"$UZDOOM_BIN" \
    -config "$REPO_DIR/$UZDOOM_INI" \
    -savedir "$REPO_DIR/$SAVES_DIR" \
    -exec "$REPO_DIR/config/shared.cfg" \
    "${ARGS[@]}" \
    "$@" || status=$?
trap - INT
saves_push
exit "$status"
