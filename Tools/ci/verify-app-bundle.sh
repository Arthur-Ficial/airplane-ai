#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

APP="$ROOT_DIR/build/AirplaneAI.app"
RES="$APP/Contents/Resources"
MANIFEST="$RES/airplane-model-manifest.json"

require_dir "$APP"
require_dir "$RES"
require_file "$RES/airplane-model.gguf"
require_file "$MANIFEST"
require_file "$RES/SystemPrompt.txt"
require_file "$APP/Contents/Info.plist"
require_dir "$APP/Contents/Frameworks"
require_file "$APP/Contents/Frameworks/libllama.dylib"

expected="$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST" | grep -oE '[0-9a-fA-F]{64}')"
actual="$(sha256_file "$RES/airplane-model.gguf")"
[[ "$expected" == "$actual" ]] || die "model SHA-256 mismatch in bundle"

step "app bundle layout OK ($actual)"
