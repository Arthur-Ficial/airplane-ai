#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

NEW_VERSION="${1:?usage: release.sh <x.y.z>}"
APP_NAME="AirplaneAI"

step "Release ${APP_NAME} ${NEW_VERSION}"
printf '%s\n' "$NEW_VERSION" > "$ROOT_DIR/.version"

step "Quality gate"
cd "$ROOT_DIR"
"$ROOT_DIR/scripts/line-buffered.sh" swift test --parallel
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-no-forbidden-deps.sh
./Tools/ci/verify-model-manifest.sh

step "Build + notarize"
./scripts/build-dist.sh
./scripts/notarize.sh
./Tools/ci/verify-app-bundle.sh

step "Tagging release"
git add .version
git commit -m "Release v${NEW_VERSION}"
git tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
git push origin HEAD
git push origin "v${NEW_VERSION}"

ZIP="$ROOT_DIR/dist/${APP_NAME}-${NEW_VERSION}.zip"
gh release create "v${NEW_VERSION}" "$ZIP" "${ZIP}.sha256" \
  --title "Airplane AI ${NEW_VERSION}" \
  --notes-file "$ROOT_DIR/docs/RELEASE_NOTES.md" 2>/dev/null || \
gh release create "v${NEW_VERSION}" "$ZIP" "${ZIP}.sha256" \
  --title "Airplane AI ${NEW_VERSION}" \
  --notes "See CHANGELOG"

step "Released v${NEW_VERSION}"
