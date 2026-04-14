#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP="$ROOT_DIR/build/AirplaneAI.app"
APP_NAME="AirplaneAI"
EVIDENCE="$ROOT_DIR/build/smoke-evidence"

rm -rf "$EVIDENCE"
mkdir -p "$EVIDENCE"
require_dir "$APP"

step "Launching $APP"
open -a "$APP"
sleep 4

step "Network probe"
/usr/sbin/lsof -nP -iTCP -iUDP 2>/dev/null | grep -i "$APP_NAME" || true > "$EVIDENCE/lsof.txt"
if grep -qi "$APP_NAME" "$EVIDENCE/lsof.txt" 2>/dev/null; then
  die "AirplaneAI opened a network connection"
fi
info "No network connections"

step "Capturing screenshots"
"$ROOT_DIR/scripts/shot-app.sh" "$EVIDENCE/01-launched.png"

step "Sending test prompt"
osascript <<'OSA' || warn "AppleScript UI drive failed; accessibility permissions may be missing"
tell application "AirplaneAI" to activate
delay 1
tell application "System Events"
    tell process "AirplaneAI"
        keystroke "Say hi in one word."
        delay 0.2
        keystroke return
    end tell
end tell
OSA
sleep 12
"$ROOT_DIR/scripts/shot-app.sh" "$EVIDENCE/02-generated.png"

osascript -e 'tell application "AirplaneAI" to quit' 2>/dev/null || true
sleep 1

step "Evidence in $EVIDENCE"
/bin/ls -la "$EVIDENCE"
