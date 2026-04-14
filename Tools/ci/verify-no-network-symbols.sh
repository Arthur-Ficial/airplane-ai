#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

cd "$ROOT_DIR"

forbidden=(
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

found=0
for pattern in "${forbidden[@]}"; do
  if grep -RIn --include='*.swift' -E "$pattern" Sources 2>/dev/null | grep -vE '^\s*(//|/\*)'; then
    printf '✗ forbidden symbol: %s\n' "$pattern" >&2
    found=1
  fi
done

[[ "$found" -eq 0 ]] || die "forbidden network symbols found in Sources/"
step "no forbidden network symbols in Sources/"
