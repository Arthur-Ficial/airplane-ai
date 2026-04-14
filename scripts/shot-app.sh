#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

OUT="${1:-$(pwd)/build/ui-evidence/app.png}"
APP_PROCESS_NAME="AirplaneAI"
mkdir -p "$(dirname "$OUT")"

wid=""
for _ in $(seq 1 20); do
  wid="$(osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to get value of attribute \"AXWindowID\" of front window" 2>/dev/null || true)"
  [[ -n "$wid" ]] && break
  sleep 1
done

if [[ -n "$wid" ]]; then
  screencapture -x -l "$wid" "$OUT"
  printf '→ %s\n' "$OUT"
  exit 0
fi

x="$(osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to item 1 of (get position of front window)" 2>/dev/null || true)"
y="$(osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to item 2 of (get position of front window)" 2>/dev/null || true)"
w="$(osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to item 1 of (get size of front window)" 2>/dev/null || true)"
h="$(osascript -e "tell application \"System Events\" to tell process \"$APP_PROCESS_NAME\" to item 2 of (get size of front window)" 2>/dev/null || true)"

if [[ -n "$x" && -n "$y" && -n "$w" && -n "$h" ]]; then
  screencapture -x -R"${x},${y},${w},${h}" "$OUT"
  printf '→ %s\n' "$OUT"
  exit 0
fi

if command -v peekaboo >/dev/null 2>&1; then
  peekaboo image --app AirplaneAI --mode window --path "$OUT" >/dev/null
  printf '→ %s\n' "$OUT"
  exit 0
fi

die "AirplaneAI is not running or its window could not be found"
