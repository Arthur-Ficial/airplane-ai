#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/lib.sh"

if [[ $# -eq 0 ]]; then
  die "usage: with-build-lock.sh <command> [args...]"
fi

if [[ "${AIRPLANE_BUILD_LOCK_HELD:-}" == "1" ]]; then
  exec "$@"
fi

LOCK_ROOT="$ROOT_DIR/build"
LOCK_DIR="$LOCK_ROOT/.airplane-build.lock"
PID_FILE="$LOCK_DIR/pid"
CMD_FILE="$LOCK_DIR/command"

mkdir -p "$LOCK_ROOT"

clear_stale_lock() {
  [[ -d "$LOCK_DIR" ]] || return 0

  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(<"$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      return 1
    fi
  fi

  rm -rf "$LOCK_DIR"
  return 0
}

if ! clear_stale_lock && ! mkdir "$LOCK_DIR" 2>/dev/null; then
  holder_pid="$(<"$PID_FILE" 2>/dev/null || true)"
  holder_cmd="$(<"$CMD_FILE" 2>/dev/null || true)"
  die "build lock busy (pid ${holder_pid:-unknown}: ${holder_cmd:-unknown}); wait for it to finish or run 'make unstick'"
fi

if [[ ! -d "$LOCK_DIR" ]]; then
  mkdir "$LOCK_DIR"
fi

printf '%s\n' "$$" > "$PID_FILE"
printf '%s\n' "$*" > "$CMD_FILE"

cleanup() {
  rm -rf "$LOCK_DIR"
}

trap cleanup EXIT INT TERM

export AIRPLANE_BUILD_LOCK_HELD=1
"$@"
