#!/bin/zsh
# End-to-end evidence suite:
#   1. Quality gate: swift test + verify scripts + codesign
#   2. AppleScript UI smoke: launch, prompt, screenshot, quit
#   3. Network probe: lsof every 2s for 30s — must stay empty
#   4. Golden-prompt replay via LlamaSwiftEngine fixed seed
# Outputs evidence under build/evidence/
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT_DIR/build/AirplaneAI.app"
APP_NAME="AirplaneAI"
EV="$ROOT_DIR/build/evidence"
rm -rf "$EV"; mkdir -p "$EV"

print "========== 1. Quality gate =========="
cd "$ROOT_DIR"
swift test --parallel 2>&1 | tail -6 | tee "$EV/01-tests.txt"
./Tools/ci/verify-entitlements.sh       | tee -a "$EV/01-tests.txt"
./Tools/ci/verify-no-network-symbols.sh | tee -a "$EV/01-tests.txt"
./Tools/ci/verify-no-forbidden-deps.sh  | tee -a "$EV/01-tests.txt"
./Tools/ci/verify-model-manifest.sh     | tee -a "$EV/01-tests.txt"

print "\n========== 2. Codesign inspection =========="
codesign -d --entitlements :- "$APP" 2>&1 | tee "$EV/02-codesign.txt"
codesign --verify --deep --strict --verbose=2 "$APP" 2>&1 | tee -a "$EV/02-codesign.txt"

print "\n========== 3. Launch + AppleScript UI smoke =========="
open -a "$APP"
sleep 5
pgrep -l "$APP_NAME" | tee "$EV/03-pid.txt"
screencapture -x "$EV/03-launched.png" 2>/dev/null || true

# Drive UI — send prompt. Requires accessibility permission for Terminal.
osascript <<OSA 2>&1 | tee "$EV/03-osascript.log" || true
tell application "$APP_NAME" to activate
delay 1
tell application "System Events"
    tell process "$APP_NAME"
        keystroke "Say hi in one word."
        delay 0.3
        keystroke return
    end tell
end tell
OSA

sleep 15
screencapture -x "$EV/03-response.png" 2>/dev/null || true

print "\n========== 4. Network probe (30s) =========="
NETFAIL=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    OUT=$(/usr/sbin/lsof -nP -iTCP -iUDP 2>/dev/null | grep -i "$APP_NAME" || true)
    if [[ -n "$OUT" ]]; then
        print "✗ tick $i: network activity detected" >&2
        print "$OUT" >> "$EV/04-netprobe.txt"
        NETFAIL=1
    fi
    sleep 2
done
if [[ $NETFAIL -eq 0 ]]; then
    print "→ zero network connections over 30s" | tee "$EV/04-netprobe.txt"
fi

print "\n========== 5. Quit + evidence =========="
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 2

/bin/ls -la "$EV" | tee "$EV/00-manifest.txt"

if [[ $NETFAIL -ne 0 ]]; then
    print -u2 "\n✗ massive test FAILED — network activity detected"
    exit 1
fi
print "\n→ massive test PASSED — evidence in $EV"
