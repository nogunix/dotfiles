#!/usr/bin/env bats

set -euo pipefail

setup() {
  set -euo pipefail
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TS_TMP="$(mktemp -d "${TMPDIR:-/tmp}/nvim-ts.XXXXXX")"
  export XDG_CONFIG_HOME="$REPO_ROOT/nvim/.config"
  export XDG_CACHE_HOME="$TS_TMP/cache"
  export XDG_STATE_HOME="$TS_TMP/state"
  export XDG_RUNTIME_DIR="$TS_TMP/runtime"
  mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
}

teardown() {
  rm -rf "$TS_TMP"
}

@test "nvim loads config without treesitter range error" {
  command -v nvim >/dev/null || skip "nvim not installed"
  [ -d "$HOME/.local/share/nvim/lazy/nvim-treesitter" ] \
    || skip "nvim-treesitter not installed; run :Lazy install"

  run nvim --headless "+Lazy! load all" "+qa"
  [ "$status" -eq 0 ]
  [[ "$output" != *"attempt to call method 'range'"* ]]
}

@test "treesitter attaches to a lua buffer and parses without error" {
  command -v nvim >/dev/null || skip "nvim not installed"
  [ -d "$HOME/.local/share/nvim/lazy/nvim-treesitter" ] \
    || skip "nvim-treesitter not installed; run :Lazy install"

  run nvim --headless \
    "+luafile $BATS_TEST_DIRNAME/nvim-treesitter-smoke.lua"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TREESITTER SMOKE OK"* ]]
  [[ "$output" != *"attempt to call method 'range'"* ]]
}
