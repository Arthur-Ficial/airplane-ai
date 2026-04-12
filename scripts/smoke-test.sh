#!/bin/zsh
# Launch AirplaneAI.app, exercise it via AppleScript, capture evidence.
# Requirements: macOS, accessibility permission granted for the terminal.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/build/AirplaneAI.app"
APP_NAME="AirplaneAI"
EVIDENCE="$ROOT_DIR/build/smoke-evidence"
rm -rf "$EVIDENCE"
mkdir -p "$EVIDENCE"

[[ -d "$APP" ]] || { print -u2 "missing: $APP — run make app first"; exit 1; }

print "==> launching $APP"
open -a "$APP"
sleep 4

# Snapshot network connections — must be empty for AirplaneAI.
print "==> lsof network probe"
/usr/sbin/lsof -nP -iTCP -iUDP 2>/dev/null | grep -i "$APP_NAME" || true > "$EVIDENCE/lsof.txt"
if grep -qi "$APP_NAME" "$EVIDENCE/lsof.txt" 2>/dev/null; then
    print -u2 "✗ AirplaneAI opened a network connection"
    exit 1
fi
print "→ no network connections"

# Screenshot window.
print "==> screenshot window"
WIN_ID=$(osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to return id of window 1" 2>/dev/null || print "")
screencapture -x "$EVIDENCE/01-launched.png" 2>/dev/null || true

# Drive UI via AppleScript: send a prompt, wait, screenshot again.
print "==> sending test prompt"
osascript <<OSA || print -u2 "AppleScript UI drive failed (may need accessibility permissions)"
tell application "$APP_NAME" to activate
delay 1
tell application "System Events"
    tell process "$APP_NAME"
        keystroke "Say hi in one word."
        delay 0.2
        keystroke return
    end tell
end tell
OSA
sleep 12
screencapture -x "$EVIDENCE/02-generated.png" 2>/dev/null || true

# Quit cleanly.
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 1

print "==> evidence in $EVIDENCE"
/bin/ls -la "$EVIDENCE"
