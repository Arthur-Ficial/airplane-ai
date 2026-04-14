#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

RESOLVED="$ROOT_DIR/Package.resolved"
if [[ ! -f "$RESOLVED" ]]; then
  step "no Package.resolved yet; skipping dep allow-list check"
  exit 0
fi

bad=0
while IFS= read -r identity; do
  [[ -z "$identity" ]] && continue
  case "$identity" in
    llama.cpp|llama-cpp) ;;
    *)
      printf '✗ forbidden dependency: %s\n' "$identity" >&2
      bad=1
      ;;
  esac
done < <(grep -oE '"identity"[[:space:]]*:[[:space:]]*"[^"]+"' "$RESOLVED" | sed -E 's/.*"([^"]+)"[^"]*$/\1/' | sort -u)

[[ "$bad" -eq 0 ]] || die "only llama.cpp is permitted"
step "dep allow-list OK"
