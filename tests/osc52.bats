#!/usr/bin/env bats

# osc52-copy is the fallback every other backend degrades into, so its guards
# matter: an oversized payload can wedge a terminal, and the escape sequence
# has to be wrapped differently inside tmux and screen.

setup() {
  BIN_DIR="$(cd "$BATS_TEST_DIRNAME/../zsh/.local/bin" && pwd -P)"
  OSC52="$BIN_DIR/osc52-copy"
  TEST_TMP="$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/osc52.XXXXXX")" && pwd -P)"
  unset TMUX
  unset OSC52_MAX_BYTES
  export TERM=xterm-256color
}

teardown() {
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

@test "takes the payload from arguments when given any" {
  run "$OSC52" hello-osc52
  [ "$status" -eq 0 ]
  # Base64 of "hello-osc52".
  [[ "$output" == *$'\e]52;c;aGVsbG8tb3NjNTI='* ]]
}

@test "joins multiple arguments with a space" {
  run "$OSC52" two words
  [ "$status" -eq 0 ]
  # Base64 of "two words".
  [[ "$output" == *$'\e]52;c;dHdvIHdvcmRz'* ]]
}

@test "copies nothing and succeeds on empty input" {
  run bash -c "printf '' | '$OSC52'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "refuses a payload past the size limit" {
  run env OSC52_MAX_BYTES=8 "$OSC52" "this is definitely longer than eight bytes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing to copy"* ]]
  [[ "$output" == *"limit: 8"* ]]
  [[ "$output" != *$'\e]52'* ]]
}

@test "accepts a payload exactly at the limit" {
  # The guard is >, not >=, so the boundary itself must still copy.
  run env OSC52_MAX_BYTES=5 "$OSC52" 12345
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]52;c;'* ]]
}

@test "emits the bare sequence inside tmux" {
  run env TMUX=/tmp/tmux-1000/default,1,0 "$OSC52" in-tmux
  [ "$status" -eq 0 ]
  [[ "$output" == $'\e]52;c;'*$'\a' ]]
  # No screen DCS wrapper.
  [[ "$output" != $'\eP'* ]]
}

@test "wraps the sequence in a DCS passthrough under screen" {
  run env TERM=screen.xterm-256color "$OSC52" in-screen
  [ "$status" -eq 0 ]
  [[ "$output" == $'\eP\e'* ]]
  [[ "$output" == *$'\e\\' ]]
}

@test "tmux wins over a screen TERM" {
  run env TMUX=/tmp/tmux-1000/default,1,0 TERM=screen "$OSC52" both
  [ "$status" -eq 0 ]
  [[ "$output" != $'\eP'* ]]
}

@test "reports when base64 is unavailable" {
  # command -v decides, so a PATH without base64 exercises the guard.
  iso="$TEST_TMP/bin"
  mkdir -p "$iso"
  for cmd in bash cat tr; do
    ln -s "$(command -v "$cmd")" "$iso/$cmd"
  done

  # -u rather than -i: clearing the environment would also strip what kcov
  # needs to trace this run.
  run env -u TMUX PATH="$iso" "$OSC52" no-base64
  [ "$status" -eq 1 ]
  [[ "$output" == *"base64 is required"* ]]
}
