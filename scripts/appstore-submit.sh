#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP_NAME="AirplaneAI"
APP_PATH="$ROOT_DIR/build/${APP_NAME}.app"
DIST_DIR="$ROOT_DIR/dist/appstore"
PKG_PATH="$DIST_DIR/${APP_NAME}.pkg"
VERSION_FILE="$ROOT_DIR/.version"
INFO_PLIST="$ROOT_DIR/Info.plist"

UPLOAD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      UPLOAD=1
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: ./scripts/appstore-submit.sh [--upload]

Builds and packages a Mac App Store candidate.
Default mode stops after packaging.
Pass --upload to send the package with iTMSTransporter.

Environment:
  APPSTORE_APP_SIGN_IDENTITY         Optional pkgbuild signing identity
  APPSTORE_INSTALLER_SIGN_IDENTITY   Optional productbuild signing identity
  APPSTORE_ASC_USERNAME              Required with --upload
  APPSTORE_ASC_PASSWORD              Required with --upload
  APPSTORE_ASC_PROVIDER              Optional provider short name
EOF
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

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

step "Packaging component package"
pkgbuild "${PKGBUILD_ARGS[@]}"

if [[ -n "${APPSTORE_INSTALLER_SIGN_IDENTITY:-}" ]]; then
  PRODUCT_PKG="$DIST_DIR/${APP_NAME}-signed.pkg"
  rm -f "$PRODUCT_PKG"
  step "Re-signing installer package"
  productbuild --sign "$APPSTORE_INSTALLER_SIGN_IDENTITY" --package "$PKG_PATH" "$PRODUCT_PKG"
  mv "$PRODUCT_PKG" "$PKG_PATH"
fi

sha256_file "$PKG_PATH" | tee "$PKG_PATH.sha256" >/dev/null
info "package: $PKG_PATH"

if [[ "$UPLOAD" -eq 0 ]]; then
  step "Package ready. Upload skipped."
  exit 0
fi

[[ -n "${APPSTORE_ASC_USERNAME:-}" ]] || die "APPSTORE_ASC_USERNAME is required with --upload"
[[ -n "${APPSTORE_ASC_PASSWORD:-}" ]] || die "APPSTORE_ASC_PASSWORD is required with --upload"

TRANSPORT_ARGS=(
  -m upload
  -assetFile "$PKG_PATH"
  -u "$APPSTORE_ASC_USERNAME"
  -p "$APPSTORE_ASC_PASSWORD"
)

if [[ -n "${APPSTORE_ASC_PROVIDER:-}" ]]; then
  TRANSPORT_ARGS+=(-itc_provider "$APPSTORE_ASC_PROVIDER")
fi

step "Uploading package with iTMSTransporter"
xcrun iTMSTransporter "${TRANSPORT_ARGS[@]}"
