#!/bin/zsh
# Fails if Package.resolved contains any dependency outside the allow-list.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVED="$ROOT_DIR/Package.resolved"

# Pre-first-resolve (no Package.resolved yet) is fine — nothing to check.
if [[ ! -f "$RESOLVED" ]]; then
    print "→ no Package.resolved yet — skipping dep allow-list check"
    exit 0
fi

# Allow-list of identities (package URL basenames) that v1 permits.
ALLOWED="llama.cpp"

# Extract identity fields from Package.resolved (swift-tools 5.6+ format).
IDENTS=$(grep -oE '"identity"[[:space:]]*:[[:space:]]*"[^"]+"' "$RESOLVED" | sed -E 's/.*"([^"]+)"[^"]*$/\1/' | sort -u)

BAD=0
while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    case "$id" in
        llama.cpp|llama-cpp) ;;
        *)
            print -u2 "✗ forbidden dependency: $id"
            BAD=1
            ;;
    esac
done <<< "$IDENTS"

if [[ "$BAD" -eq 1 ]]; then
    print -u2 "→ FAIL: only $ALLOWED is permitted"
    exit 1
fi

print "→ dep allow-list OK"
