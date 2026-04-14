#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

cd "$ROOT_DIR"
VENDOR_DYLIB_DIR="$ROOT_DIR/Vendor/llama.cpp/llama-b8763"

step "Airplane AI developer setup"
info "Machine: $(whoami)@$(hostname)"
info "Date: $(date +%Y-%m-%d)"

step "[1/6] Checking prerequisites"
XCODE_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ "$XCODE_PATH" == "/Library/Developer/CommandLineTools" ]] || [[ -z "$XCODE_PATH" ]]; then
  if [[ -d "/Applications/Xcode.app" ]]; then
    info "Switching xcode-select to Xcode.app"
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  else
    die "Xcode.app required (SwiftData @Model macros need the full toolchain)"
  fi
fi

info "Swift: $(swift --version 2>&1 | head -1)"
os_ver="$(sw_vers -productVersion)"
os_major="${os_ver%%.*}"
(( os_major >= 15 )) || die "macOS 15+ required (got $os_ver)"
info "macOS: $os_ver"

arch="$(uname -m)"
[[ "$arch" == "arm64" ]] || die "Apple Silicon required (got $arch)"
info "Arch: $arch"

require_dir "$VENDOR_DYLIB_DIR"
info "Vendor dylibs: $(find "$VENDOR_DYLIB_DIR" -maxdepth 1 \( -type f -o -type l \) -name '*.dylib' | wc -l | tr -d ' ')"

step "[2/6] Checking Xcode license"
if ! xcodebuild -license check 2>/dev/null; then
  info "Accepting Xcode license"
  sudo xcodebuild -license accept
fi

step "[3/6] Fetching AI model"
"$ROOT_DIR/scripts/fetch-model.sh"

step "[4/6] Building release"
"$ROOT_DIR/scripts/with-build-lock.sh" swift build -c release

step "[5/6] Running fast tests"
"$ROOT_DIR/scripts/with-build-lock.sh" "$ROOT_DIR/scripts/line-buffered.sh" swift test --parallel

step "[6/6] Running verification scripts"
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-no-forbidden-deps.sh
./Tools/ci/verify-model-manifest.sh

step "Setup complete"
info "Next: make app"
