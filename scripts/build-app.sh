#!/bin/zsh
# Build AirplaneAI.app from the SwiftPM release binary.
# Copies Info.plist, PrivacyInfo, and bundles resources. Signs with ad-hoc by default.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="AirplaneAI"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
ICON_SOURCE="$ROOT_DIR/Sources/AirplaneAI/Resources/AppIcon.icns"
LLAMA_DYLIB_DIR="$ROOT_DIR/Vendor/llama.cpp/llama-b8763"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/AirplaneAI.entitlements}"

codesign_path() {
    local target="$1"
    shift || true
    if [[ "$SIGN_IDENTITY" == "-" ]]; then
        codesign --force --sign "$SIGN_IDENTITY" "$@" "$target"
    else
        codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$@" "$target"
    fi
}

print "==> Building ${APP_NAME} ${VERSION}"
swift build -c release --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
cp "$ROOT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Bundle llama.cpp dylibs into Contents/Frameworks (@rpath @executable_path/../Frameworks).
for dylib in libllama libggml libggml-base libggml-cpu libggml-metal libggml-blas libggml-rpc libmtmd; do
    for f in "$LLAMA_DYLIB_DIR/${dylib}"*.dylib; do
        [[ -f "$f" ]] || continue
        cp "$f" "$APP_BUNDLE/Contents/Frameworks/"
    done
done

# Copy Metal shader blobs if the llama.cpp release shipped them.
setopt NULL_GLOB
for shader in "$LLAMA_DYLIB_DIR"/*.metallib "$LLAMA_DYLIB_DIR"/*.metal; do
    cp "$shader" "$APP_BUNDLE/Contents/Resources/"
done
unsetopt NULL_GLOB

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$APP_BUNDLE/Contents/Info.plist" >/dev/null

[[ -f "$ICON_SOURCE" ]] && cp "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
[[ -f "$ROOT_DIR/PrivacyInfo.xcprivacy" ]] && cp "$ROOT_DIR/PrivacyInfo.xcprivacy" "$APP_BUNDLE/Contents/Resources/"

# SwiftPM places the .bundle with processed resources next to the binary — move it in.
RES_BUNDLE="${BIN_DIR}/AirplaneAI_AirplaneAI.bundle"
[[ -d "$RES_BUNDLE" ]] && cp -R "$RES_BUNDLE" "$APP_BUNDLE/Contents/Resources/"

xattr -cr "$APP_BUNDLE" 2>/dev/null || true
print "==> Signing bundle (${SIGN_IDENTITY})"
if [[ -f "$ENTITLEMENTS" ]]; then
    codesign_path "$APP_BUNDLE" --entitlements "$ENTITLEMENTS"
else
    codesign_path "$APP_BUNDLE"
fi
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

print "==> Built ${APP_BUNDLE}"
