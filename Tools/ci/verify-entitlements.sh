#!/bin/zsh
# Fails if the entitlements file contains any key other than app-sandbox.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
ENT="$ROOT_DIR/AirplaneAI.entitlements"

[[ -f "$ENT" ]] || { print -u2 "missing: $ENT"; exit 1; }

# Extract all <key>...</key> entries.
KEYS=$(grep -oE '<key>[^<]+</key>' "$ENT" | sed -E 's#</?key>##g' | sort -u)
EXPECTED="com.apple.security.app-sandbox"

if [[ "$KEYS" != "$EXPECTED" ]]; then
    print -u2 "entitlements contain forbidden keys:"
    print -u2 "$KEYS"
    exit 1
fi

# Sandbox value must be <true/> via PlistBuddy — authoritative, whitespace-agnostic.
VAL=$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "$ENT" 2>/dev/null || echo "")
if [[ "$VAL" != "true" ]]; then
    print -u2 "app-sandbox is not true (got: '$VAL')"
    exit 1
fi

print "→ entitlements OK (sandbox-only)"
