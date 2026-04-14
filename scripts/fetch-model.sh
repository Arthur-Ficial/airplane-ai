#!/usr/bin/env bash
# Fetch the bundled GGUF model from Hugging Face. Idempotent and SHA-verified.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

MANIFEST="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model-manifest.json"
MODEL_DIR="$ROOT_DIR/Sources/AirplaneAI/Resources/models"
MODEL_PATH="$MODEL_DIR/airplane-model.gguf"
PARTIAL_DIR="$ROOT_DIR/build/downloads"
PARTIAL_PATH="$PARTIAL_DIR/airplane-model.gguf.partial"

require_file "$MANIFEST"

SOURCE_ID="$(grep -oE '"source_model_id"[[:space:]]*:[[:space:]]*"[^"]+"' "$MANIFEST" | sed -E 's/.*"([^"]+)"$/\1/')"
SOURCE_FILE="$(grep -oE '"source_file"[[:space:]]*:[[:space:]]*"[^"]+"' "$MANIFEST" | sed -E 's/.*"([^"]+)"$/\1/')"
EXPECTED_SHA="$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST" | grep -oE '[0-9a-fA-F]{64}')"
URL="https://huggingface.co/${SOURCE_ID}/resolve/main/${SOURCE_FILE}"

if [[ -f "$MODEL_PATH" ]]; then
  actual_sha="$(sha256_file "$MODEL_PATH")"
  if [[ "$actual_sha" == "$EXPECTED_SHA" ]]; then
    step "Model already present and verified"
    info "$MODEL_PATH ($EXPECTED_SHA)"
    exit 0
  fi
  warn "model exists but SHA mismatch; re-downloading"
  rm -f "$MODEL_PATH"
fi

step "Downloading ${SOURCE_FILE}"
info "$URL"
mkdir -p "$MODEL_DIR"
mkdir -p "$PARTIAL_DIR"

if [[ -f "$PARTIAL_PATH" ]]; then
  curl -L -C - --progress-bar -o "$PARTIAL_PATH" "$URL"
else
  curl -L --progress-bar -o "$PARTIAL_PATH" "$URL"
fi

actual_sha="$(sha256_file "$PARTIAL_PATH")"
if [[ "$actual_sha" != "$EXPECTED_SHA" ]]; then
  rm -f "$PARTIAL_PATH"
  die "SHA-256 mismatch after download (expected $EXPECTED_SHA, got $actual_sha)"
fi

mv "$PARTIAL_PATH" "$MODEL_PATH"
step "Model verified"
info "$(du -h "$MODEL_PATH" | awk '{print $1}') at $MODEL_PATH"
