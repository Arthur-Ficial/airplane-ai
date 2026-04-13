#!/bin/zsh
# Waits for Xcode to finish installing, switches toolchain, then runs full setup.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

print "==> Waiting for Xcode.app to appear in /Applications..."

while [[ ! -d "/Applications/Xcode.app" ]]; do
    sleep 10
    # Check if still downloading
    if [[ -d "/Applications/Xcode.appdownload" ]]; then
        SIZE=$(du -sh "/Applications/Xcode.appdownload" 2>/dev/null | awk '{print $1}')
        print "    Still downloading... ($SIZE)"
    fi
done

print "==> Xcode.app found! Switching toolchain..."
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

print "==> Accepting Xcode license..."
sudo xcodebuild -license accept 2>/dev/null || true

print "==> Running full setup..."
"$ROOT_DIR/scripts/setup-dev.sh"

print "==> Building .app bundle..."
cd "$ROOT_DIR"
make app

print "==> All done! AirplaneAI.app is at: $ROOT_DIR/build/AirplaneAI.app"
