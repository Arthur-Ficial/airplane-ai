#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP_NAME="AirplaneAI"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
DIST_DIR="$ROOT_DIR/dist"
ZIP="$DIST_DIR/${APP_NAME}-${VERSION}.zip"

step "Building signed app bundle"
"$ROOT_DIR/scripts/build-app.sh"

step "Packaging distributable zip"
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/build/${APP_NAME}.app" "$ZIP"
shasum -a 256 "$ZIP" | tee "${ZIP}.sha256"
step "Packaged ${ZIP}"
