#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP_NAME="AirplaneAI"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ZIP="$ROOT_DIR/dist/${APP_NAME}-${VERSION}.zip"
APP="$ROOT_DIR/build/${APP_NAME}.app"

require_file "$ZIP"

step "Submitting zip for notarization"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
else
  : "${NOTARY_APPLE_ID:?NOTARY_APPLE_ID or NOTARY_PROFILE required}"
  : "${NOTARY_TEAM_ID:?NOTARY_TEAM_ID required}"
  : "${NOTARY_PASSWORD:?NOTARY_PASSWORD required}"
  xcrun notarytool submit "$ZIP" \
    --apple-id "$NOTARY_APPLE_ID" \
    --team-id "$NOTARY_TEAM_ID" \
    --password "$NOTARY_PASSWORD" \
    --wait
fi

step "Stapling notarization ticket"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
step "Notarized and stapled ${APP}"
