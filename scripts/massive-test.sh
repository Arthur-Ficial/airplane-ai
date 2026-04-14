#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP="$ROOT_DIR/build/AirplaneAI.app"
APP_NAME="AirplaneAI"
EV="$ROOT_DIR/build/evidence"

rm -rf "$EV"
mkdir -p "$EV"

step "Quality gate"
cd "$ROOT_DIR"
"$ROOT_DIR/scripts/line-buffered.sh" swift test --parallel 2>&1 | tee "$EV/01-tests.txt"
./Tools/ci/verify-entitlements.sh       | tee -a "$EV/01-tests.txt"
./Tools/ci/verify-no-network-symbols.sh | tee -a "$EV/01-tests.txt"
./Tools/ci/verify-no-forbidden-deps.sh  | tee -a "$EV/01-tests.txt"
./Tools/ci/verify-model-manifest.sh     | tee -a "$EV/01-tests.txt"

step "Codesign inspection"
codesign -d --entitlements :- "$APP" 2>&1 | tee "$EV/02-codesign.txt"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tee -a "$EV/02-codesign.txt"

step "Launch + UI smoke"
open -a "$APP"
sleep 5
pgrep -l "$APP_NAME" | tee "$EV/03-pid.txt"
screencapture -x "$EV/03-launched.png" 2>/dev/null || true

osascript <<'OSA' 2>&1 | tee "$EV/03-osascript.log" || true
tell application "AirplaneAI" to activate
delay 1
tell application "System Events"
    tell process "AirplaneAI"
        keystroke "Say hi in one word."
        delay 0.3
        keystroke return
    end tell
end tell
OSA

sleep 15
screencapture -x "$EV/03-response.png" 2>/dev/null || true

step "Network probe (30s)"
netfail=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  out="$("/usr/sbin/lsof" -nP -iTCP -iUDP 2>/dev/null | grep -i "$APP_NAME" || true)"
  if [[ -n "$out" ]]; then
    printf '✗ tick %s: network activity detected\n' "$i" >&2
    printf '%s\n' "$out" >> "$EV/04-netprobe.txt"
    netfail=1
  fi
  sleep 2
done
if [[ "$netfail" -eq 0 ]]; then
  printf '→ zero network connections over 30s\n' | tee "$EV/04-netprobe.txt"
fi

step "Quit + evidence"
osascript -e 'tell application "AirplaneAI" to quit' 2>/dev/null || true
sleep 2
/bin/ls -la "$EV" | tee "$EV/00-manifest.txt"

if [[ "$netfail" -ne 0 ]]; then
  die "massive test failed; network activity detected"
fi

step "massive test passed"
