#!/usr/bin/env bats

# Behaviour of the Neovim config once its plugins are installed. Each test
# runs the real config headlessly with throwaway cache/state dirs, and writes
# what it observed to a file, because headless Neovim's own output is noisy.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  NVIM_TMP="$(mktemp -d "${TMPDIR:-/tmp}/nvim-config.XXXXXX")"
  export XDG_CONFIG_HOME="$REPO_ROOT/nvim/.config"
  export XDG_CACHE_HOME="$NVIM_TMP/cache"
  export XDG_STATE_HOME="$NVIM_TMP/state"
  export XDG_RUNTIME_DIR="$NVIM_TMP/runtime"
  mkdir -p "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
  LAZY_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"
}

teardown() {
  rm -rf "$NVIM_TMP"
}

need_plugins() {
  command -v nvim >/dev/null || skip "nvim not installed"
  local p
  for p in "$@"; do
    [ -d "$LAZY_DIR/$p" ] || skip "$p not installed; run :Lazy install"
  done
}

# Open $1 in the config, run the Lua in $2, and leave what it wrote in $OUT.
probe() {
  local file="$1" lua="$2"
  OUT="$NVIM_TMP/out"
  # pcall, so that a failing probe still quits instead of leaving headless
  # Neovim waiting forever (macOS has no `timeout` to fall back on).
  printf '%s\n' "local out = {}" "local ok, err = pcall(function()" "$lua" "end)" \
    "if not ok then out = { 'probe error: ' .. tostring(err) } end" \
    "vim.fn.writefile(out, '$OUT')" "vim.cmd('qa!')" >"$NVIM_TMP/probe.lua"
  nvim --headless "$file" "+luafile $NVIM_TMP/probe.lua" >/dev/null 2>&1 || true
  [ -f "$OUT" ]
}

@test "opening a file enables the LSP servers without loading mason" {
  need_plugins nvim-lspconfig mason.nvim
  # mason costs ~20 ms to load and is only needed to install servers.
  probe "$REPO_ROOT/nvim/.config/nvim/init.lua" "
    local plugins = require('lazy.core.config').plugins
    out[1] = plugins['mason.nvim']._.loaded and 'mason loaded' or 'mason idle'
    out[2] = plugins['nvim-lspconfig']._.loaded and 'lspconfig loaded' or 'lspconfig idle'
    out[3] = vim.lsp.is_enabled('lua_ls') and 'lua_ls enabled' or 'lua_ls disabled'
  "
  run cat "$OUT"
  [[ "$output" == *"mason idle"* ]]
  [[ "$output" == *"lspconfig loaded"* ]]
  [[ "$output" == *"lua_ls enabled"* ]]
}

@test "lua_ls indexes Neovim's runtime, not every plugin on the rtp" {
  need_plugins nvim-lspconfig
  probe "$REPO_ROOT/nvim/.config/nvim/init.lua" "
    local lib = vim.lsp.config.lua_ls.settings.Lua.workspace.library
    out[1] = #lib .. ' ' .. tostring(lib[1] == vim.env.VIMRUNTIME)
  "
  run cat "$OUT"
  [ "$output" = "1 true" ]
}

@test "mason's bin dir is on PATH before mason itself loads" {
  need_plugins mason.nvim
  probe "" "
    out[1] = vim.tbl_contains(vim.split(vim.env.PATH, ':', { plain = true }),
      vim.fn.stdpath('data') .. '/mason/bin') and 'on PATH' or 'missing'
  "
  run cat "$OUT"
  [ "$output" = "on PATH" ]
}
