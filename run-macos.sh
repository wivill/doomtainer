#!/bin/bash
# Kept so existing habits and shortcuts still work; run-native.sh now covers
# macOS, Windows and native Linux.
exec "$(dirname "$0")/run-native.sh" "$@"
