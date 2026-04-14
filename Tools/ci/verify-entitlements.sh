#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

ENT="$ROOT_DIR/AirplaneAI.entitlements"
require_file "$ENT"

keys="$(grep -oE '<key>[^<]+</key>' "$ENT" | sed -E 's#</?key>##g' | sort -u)"
allowed_sorted="$(
  printf '%s\n' \
    "com.apple.security.app-sandbox" \
    "com.apple.security.device.audio-input" \
    "com.apple.security.files.user-selected.read-only" | sort -u
)"

if [[ "$keys" != "$allowed_sorted" ]]; then
  printf 'entitlements contain forbidden keys:\n' >&2
  printf '  found:   %s\n' "$keys" >&2
  printf '  allowed: %s\n' "$allowed_sorted" >&2
  exit 1
fi

value="$("/usr/libexec/PlistBuddy" -c "Print :com.apple.security.app-sandbox" "$ENT" 2>/dev/null || true)"
[[ "$value" == "true" ]] || die "app-sandbox is not true (got '$value')"

step "entitlements OK"
