#!/bin/zsh
# Fails if any Swift source references forbidden network/web/analytics APIs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

# Patterns that must never appear in Sources/.
# Word-boundary / import-qualified matches only.
FORBIDDEN=(
    'URLSession'
    'NWConnection'
    'NWListener'
    'NWBrowser'
    'WKWebView'
    'WebView'
    'Sparkle'
    'CFNetwork'
    'BSD socket'
    'Network\.framework'
    'SocketPort'
)

FOUND=0
for pattern in "${FORBIDDEN[@]}"; do
    # Ignore comments and the verify scripts themselves.
    if grep -RIn --include='*.swift' -E "$pattern" Sources 2>/dev/null | grep -vE '^\s*(//|/\*)'; then
        print -u2 "✗ forbidden symbol: $pattern"
        FOUND=1
    fi
done

if [[ "$FOUND" -eq 1 ]]; then
    print -u2 "→ FAIL: forbidden network symbols in Sources/"
    exit 1
fi

print "→ no forbidden network symbols in Sources/"
