#!/bin/zsh
# Fails if the entitlements file contains any key other than app-sandbox.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENT="$ROOT_DIR/AirplaneAI.entitlements"

[[ -f "$ENT" ]] || { print -u2 "missing: $ENT"; exit 1; }

# Extract all <key>...</key> entries.
KEYS=$(grep -oE '<key>[^<]+</key>' "$ENT" | sed -E 's#</?key>##g' | sort -u)

# Allow-list: sandbox + audio-input only. Nothing else — ever.
ALLOWED=(
    "com.apple.security.app-sandbox"
    "com.apple.security.device.audio-input"
)
ALLOWED_SORTED=$(printf '%s\n' "${ALLOWED[@]}" | sort -u)

if [[ "$KEYS" != "$ALLOWED_SORTED" ]]; then
    print -u2 "entitlements contain forbidden keys:"
    print -u2 "  found:   $KEYS"
    print -u2 "  allowed: $ALLOWED_SORTED"
    exit 1
fi

# Sandbox value must be <true/>.
VAL=$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "$ENT" 2>/dev/null || echo "")
if [[ "$VAL" != "true" ]]; then
    print -u2 "app-sandbox is not true (got: '$VAL')"
    exit 1
fi

print "→ entitlements OK (sandbox + audio-input)"
