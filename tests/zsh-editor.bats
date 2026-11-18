#!/usr/bin/env bats

# EDITOR / VISUAL from zsh/.zshrc. git, crontab and Claude Code's Ctrl-G all
# shell out to $EDITOR; left unset they fall back to a bare vi.

setup() {
  command -v zsh >/dev/null || skip "zsh not installed"

  EDITOR_TMP="$(mktemp -d "${TMPDIR:-/tmp}/zsh-editor.XXXXXX")"
  # .zshrc cannot be sourced here (it bootstraps zinit), so pull out the block.
  awk '/^# Editor for anything/,/^fi$/' \
    "$BATS_TEST_DIRNAME/../zsh/.zshrc" >"$EDITOR_TMP/editor.zsh"
  [ -s "$EDITOR_TMP/editor.zsh" ]

  mkdir -p "$EDITOR_TMP/bin"
  printf '#!/bin/sh\n' >"$EDITOR_TMP/bin/nvim"
  chmod +x "$EDITOR_TMP/bin/nvim"
  mkdir -p "$EDITOR_TMP/empty"
  # Absolute, so PATH can be cut down to a directory we control: a real nvim
  # in /usr/bin (apt, dnf) would otherwise answer the "missing" case.
  ZSH_BIN="$(command -v zsh)"
}

teardown() {
  rm -rf "$EDITOR_TMP"
}

@test "EDITOR and VISUAL are nvim when nvim is installed" {
  run env -u EDITOR -u VISUAL PATH="$EDITOR_TMP/bin" \
    "$ZSH_BIN" -f -c "source '$EDITOR_TMP/editor.zsh'; print -r -- \"\$EDITOR \$VISUAL\""
  [ "$status" -eq 0 ]
  [ "$output" = "nvim nvim" ]
}

@test "EDITOR is left alone when nvim is missing" {
  # Pointing it at a command that does not exist would be worse than vi.
  run env -u EDITOR -u VISUAL PATH="$EDITOR_TMP/empty" \
    "$ZSH_BIN" -f -c "source '$EDITOR_TMP/editor.zsh'; print -r -- \"[\${EDITOR-unset}]\""
  [ "$status" -eq 0 ]
  [ "$output" = "[unset]" ]
}
