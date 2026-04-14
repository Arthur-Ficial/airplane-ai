#!/usr/bin/env bash
# Build AirplaneAI.app from the SwiftPM release binary.
# Keeps the bundle incremental so warm builds avoid re-copying multi-GB assets.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

if [[ "${AIRPLANE_BUILD_LOCK_HELD:-}" != "1" ]]; then
  exec "$ROOT_DIR/scripts/with-build-lock.sh" "$0" "$@"
fi

APP_NAME="AirplaneAI"
APP_BUNDLE="$ROOT_DIR/build/${APP_NAME}.app"
BUILD_DIR="$ROOT_DIR/build"
CACHE_DIR="$BUILD_DIR/.cache"
APP_STATE_SENTINEL="$CACHE_DIR/app-bundle.state"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
VERSION="$(tr -d '\n' < "$ROOT_DIR/.version")"
BIN_CONFIG="release"
BIN_DIR=""
BIN_PATH=""
INFO_TEMPLATE="$ROOT_DIR/Info.plist"
INFO_PLIST="$CONTENTS_DIR/Info.plist"
ICON_SOURCE="$ROOT_DIR/Sources/AirplaneAI/Resources/AppIcon.icns"
PRIVACY_SOURCE="$ROOT_DIR/PrivacyInfo.xcprivacy"
MODEL_SOURCE="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model.gguf"
MANIFEST_SOURCE="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model-manifest.json"
PROMPT_SOURCE="$ROOT_DIR/Sources/AirplaneAI/Resources/prompts/SystemPrompt.txt"
STRINGS_SOURCE="$ROOT_DIR/Sources/AirplaneAI/Resources/Localizable.xcstrings"
LICENSES_DIR="$ROOT_DIR/Sources/AirplaneAI/Resources/licenses"
LLAMA_DYLIB_DIR="$ROOT_DIR/Vendor/llama.cpp/llama-b8763"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-$ROOT_DIR/AirplaneAI.entitlements}"
MODEL_VERIFY_SENTINEL="$CACHE_DIR/model-source.state"
MODEL_COPY_SENTINEL="$RESOURCES_DIR/.airplane-model.state"
MODEL_EXPECTED_SHA="$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST_SOURCE" | grep -oE '[0-9a-fA-F]{64}')"
MODEL_SOURCE_STATE=""
TEMP_INFO_STATE_PATH="$CACHE_DIR/Info.plist"
bundle_changed=0

codesign_path() {
  local target="$1"
  shift || true
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" "$@" "$target"
  else
    codesign --force --timestamp --options runtime --sign "$SIGN_IDENTITY" "$@" "$target"
  fi
}

mark_changed() {
  bundle_changed=1
}

sync_small_file() {
  local src="$1"
  local dest="$2"

  if sync_file "$src" "$dest"; then
    mark_changed
  fi
}

sync_optional_small_file() {
  local src="$1"
  local dest="$2"

  [[ -f "$src" ]] || return 0
  sync_small_file "$src" "$dest"
}

sync_model_file() {
  local dest="$RESOURCES_DIR/airplane-model.gguf"
  local current_state

  require_file "$MODEL_SOURCE"
  current_state="${MODEL_EXPECTED_SHA}|$(file_fingerprint "$MODEL_SOURCE")"

  if [[ -f "$MODEL_VERIFY_SENTINEL" ]] && [[ "$(cat "$MODEL_VERIFY_SENTINEL")" != "$current_state" ]]; then
    rm -f "$MODEL_VERIFY_SENTINEL"
  fi

  if [[ ! -f "$MODEL_VERIFY_SENTINEL" ]]; then
    step "Verifying bundled model SHA-256"
    actual_sha="$(sha256_file "$MODEL_SOURCE")"
    [[ "$actual_sha" == "$MODEL_EXPECTED_SHA" ]] || die "model SHA-256 mismatch (expected $MODEL_EXPECTED_SHA, got $actual_sha)"
    mkdir -p "$CACHE_DIR"
    printf '%s\n' "$current_state" > "$MODEL_VERIFY_SENTINEL"
  else
    info "Model SHA cache hit"
  fi

  MODEL_SOURCE_STATE="$current_state"

  if [[ -f "$dest" ]] && [[ -f "$MODEL_COPY_SENTINEL" ]] && [[ "$(cat "$MODEL_COPY_SENTINEL")" == "$current_state" ]]; then
    info "Model already staged in app bundle"
    return 0
  fi

  step "Staging bundled model"
  clone_or_copy_file "$MODEL_SOURCE" "$dest"
  printf '%s\n' "$current_state" > "$MODEL_COPY_SENTINEL"
  mark_changed
}

sync_frameworks() {
  local output

  require_dir "$LLAMA_DYLIB_DIR"
  mkdir -p "$FRAMEWORKS_DIR"
  output="$(
    rsync -a --delete --omit-dir-times --itemize-changes \
      --include='lib*.dylib' \
      --include='*/' \
      --exclude='*' \
      "$LLAMA_DYLIB_DIR"/ "$FRAMEWORKS_DIR"/
  )"
  if [[ -n "$output" ]]; then
    mark_changed
    printf '%s\n' "$output" | sed 's/^/    /'
  else
    info "Frameworks already up to date"
  fi
}

sync_shader_resources() {
  local output

  mkdir -p "$RESOURCES_DIR"
  output="$(
    rsync -a --omit-dir-times --itemize-changes \
      --include='*.metallib' \
      --include='*.metal' \
      --include='*/' \
      --exclude='*' \
      "$LLAMA_DYLIB_DIR"/ "$RESOURCES_DIR"/
  )"
  if [[ -n "$output" ]]; then
    mark_changed
    printf '%s\n' "$output" | sed 's/^/    /'
  else
    info "Shader resources already up to date"
  fi
}

