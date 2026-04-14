#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

LOCK_FILE="$ROOT_DIR/.build/workspace-state.json.lock"
BUILD_LOCK_DIR="$ROOT_DIR/build/.airplane-build.lock"

step "Checking Airplane build lock"
if [[ -d "$BUILD_LOCK_DIR" ]]; then
  pid="$(<"$BUILD_LOCK_DIR/pid" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    die "repo build lock is still held by pid $pid"
  fi
  rm -rf "$BUILD_LOCK_DIR"
  info "Removed stale repo build lock"
else
  info "No repo build lock present"
fi

step "Checking SwiftPM workspace lock"
if [[ -f "$LOCK_FILE" ]]; then
  if /usr/sbin/lsof "$LOCK_FILE" >/dev/null 2>&1; then
    die "SwiftPM workspace lock is still held by a live process"
  fi
  rm -f "$LOCK_FILE"
  info "Removed stale SwiftPM workspace lock"
else
  info "No SwiftPM workspace lock present"
fi

step "Done"
