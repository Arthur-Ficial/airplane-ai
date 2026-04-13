#!/bin/zsh
# Fetch the bundled GGUF model from Hugging Face. Idempotent — skips if present and verified.
# All parameters read from the manifest (SSOT). No hardcoded model names or hashes.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST="$ROOT_DIR/Sources/AirplaneAI/Resources/models/airplane-model-manifest.json"
MODEL_DIR="$ROOT_DIR/Sources/AirplaneAI/Resources/models"
MODEL_PATH="$MODEL_DIR/airplane-model.gguf"
PARTIAL_PATH="${MODEL_PATH}.partial"

[[ -f "$MANIFEST" ]] || { print -u2 "✗ manifest missing: $MANIFEST"; exit 1; }

# Read SSOT fields from manifest (no jq dependency).
SOURCE_ID=$(grep -oE '"source_model_id"[[:space:]]*:[[:space:]]*"[^"]+"' "$MANIFEST" | sed -E 's/.*"([^"]+)"$/\1/')
SOURCE_FILE=$(grep -oE '"source_file"[[:space:]]*:[[:space:]]*"[^"]+"' "$MANIFEST" | sed -E 's/.*"([^"]+)"$/\1/')
EXPECTED_SHA=$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST" | grep -oE '[0-9a-fA-F]{64}')
URL="https://huggingface.co/${SOURCE_ID}/resolve/main/${SOURCE_FILE}"

# Short-circuit if model already present and verified.
if [[ -f "$MODEL_PATH" ]]; then
    ACTUAL_SHA=$(shasum -a 256 "$MODEL_PATH" | awk '{print $1}')
    if [[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]]; then
        print "→ model already present and verified ($EXPECTED_SHA)"
        exit 0
    fi
    print "⚠ model exists but SHA mismatch — re-downloading"
    rm -f "$MODEL_PATH"
fi

print "==> Downloading $SOURCE_FILE from Hugging Face..."
print "    URL: $URL"
mkdir -p "$MODEL_DIR"

# Resume-capable download to .partial file.
if [[ -f "$PARTIAL_PATH" ]]; then
    curl -L -C - --progress-bar -o "$PARTIAL_PATH" "$URL"
else
    curl -L --progress-bar -o "$PARTIAL_PATH" "$URL"
fi

# Verify SHA-256 before atomic move.
ACTUAL_SHA=$(shasum -a 256 "$PARTIAL_PATH" | awk '{print $1}')
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
    print -u2 "✗ SHA-256 mismatch after download"
    print -u2 "  expected: $EXPECTED_SHA"
    print -u2 "  actual:   $ACTUAL_SHA"
    rm -f "$PARTIAL_PATH"
    exit 1
fi

mv "$PARTIAL_PATH" "$MODEL_PATH"
SIZE=$(du -h "$MODEL_PATH" | awk '{print $1}')
print "→ model verified and placed ($SIZE, sha256: $ACTUAL_SHA)"
