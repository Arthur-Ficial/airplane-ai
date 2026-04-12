#!/bin/zsh
# Notarize the distributable zip. Requires env vars:
#   NOTARY_PROFILE   keychain profile for xcrun notarytool
# or NOTARY_APPLE_ID, NOTARY_TEAM_ID, NOTARY_PASSWORD.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AirplaneAI"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ZIP="$ROOT_DIR/dist/${APP_NAME}-${VERSION}.zip"
APP="$ROOT_DIR/build/${APP_NAME}.app"

[[ -f "$ZIP" ]] || { print -u2 "missing: $ZIP — run scripts/build-dist.sh first"; exit 1; }

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
else
    : "${NOTARY_APPLE_ID:?NOTARY_APPLE_ID or NOTARY_PROFILE required}"
    : "${NOTARY_TEAM_ID:?NOTARY_TEAM_ID required}"
    : "${NOTARY_PASSWORD:?NOTARY_PASSWORD required}"
    xcrun notarytool submit "$ZIP" --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD" --wait
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
print "==> Notarized and stapled ${APP}"
