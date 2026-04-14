#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP="$ROOT_DIR/build/AirplaneAI.app"
OUT_DIR="${1:-$ROOT_DIR/build/screenshots}"
APP_DEFAULTS_DOMAIN="com.franzai.airplane-ai"
APP_BUNDLE_ID="com.franzai.airplane-ai"
APP_PROCESS_NAME="AirplaneAI"

require_dir "$APP"
mkdir -p "$OUT_DIR"

close_app() {
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" 2>/dev/null || true
  sleep 1
}

seed_sample() {
  local focus="$1"
  "$ROOT_DIR/scripts/with-build-lock.sh" swift run -c debug --skip-build AirplaneAI --seed-sample-conversations --replace --focus "$focus"
}

launch_app() {
  open "$APP"
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to activate" >/dev/null

  for _ in $(seq 1 60); do
    if pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
      if osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to count windows" 2>/dev/null | grep -Eq '^[1-9][0-9]*$'; then
        break
      fi
    fi
    sleep 1
  done

  osascript <<OSA >/dev/null 2>&1 || true
tell application "System Events"
  tell process "$APP_PROCESS_NAME"
    if (count windows) > 0 then
      set position of front window to {120, 80}
      set size of front window to {1440, 1024}
    end if
  end tell
end tell
OSA
}

capture_main() {
  local name="$1"
  "$ROOT_DIR/scripts/shot-app.sh" "$OUT_DIR/$name"
}

send_hotkey() {
  local key="$1"
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to activate" >/dev/null
  osascript -e "tell application \"System Events\" to keystroke \"$key\" using command down" >/dev/null
}

step "Seeding deterministic conversations"
defaults write "$APP_DEFAULTS_DOMAIN" airplane.hasCompletedOnboarding -bool true
defaults write "$APP_DEFAULTS_DOMAIN" airplane.appearance -string light
defaults write "$APP_DEFAULTS_DOMAIN" airplane.showTokenCounts -bool true
"$ROOT_DIR/scripts/with-build-lock.sh" swift build -c debug --product AirplaneAI

SHOTS=(
  "hero:screen-chat.png"
  "hero:screen-sidebar.png"
  "code:screen-code.png"
  "travel:screen-travel.png"
  "writing:screen-writing.png"
  "translate:screen-translate.png"
  "creative:screen-creative.png"
  "debugging:screen-debugging.png"
  "regex:screen-regex.png"
  "settings:screen-analysis.png"
)

for entry in "${SHOTS[@]}"; do
  focus="${entry%%:*}"
  filename="${entry##*:}"
  step "Capturing $focus → $filename"
  seed_sample "$focus"
  close_app
  launch_app
  sleep 1
  capture_main "$filename"
done

step "Capturing settings panel"
send_hotkey ","
sleep 2
capture_main "screen-settings.png"

close_app
step "Screenshots written to $OUT_DIR"
