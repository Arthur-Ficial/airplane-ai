#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  printf 'usage: line-buffered.sh <command> [args...]\n' >&2
  exit 1
fi

if command -v stdbuf >/dev/null 2>&1; then
  exec stdbuf -oL -eL "$@"
fi

if command -v gstdbuf >/dev/null 2>&1; then
  exec gstdbuf -oL -eL "$@"
fi

if command -v script >/dev/null 2>&1; then
  set +e
  script -q /dev/null "$@" | perl -pe 's/\^D\x08\x08//g; s/\r$//'
  status=${PIPESTATUS[0]}
  exit "$status"
fi

exec "$@"
