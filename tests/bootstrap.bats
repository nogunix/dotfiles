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

  cat >"$STUBDIR/stow" <<'STUB'
#!/usr/bin/env bash
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
