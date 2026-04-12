#!/bin/zsh
# Recomputes SHA-256 of the bundled GGUF and compares to the manifest.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MODEL="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model.gguf"
MANIFEST="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model-manifest.json"

if [[ ! -f "$MODEL" ]]; then
    print "→ no bundled model yet — skipping manifest check (M2 will populate it)"
    exit 0
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
