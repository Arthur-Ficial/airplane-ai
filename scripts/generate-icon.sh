#!/usr/bin/env bash
# Render AppIcon.icns from the SwiftUI icon tool using a cached debug build.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

if [[ "${AIRPLANE_BUILD_LOCK_HELD:-}" != "1" ]]; then
  exec "$ROOT_DIR/scripts/with-build-lock.sh" "$0" "$@"
fi

OUT_PATH="$ROOT_DIR/Sources/AirplaneAI/Resources/AppIcon.icns"
CACHE_DIR="$ROOT_DIR/build/.cache"
STAMP_PATH="$CACHE_DIR/iconrender.state"
STATE_INPUTS=(
  "$ROOT_DIR/Tools/iconrender/IconRender.swift"
  "$ROOT_DIR/Sources/AirplaneAI/UI/BrandIcon.swift"
)

mkdir -p "$CACHE_DIR"

state="$(
  for path in "${STATE_INPUTS[@]}"; do
    require_file "$path"
    printf '%s|%s\n' "$path" "$(file_fingerprint "$path")"
  done
)"

if [[ "${1:-}" != "--force" ]] && [[ -f "$OUT_PATH" ]] && [[ -f "$STAMP_PATH" ]] && [[ "$(cat "$STAMP_PATH")" == "$state" ]]; then
  step "AppIcon.icns already up to date"
  info "$OUT_PATH"
  exit 0
fi

step "Building AirplaneIconRender (debug)"
swift build -c debug --product AirplaneIconRender --package-path "$ROOT_DIR"

step "Rendering AppIcon.icns"
swift run -c debug --skip-build --package-path "$ROOT_DIR" AirplaneIconRender "$OUT_PATH"
printf '%s\n' "$state" > "$STAMP_PATH"
step "Wrote $OUT_PATH"
