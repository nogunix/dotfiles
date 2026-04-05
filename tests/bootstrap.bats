#!/usr/bin/env bats

set -euo pipefail

setup() {
  set -euo pipefail
  TMPDIR="$(mktemp -d)"
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"

  STUBDIR="$TMPDIR/bin"
  mkdir "$STUBDIR"
  export PATH="$STUBDIR:$PATH"
  export STOW_LOG="$TMPDIR/stow.log"
  export PM_LOG="$TMPDIR/pm.log"

  cat >"$STUBDIR/stow" <<'STUB'
#!/bin/bash
# simple stub to capture stow args
printf '%s\n' "$*" >> "$STOW_LOG"
STUB
  chmod +x "$STUBDIR/stow"
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "bootstrap.sh --help outputs usage" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "stows packages without adopt or uninstall" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nvim" --no-install
  [ "$status" -eq 0 ]
  stow_args="$(cat "$STOW_LOG")"
  [[ "$stow_args" == *"-v -t $HOME nvim"* ]]
  [[ "$stow_args" != *"--adopt"* ]]
  [[ "$stow_args" != *"-D"* ]]
}

@test "uses --adopt when -a flag provided" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nvim" -a --no-install
  [ "$status" -eq 0 ]
  stow_args="$(cat "$STOW_LOG")"
  [[ "$stow_args" == *"--adopt"* ]]
  [[ "$stow_args" != *"-D"* ]]
}

@test "uses -D when -U flag provided" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nvim" -U --no-install
  [ "$status" -eq 0 ]
  stow_args="$(cat "$STOW_LOG")"
  [[ "$stow_args" == *"-D"* ]]
}

@test "unstows only selected packages with -u" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -u "tmux" --no-install
  [ "$status" -eq 0 ]
  stow_args="$(cat "$STOW_LOG")"
  [[ "$stow_args" == *"-D -v -t $HOME tmux"* ]]
  [[ "$stow_args" != *"nvim"* ]]
  [[ "$stow_args" != *"zsh"* ]]
}

@test "passes -n to stow when dry-run flag provided" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nvim" -n --no-install
  [ "$status" -eq 0 ]
  stow_args="$(cat "$STOW_LOG")"
  [[ "$stow_args" == *"-n -v -t $HOME nvim"* ]]
}

@test "fails when requested package is missing" {
  run /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nonexistent" --no-install
  [ "$status" -ne 0 ]
  [[ "$output" == *"Selected package 'nonexistent' not found"* ]]
}

@test "fails when no supported package manager is found" {
  temp="$(mktemp -d)"
  run env -i HOME="$temp" PATH="" /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nvim"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No supported package manager found"* ]]
  rm -rf "$temp"
}

@test "installs missing base tools with Homebrew when brew is available" {
  isolated_bin="$TMPDIR/isolated-bin"
  mkdir -p "$isolated_bin"

  for cmd in find date mv readlink head; do
    ln -s "$(command -v "$cmd")" "$isolated_bin/$cmd"
  done

  cp "$STUBDIR/stow" "$isolated_bin/stow"

  cat >"$isolated_bin/brew" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$PM_LOG"
STUB
  chmod +x "$isolated_bin/brew"

  run env -i HOME="$HOME" PATH="$isolated_bin" PM_LOG="$PM_LOG" STOW_LOG="$STOW_LOG" /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "nvim"
  [ "$status" -eq 0 ]
  brew_args="$(cat "$PM_LOG")"
  [[ "$brew_args" == "install git curl neovim tmux zsh" ]]
}

@test "installs universal-ctags with Homebrew when ctags package is selected" {
  isolated_bin="$TMPDIR/isolated-bin-ctags"
  mkdir -p "$isolated_bin"

  for cmd in find date mv readlink head; do
    ln -s "$(command -v "$cmd")" "$isolated_bin/$cmd"
  done

  cp "$STUBDIR/stow" "$isolated_bin/stow"

  cat >"$isolated_bin/brew" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$PM_LOG"
STUB
  chmod +x "$isolated_bin/brew"

  run env -i HOME="$HOME" PATH="$isolated_bin" PM_LOG="$PM_LOG" STOW_LOG="$STOW_LOG" /bin/bash "$BATS_TEST_DIRNAME/../bootstrap.sh" -p "ctags"
  [ "$status" -eq 0 ]
  brew_args="$(cat "$PM_LOG")"
  [[ "$brew_args" == *"install universal-ctags"* ]]
}
