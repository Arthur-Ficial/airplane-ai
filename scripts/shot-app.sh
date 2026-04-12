#!/bin/zsh
# Screenshot ONLY the AirplaneAI window (no desktop).
# Uses `screencapture -l <windowID>` via window ID from osascript.
set -euo pipefail
OUT="${1:-$(pwd)/build/ui-evidence/app.png}"
mkdir -p "$(dirname "$OUT")"

WID=$(osascript -e 'tell application "System Events" to tell process "AirplaneAI" to get value of attribute "AXWindowID" of front window' 2>/dev/null || print "")
if [[ -n "$WID" ]]; then
    screencapture -x -l "$WID" "$OUT"
else
    # Fallback: region-capture using AXPosition + AXSize.
    X=$(osascript -e 'tell application "System Events" to tell process "AirplaneAI" to item 1 of (get position of front window)' 2>/dev/null || print "")
    Y=$(osascript -e 'tell application "System Events" to tell process "AirplaneAI" to item 2 of (get position of front window)' 2>/dev/null || print "")
    W=$(osascript -e 'tell application "System Events" to tell process "AirplaneAI" to item 1 of (get size of front window)' 2>/dev/null || print "")
    H=$(osascript -e 'tell application "System Events" to tell process "AirplaneAI" to item 2 of (get size of front window)' 2>/dev/null || print "")
    if [[ -n "$X" && -n "$Y" && -n "$W" && -n "$H" ]]; then
        screencapture -x -R"${X},${Y},${W},${H}" "$OUT"
    else
        print -u2 "AirplaneAI not running or window not found"; exit 1
    fi
fi
print "→ $OUT"
