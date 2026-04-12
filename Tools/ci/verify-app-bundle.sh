#!/bin/zsh
# Post-build assertion: the built .app contains the resource bundle at the path
# SwiftPM's generated Bundle.module accessor expects, plus the bundled model.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT_DIR/build/AirplaneAI.app"
REQUIRED_BUNDLE="$APP/AirplaneAI_AirplaneAI.bundle"
REQUIRED_MODEL="$REQUIRED_BUNDLE/airplane-model.gguf"
REQUIRED_MANIFEST="$REQUIRED_BUNDLE/airplane-model-manifest.json"
REQUIRED_PROMPT="$REQUIRED_BUNDLE/SystemPrompt.txt"

[[ -d "$APP" ]]               || { print -u2 "✗ missing: $APP"; exit 1; }
[[ -d "$REQUIRED_BUNDLE" ]]   || { print -u2 "✗ missing: $REQUIRED_BUNDLE"; exit 1; }
[[ -f "$REQUIRED_MODEL" ]]    || { print -u2 "✗ missing: $REQUIRED_MODEL"; exit 1; }
[[ -f "$REQUIRED_MANIFEST" ]] || { print -u2 "✗ missing: $REQUIRED_MANIFEST"; exit 1; }
[[ -f "$REQUIRED_PROMPT" ]]   || { print -u2 "✗ missing: $REQUIRED_PROMPT"; exit 1; }

print "→ app bundle layout OK"
