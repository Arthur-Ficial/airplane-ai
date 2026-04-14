#!/usr/bin/env bash

step() {
  printf '==> %s\n' "$*"
}

info() {
  printf '    %s\n' "$*"
}

warn() {
  printf '⚠ %s\n' "$*" >&2
}

die() {
  printf '✗ %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "missing file: $1"
}

require_dir() {
  [[ -d "$1" ]] || die "missing directory: $1"
}

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}

file_fingerprint() {
  stat -f '%i:%z:%m' "$1"
}

sync_file() {
  local src="$1"
  local dest="$2"

  require_file "$src"
  mkdir -p "$(dirname "$dest")"

  if [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    return 1
  fi

  cp -f "$src" "$dest"
}

clone_or_copy_file() {
  local src="$1"
  local dest="$2"

  require_file "$src"
  mkdir -p "$(dirname "$dest")"

  if cp -f -c "$src" "$dest" 2>/dev/null; then
    return 0
  fi

  cp -f "$src" "$dest"
}