prepare_info_plist() {
  require_file "$INFO_TEMPLATE"
  mkdir -p "$CACHE_DIR"
  cp "$INFO_TEMPLATE" "$TEMP_INFO_STATE_PATH"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${VERSION}" "$TEMP_INFO_STATE_PATH" >/dev/null
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$TEMP_INFO_STATE_PATH" >/dev/null
}

stage_info_plist() {
  sync_small_file "$TEMP_INFO_STATE_PATH" "$INFO_PLIST"
}

collect_path_state() {
  local path="$1"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    printf '%s|missing\n' "$path"
    return 0
  fi

  if [[ -L "$path" ]]; then
    printf '%s|link|%s\n' "$path" "$(readlink "$path")"
    return 0
  fi

  printf '%s|%s\n' "$path" "$(file_fingerprint "$path")"
}

compute_tree_state() {
  local dir="$1"
  local pattern="$2"

  find "$dir" -maxdepth 1 \( -type f -o -type l \) -name "$pattern" -print0 | sort -z | while IFS= read -r -d '' path; do
    collect_path_state "$path"
  done
}

compute_bundle_state() {
  {
    printf 'version|%s\n' "$VERSION"
    printf 'sign|%s\n' "$SIGN_IDENTITY"
    collect_path_state "$BIN_PATH"
    printf '%s|sha256|%s\n' "$TEMP_INFO_STATE_PATH" "$(sha256_file "$TEMP_INFO_STATE_PATH")"
    collect_path_state "$ICON_SOURCE"
    collect_path_state "$PRIVACY_SOURCE"
    collect_path_state "$MANIFEST_SOURCE"
    collect_path_state "$PROMPT_SOURCE"
    collect_path_state "$STRINGS_SOURCE"
    collect_path_state "$ENTITLEMENTS"
    printf 'model|%s\n' "$MODEL_SOURCE_STATE"
    compute_tree_state "$LICENSES_DIR" '*.txt'
    compute_tree_state "$LLAMA_DYLIB_DIR" 'lib*.dylib'
    compute_tree_state "$LLAMA_DYLIB_DIR" '*.metallib'
    compute_tree_state "$LLAMA_DYLIB_DIR" '*.metal'
  }
}

assert_bundle_layout() {
  require_dir "$APP_BUNDLE"
  require_dir "$MACOS_DIR"
  require_dir "$RESOURCES_DIR"
  require_dir "$FRAMEWORKS_DIR"
  require_file "$MACOS_DIR/${APP_NAME}"
  require_file "$INFO_PLIST"
  require_file "$RESOURCES_DIR/airplane-model.gguf"
  require_file "$RESOURCES_DIR/airplane-model-manifest.json"
  require_file "$RESOURCES_DIR/SystemPrompt.txt"
  require_file "$FRAMEWORKS_DIR/libllama.dylib"

  [[ -s "$MACOS_DIR/${APP_NAME}" ]] || die "empty app binary: $MACOS_DIR/${APP_NAME}"
}

step "Building ${APP_NAME} ${VERSION}"
require_file "$ROOT_DIR/.version"
require_file "$MANIFEST_SOURCE"

step "Compiling SwiftPM release binary"
swift build -c "$BIN_CONFIG" --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c "$BIN_CONFIG" --show-bin-path --package-path "$ROOT_DIR")"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
require_file "$BIN_PATH"

step "Preparing bundle directories"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$CACHE_DIR"
prepare_info_plist
sync_model_file

current_bundle_state="$(compute_bundle_state)"
if [[ -d "$APP_BUNDLE" ]] && [[ -f "$APP_STATE_SENTINEL" ]] && [[ "$(cat "$APP_STATE_SENTINEL")" == "$current_bundle_state" ]]; then
  step "App bundle already up to date"
  assert_bundle_layout
  exit 0
fi

step "Staging executable"
sync_small_file "$BIN_PATH" "$MACOS_DIR/${APP_NAME}"
chmod +x "$MACOS_DIR/${APP_NAME}"

step "Staging metadata"
stage_info_plist
sync_optional_small_file "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
sync_optional_small_file "$PRIVACY_SOURCE" "$RESOURCES_DIR/PrivacyInfo.xcprivacy"

step "Staging frameworks"
sync_frameworks

step "Staging shaders"
sync_shader_resources

step "Staging app resources"
sync_small_file "$MANIFEST_SOURCE" "$RESOURCES_DIR/airplane-model-manifest.json"
sync_small_file "$PROMPT_SOURCE" "$RESOURCES_DIR/SystemPrompt.txt"
sync_small_file "$STRINGS_SOURCE" "$RESOURCES_DIR/Localizable.xcstrings"
for license_file in "$LICENSES_DIR"/*.txt; do
  [[ -f "$license_file" ]] || continue
  sync_small_file "$license_file" "$RESOURCES_DIR/$(basename "$license_file")"
done

step "Asserting bundle completeness"
assert_bundle_layout

if [[ "$bundle_changed" -eq 1 ]]; then
  step "Signing bundle (${SIGN_IDENTITY})"
  xattr -cr "$APP_BUNDLE" 2>/dev/null || true
  if [[ -f "$ENTITLEMENTS" ]]; then
    codesign_path "$APP_BUNDLE" --entitlements "$ENTITLEMENTS"
  else
    codesign_path "$APP_BUNDLE"
  fi
  printf '%s\n' "$current_bundle_state" > "$APP_STATE_SENTINEL"
else
  step "Bundle unchanged; reusing existing signature"
fi

step "Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [[ "$bundle_changed" -eq 0 ]]; then
  printf '%s\n' "$current_bundle_state" > "$APP_STATE_SENTINEL"
fi

step "Built ${APP_BUNDLE}"
