#!/usr/bin/env bash
# Launch the app against whatever is already in the sandbox store (assumed to
# be 10 CLI-created chats) and capture one screenshot per conversation.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP="$ROOT_DIR/build/AirplaneAI.app"
OUT_DIR="${1:-$ROOT_DIR/build/screenshots}"
APP_BUNDLE_ID="com.franzai.airplane-ai"
APP_PROCESS_NAME="AirplaneAI"
APP_DEFAULTS_DOMAIN="com.franzai.airplane-ai"

require_dir "$APP"
mkdir -p "$OUT_DIR"

defaults write "$APP_DEFAULTS_DOMAIN" airplane.hasCompletedOnboarding -bool true
defaults write "$APP_DEFAULTS_DOMAIN" airplane.appearance -string light

close_app() {
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" 2>/dev/null || true
  sleep 1
}

launch_app() {
  open "$APP"
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to activate" >/dev/null
  for _ in $(seq 1 60); do
    if pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1 \
       && osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to count windows" 2>/dev/null | grep -Eq '^[1-9][0-9]*$'; then
      break
    fi
    sleep 1
  done
  sleep 2
}

select_chat() {
  local title="$1"
  osascript >/dev/null 2>&1 <<OSA || true
tell application "System Events"
  tell process "$APP_PROCESS_NAME"
    tell window 1
      click (first row of table 1 of scroll area 1 of group 1 whose value of static text 1 is "$title")
    end tell
  end tell
end tell
OSA
  sleep 1
}

capture() {
  local out="$1"
  "$ROOT_DIR/scripts/shot-app.sh" "$OUT_DIR/$out"
}

TITLES=(
  "Launch memo:screen-hero.png"
  "Safer bash copy:screen-code.png"
  "Vienna weekend:screen-travel.png"
  "Context window:screen-context.png"
  "Formal wording:screen-writing.png"
  "Japanese then Spanish:screen-translate.png"
  "Noir opening:screen-creative.png"
  "Grammar fix:screen-grammar.png"
  "Miles and metres:screen-quickfact.png"
  "SwiftUI updating:screen-debug.png"
)

close_app
launch_app
sleep 2

for pair in "${TITLES[@]}"; do
  title="${pair%%:*}"
  filename="${pair##*:}"
  step "Capturing '$title' → $filename"
  select_chat "$title"
  sleep 2
  capture "$filename"
done

step "All screenshots written to $OUT_DIR"
