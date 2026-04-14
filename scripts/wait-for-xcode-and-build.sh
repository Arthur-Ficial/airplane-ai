#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

step "Waiting for Xcode.app to appear in /Applications"
while [[ ! -d "/Applications/Xcode.app" ]]; do
  sleep 10
  if [[ -d "/Applications/Xcode.appdownload" ]]; then
    info "Still downloading... $(du -sh "/Applications/Xcode.appdownload" 2>/dev/null | awk '{print $1}')"
  fi
done

step "Switching toolchain"
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

step "Accepting Xcode license"
sudo xcodebuild -license accept 2>/dev/null || true

step "Running setup"
"$ROOT_DIR/scripts/setup-dev.sh"

step "Building app bundle"
cd "$ROOT_DIR"
make app

step "All done"
info "$ROOT_DIR/build/AirplaneAI.app"
