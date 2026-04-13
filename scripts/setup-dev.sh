#!/bin/zsh
# One-shot developer setup for Airplane AI on a new machine.
# Verifies prerequisites, patches machine-specific paths, builds, tests, and verifies.
# Usage: ./scripts/setup-dev.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VENDOR_DYLIB_DIR="$ROOT_DIR/Vendor/llama.cpp/llama-b8763"

print "==> Airplane AI — Developer Setup"
print "    Machine: $(whoami)@$(hostname)"
print "    Date:    $(date +%Y-%m-%d)"

# ── 1. Check prerequisites ──────────────────────────────────────────────
print "\n==> [1/6] Checking prerequisites..."

# Xcode (full, not just CommandLineTools — SwiftData macros need the plugin).
XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
if [[ "$XCODE_PATH" == "/Library/Developer/CommandLineTools" ]] || [[ -z "$XCODE_PATH" ]]; then
    if [[ -d "/Applications/Xcode.app" ]]; then
        print "    Switching xcode-select to Xcode.app..."
        sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    else
        print -u2 "✗ Xcode.app required (SwiftData @Model macros need the full toolchain)."
        print -u2 "  Install from App Store: mas install 497799835"
        print -u2 "  Then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
        exit 1
    fi
fi

SWIFT_VER=$(swift --version 2>&1 | head -1)
print "    Swift: $SWIFT_VER"

# Check macOS version (15+ required).
OS_VER=$(sw_vers -productVersion)
OS_MAJOR="${OS_VER%%.*}"
if (( OS_MAJOR < 15 )); then
    print -u2 "✗ macOS 15+ required (got $OS_VER)"
    exit 1
fi
print "    macOS: $OS_VER ✓"

# Check Apple Silicon.
ARCH=$(uname -m)
if [[ "$ARCH" != "arm64" ]]; then
    print -u2 "✗ Apple Silicon required (got $ARCH)"
    exit 1
fi
print "    Arch: $ARCH ✓"

# Check vendored dylibs exist.
if [[ ! -d "$VENDOR_DYLIB_DIR" ]]; then
    print -u2 "✗ Vendored llama.cpp dylibs missing: $VENDOR_DYLIB_DIR"
    exit 1
fi
DYLIB_COUNT=$(ls "$VENDOR_DYLIB_DIR"/*.dylib 2>/dev/null | wc -l | tr -d ' ')
print "    Vendor dylibs: $DYLIB_COUNT found in $VENDOR_DYLIB_DIR ✓"

# ── 2. Patch dev rpath in Package.swift ──────────────────────────────────
print "\n==> [2/6] Patching Package.swift dev rpath for this machine..."

CURRENT_RPATH=$(grep -oE '/Users/[^"]+/Vendor/llama.cpp/llama-b8763' Package.swift | head -1 || echo "")
EXPECTED_RPATH="$VENDOR_DYLIB_DIR"

if [[ "$CURRENT_RPATH" != "$EXPECTED_RPATH" ]]; then
    if [[ -n "$CURRENT_RPATH" ]]; then
        sed -i '' "s|${CURRENT_RPATH}|${EXPECTED_RPATH}|g" Package.swift
        print "    Patched: $CURRENT_RPATH → $EXPECTED_RPATH"
    else
        print "    ⚠ Could not find dev rpath in Package.swift — manual fix may be needed"
    fi
else
    print "    Already correct: $EXPECTED_RPATH"
fi

# ── 3. Accept Xcode license (if needed) ─────────────────────────────────
print "\n==> [3/6] Checking Xcode license..."
if ! xcodebuild -license check 2>/dev/null; then
    print "    Accepting Xcode license..."
    sudo xcodebuild -license accept
fi
print "    Xcode license accepted ✓"

# ── 4. Build ─────────────────────────────────────────────────────────────
print "\n==> [4/6] Building (release)..."
swift build -c release

# ── 5. Test ──────────────────────────────────────────────────────────────
print "\n==> [5/6] Running tests..."
swift test --parallel

# ── 6. Verify (CI scripts) ──────────────────────────────────────────────
print "\n==> [6/6] Running verification scripts..."
./Tools/ci/verify-entitlements.sh
./Tools/ci/verify-no-network-symbols.sh
./Tools/ci/verify-no-forbidden-deps.sh
./Tools/ci/verify-model-manifest.sh

# ── Done ─────────────────────────────────────────────────────────────────
print "\n==> ✓ Setup complete. Next steps:"
print "    make app     # build AirplaneAI.app"
print "    make run     # build + launch"
print "    make verify  # run CI checks"
print "    make test    # run tests"
