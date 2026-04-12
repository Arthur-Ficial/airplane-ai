#!/bin/zsh
# Build a distributable .zip of the signed .app for notarization upload.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT_DIR/scripts/build-app.sh"

APP_NAME="AirplaneAI"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
DIST_DIR="$ROOT_DIR/dist"
mkdir -p "$DIST_DIR"
ZIP="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$ROOT_DIR/build/${APP_NAME}.app" "$ZIP"
shasum -a 256 "$ZIP" | tee "${ZIP}.sha256"
print "==> Packaged ${ZIP}"
