#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

cd "$ROOT_DIR"

targets=(
  Sources/AirplaneAI
  scripts
  Package.swift
  Makefile
)

bad=0

if rg -n --glob '!Vendor/**' --glob '!Sources/CLlama/**' 'TODO|FIXME|HACK|XXX' "${targets[@]}"; then
  printf '✗ quality rule: TODO/FIXME/HACK/XXX markers are forbidden in first-party code\n' >&2
  bad=1
fi

if rg -n --glob '!Vendor/**' --glob '!Sources/CLlama/**' '@unchecked Sendable' "${targets[@]}"; then
  printf '✗ quality rule: @unchecked Sendable is forbidden in first-party production code\n' >&2
  bad=1
fi

if rg -n --glob '!Vendor/**' --glob '!Sources/CLlama/**' 'catch\s*\{\s*\}' "${targets[@]}"; then
  printf '✗ quality rule: empty catch blocks are forbidden in first-party code\n' >&2
  bad=1
fi

[[ "$bad" -eq 0 ]] || die "first-party quality rules failed"
step "first-party quality rules OK"
