#!/bin/zsh
# End-to-end release: bump .version, quality gate, build, sign, notarize, tag, gh release.
# Usage: ./scripts/release.sh 1.0.0
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NEW_VERSION="${1:?usage: release.sh <x.y.z>}"
APP_NAME="AirplaneAI"

print "==> Release ${APP_NAME} ${NEW_VERSION}"

# 1. Bump version (SSOT is .version).
print "$NEW_VERSION" > "$ROOT_DIR/.version"

# 2. Quality gate.
cd "$ROOT_DIR"
swift test --parallel
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-no-forbidden-deps.sh
./Tools/ci/verify-model-manifest.sh

# 3. Build + distribute + notarize + verify bundle.
./scripts/build-dist.sh
./scripts/notarize.sh
./Tools/ci/verify-app-bundle.sh

# 4. Commit + tag + push + release.
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

print "==> Released v${NEW_VERSION}"
