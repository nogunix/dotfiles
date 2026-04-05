#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run_health=0

if [[ "${1:-}" == "--health" ]]; then
  run_health=1
  shift
fi

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/nvim-headless.XXXXXX")"
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

export XDG_CONFIG_HOME="$repo_root/nvim/.config"
export XDG_CACHE_HOME="$tmp_root/cache"
export XDG_STATE_HOME="$tmp_root/state"
export XDG_RUNTIME_DIR="$tmp_root/runtime"

mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"

cmd=(
  nvim
  --headless
  "+Lazy! load all"
)

if [[ "$run_health" -eq 1 ]]; then
  cmd+=("+checkhealth")
fi

cmd+=("+qa")

exec "${cmd[@]}" "$@"
