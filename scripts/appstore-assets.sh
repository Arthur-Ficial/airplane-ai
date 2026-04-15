#!/usr/bin/env bash
# Prepare ALL Mac App Store submission assets locally. NEVER uploads.
# Produces: signed .app, .pkg, icon, screenshots, release notes, checklist.
# To actually upload, use: ./scripts/appstore-submit.sh --upload (separate tool).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP_NAME="AirplaneAI"
APP_PATH="$ROOT_DIR/build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/dist/appstore"
PKG_PATH="$DIST_DIR/${APP_NAME}.pkg"
VERSION_FILE="$ROOT_DIR/.version"
INFO_PLIST="$ROOT_DIR/Info.plist"

require_file "$VERSION_FILE"
require_file "$INFO_PLIST"

VERSION="$(tr -d '\n' < "$VERSION_FILE")"
PLIST_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"

[[ "$VERSION" == "$PLIST_VERSION" ]] || die ".version ($VERSION) does not match Info.plist ($PLIST_VERSION)"

step "Building app bundle"
"$ROOT_DIR/scripts/build-app.sh"
require_dir "$APP_PATH"

step "Running verification gates"
"$ROOT_DIR/Tools/ci/verify-entitlements.sh"
"$ROOT_DIR/Tools/ci/verify-no-network-symbols.sh"
"$ROOT_DIR/Tools/ci/verify-no-forbidden-deps.sh"
"$ROOT_DIR/Tools/ci/verify-model-manifest.sh"
"$ROOT_DIR/Tools/ci/verify-app-bundle.sh"

mkdir -p "$DIST_DIR"
rm -f "$PKG_PATH" "$PKG_PATH.sha256"

PKGBUILD_ARGS=(
  --component "$APP_PATH"
  --install-location /Applications
  "$PKG_PATH"
)
if [[ -n "${APPSTORE_APP_SIGN_IDENTITY:-}" ]]; then
  PKGBUILD_ARGS=(--sign "$APPSTORE_APP_SIGN_IDENTITY" "${PKGBUILD_ARGS[@]}")
fi

step "Packaging component package (LOCAL ONLY, no upload)"
pkgbuild "${PKGBUILD_ARGS[@]}"
shasum -a 256 "$PKG_PATH" > "$PKG_PATH.sha256"

step "Asset inventory"
cat <<EOF

  App bundle:    $APP_PATH
  Package:       $PKG_PATH  ($(du -sh "$PKG_PATH" | cut -f1))
  SHA-256:       $PKG_PATH.sha256
  Icon (1024):   $ROOT_DIR/build/appstore/AppIcon_1024.png (run ./scripts/generate-icon.sh)
  Screenshots:   $ROOT_DIR/build/screenshots/  (run make screenshots)
  Release notes: $ROOT_DIR/docs/RELEASE_NOTES.md
  Checklist:     $ROOT_DIR/docs/APP_STORE_SUBMISSION.md
  Description:   $ROOT_DIR/docs/APP_STORE_DESCRIPTION.md

==> Assets ready ON THIS COMPUTER. Nothing was uploaded.
EOF
