#!/bin/zsh
# Recomputes SHA-256 of the bundled GGUF and compares to the manifest.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MODEL="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model.gguf"
MANIFEST="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model-manifest.json"

if [[ ! -f "$MODEL" ]]; then
    if [[ "${1:-}" == "--dev" ]]; then
        print "→ [dev] model not present — skipping (run scripts/fetch-model.sh)"
        exit 0
    fi
    print -u2 "✗ model missing: $MODEL"
    print -u2 "  Run: ./scripts/fetch-model.sh"
    exit 1
fi

if [[ ! -f "$MANIFEST" ]]; then
    print -u2 "✗ model present but manifest missing: $MANIFEST"
    exit 1
fi

EXPECTED=$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST" | grep -oE '[0-9a-fA-F]{64}')
ACTUAL=$(shasum -a 256 "$MODEL" | awk '{print $1}')

if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    print -u2 "✗ GGUF SHA-256 mismatch"
    print -u2 "  manifest: $EXPECTED"
    print -u2 "  actual:   $ACTUAL"
    exit 1
fi

print "→ model manifest OK ($ACTUAL)"
