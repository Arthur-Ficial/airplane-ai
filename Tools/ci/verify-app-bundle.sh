#!/bin/zsh
# Post-build assertion: the built .app contains the required resources flat
# in Contents/Resources (how ModelLocator.find() expects them).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT_DIR/build/AirplaneAI.app"
RES="$APP/Contents/Resources"

[[ -d "$APP" ]]                                      || { print -u2 "✗ missing: $APP"; exit 1; }
[[ -f "$RES/airplane-model.gguf" ]]                  || { print -u2 "✗ missing: $RES/airplane-model.gguf"; exit 1; }
[[ -f "$RES/airplane-model-manifest.json" ]]         || { print -u2 "✗ missing: $RES/airplane-model-manifest.json"; exit 1; }
[[ -f "$RES/SystemPrompt.txt" ]]                     || { print -u2 "✗ missing: $RES/SystemPrompt.txt"; exit 1; }
[[ -f "$APP/Contents/Info.plist" ]]                  || { print -u2 "✗ missing: Info.plist"; exit 1; }
[[ -d "$APP/Contents/Frameworks" ]]                  || { print -u2 "✗ missing: Frameworks/"; exit 1; }
[[ -f "$APP/Contents/Frameworks/libllama.dylib" ]]   || { print -u2 "✗ missing: libllama.dylib in Frameworks/"; exit 1; }

# SHA-256 cross-check: bundled model must match manifest.
MANIFEST="$RES/airplane-model-manifest.json"
EXPECTED=$(grep -oE '"gguf_sha256"[[:space:]]*:[[:space:]]*"[0-9a-fA-F]{64}"' "$MANIFEST" | grep -oE '[0-9a-fA-F]{64}')
ACTUAL=$(shasum -a 256 "$RES/airplane-model.gguf" | awk '{print $1}')
[[ "$EXPECTED" == "$ACTUAL" ]] || { print -u2 "✗ model SHA-256 mismatch in bundle"; exit 1; }

print "→ app bundle layout OK (model sha256: $ACTUAL)"
