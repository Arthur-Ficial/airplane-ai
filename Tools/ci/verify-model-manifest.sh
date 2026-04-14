#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

MODEL="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model.gguf"
MANIFEST="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model-manifest.json"

if [[ ! -f "$MODEL" ]]; then
  if [[ "${1:-}" == "--dev" ]]; then
    step "[dev] model not present; skipping"
    exit 0
  fi
  die "model missing: $MODEL (run ./scripts/fetch-model.sh)"
fi

require_file "$MANIFEST"

expected="$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST" | grep -oE '[0-9a-fA-F]{64}')"
actual="$(sha256_file "$MODEL")"
[[ "$expected" == "$actual" ]] || die "GGUF SHA-256 mismatch (manifest $expected, actual $actual)"

step "model manifest OK ($actual)"
