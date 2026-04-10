#!/usr/bin/env bats

setup() {
  export BIN_DIR="$BATS_TEST_DIRNAME/../zsh/.local/bin"
  export PATH="$BIN_DIR:$PATH"
  
  # Stub find_real_command's dependencies
  export STUB_BIN_DIR="$(mktemp -d)"
  export PATH="$STUB_BIN_DIR:$PATH"
  
  touch "$STUB_BIN_DIR/wl-copy"
  chmod +x "$STUB_BIN_DIR/wl-copy"
  
  touch "$STUB_BIN_DIR/xclip"
  chmod +x "$STUB_BIN_DIR/xclip"
  
  touch "$STUB_BIN_DIR/pbcopy"
  chmod +x "$STUB_BIN_DIR/pbcopy"
}

teardown() {
  rm -rf "$STUB_BIN_DIR"
}

@test "prioritizes wl-copy over SSH/TMUX if WAYLAND_DISPLAY is set" {
  export WAYLAND_DISPLAY=wayland-0
  export SSH_TTY=/dev/pts/0
  
  run "$BIN_DIR/clipboard-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == "wl-copy:"* ]]
}

@test "falls back to osc52 if WAYLAND_DISPLAY is not set and DISPLAY is not set but SSH_TTY is set" {
  unset WAYLAND_DISPLAY
  unset DISPLAY
  export SSH_TTY=/dev/pts/0
  
  run "$BIN_DIR/clipboard-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == "osc52:"* ]]
}

@test "uses wl-copy in local session (no SSH/TMUX)" {
  export WAYLAND_DISPLAY=wayland-0
  unset SSH_TTY
  unset TMUX
  unset SSH_CONNECTION
  
  run "$BIN_DIR/clipboard-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == "wl-copy:"* ]]
}

@test "prioritizes X11 over SSH/TMUX session" {
  unset WAYLAND_DISPLAY
  export DISPLAY=:0
  export SSH_TTY=/dev/pts/0
  
  run "$BIN_DIR/clipboard-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == "xclip:"* ]]
}

@test "uses pbcopy on macOS" {
  export OSTYPE=darwin21
  unset WAYLAND_DISPLAY
  unset DISPLAY
  unset SSH_TTY
  unset TMUX
  unset SSH_CONNECTION
  
  run "$BIN_DIR/clipboard-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == "pbcopy:"* ]]
}
