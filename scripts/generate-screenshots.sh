#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP="$ROOT_DIR/build/AirplaneAI.app"
APP_BIN="$APP/Contents/MacOS/AirplaneAI"
OUT_DIR="${1:-$ROOT_DIR/site/img}"
APP_DEFAULTS_DOMAIN="com.franzai.airplane-ai"
APP_BUNDLE_ID="com.franzai.airplane-ai"
APP_PROCESS_NAME="AirplaneAI"
WINDOW_WIDTH=1440
WINDOW_HEIGHT=1024
CHAT_CROP_X=332
CHAT_CROP_Y=68
CHAT_CROP_WIDTH=1068
CHAT_CROP_HEIGHT=902

require_dir "$APP"
mkdir -p "$OUT_DIR"
command -v cwebp >/dev/null 2>&1 || die "cwebp is required for screenshot generation"

close_app() {
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to quit" 2>/dev/null || true
  sleep 1
}

seed_samples() {
  "$ROOT_DIR/scripts/with-build-lock.sh" swift run -c debug --skip-build AirplaneAI --seed-sample-conversations --replace
}

launch_app() {
  AIRPLANE_SCREENSHOT_MODE=1 "$APP_BIN" >/tmp/airplane-screenshot.log 2>&1 &
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
      set size of front window to {$WINDOW_WIDTH, $WINDOW_HEIGHT}
    end if
  end tell
end tell
OSA
}

capture_window() {
  local out="$1"
  "$ROOT_DIR/scripts/shot-app.sh" "$out"
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

open_settings() {
  osascript -e "tell application id \"$APP_BUNDLE_ID\" to activate" >/dev/null
  osascript -e "tell application \"System Events\" to keystroke \",\" using command down" >/dev/null
}

crop_chat() {
  local src="$1"
  local dest="$2"
  python3 - "$src" "$dest" "$CHAT_CROP_X" "$CHAT_CROP_Y" "$CHAT_CROP_WIDTH" "$CHAT_CROP_HEIGHT" <<'PY'
from PIL import Image
import sys

src, dest, x, y, width, height = sys.argv[1:]
x = int(x)
y = int(y)
width = int(width)
height = int(height)

with Image.open(src) as image:
    cropped = image.crop((x, y, x + width, y + height))
    cropped.save(dest)
PY
}

encode_webp() {
  local src="$1"
  local dest="$2"
  cwebp -quiet -q 92 "$src" -o "$dest"
}

capture_chat_asset() {
  local title="$1"
  local stem="$2"
  local raw="$OUT_DIR/.${stem}.raw.png"
  local png="$OUT_DIR/${stem}.png"
  local webp="$OUT_DIR/${stem}.webp"

  step "Capturing $stem"
  select_chat "$title"
  capture_window "$raw"
  crop_chat "$raw" "$png"
  encode_webp "$png" "$webp"
  rm -f "$raw"
}

capture_settings_asset() {
  local stem="$1"
  local png="$OUT_DIR/${stem}.png"
  local webp="$OUT_DIR/${stem}.webp"

  step "Capturing $stem"
  open_settings
  sleep 2
  capture_window "$png"
  encode_webp "$png" "$webp"
}

step "Seeding deterministic conversations"
defaults write "$APP_DEFAULTS_DOMAIN" airplane.hasCompletedOnboarding -bool true
defaults write "$APP_DEFAULTS_DOMAIN" airplane.appearance -string light
defaults write "$APP_DEFAULTS_DOMAIN" airplane.showTokenCounts -bool true
"$ROOT_DIR/scripts/with-build-lock.sh" swift build -c debug --product AirplaneAI

seed_samples
close_app
launch_app
sleep 2

SHOTS=(
  "Product launch memo:screen-chat"
  "Safer bash file copy:screen-code"
  "Vienna weekend, coffee focus:screen-travel"
  "Make this more formal:screen-writing"
  "Bathroom in Japanese, then Spanish:screen-translate"
  "Noir opening set in Tokyo:screen-creative"
  "SwiftUI view not updating:screen-debugging"
  "Email regex (and its limits):screen-regex"
  "Context window tradeoffs:screen-analysis"
)

for entry in "${SHOTS[@]}"; do
  title="${entry%%:*}"
  stem="${entry##*:}"
  capture_chat_asset "$title" "$stem"
done

capture_settings_asset "screen-settings"

close_app
step "Screenshots written to $OUT_DIR"
