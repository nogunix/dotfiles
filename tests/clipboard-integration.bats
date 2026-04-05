#!/usr/bin/env bats

setup() {
  export BIN_DIR="$(cd "$BATS_TEST_DIRNAME/../zsh/.local/bin" && pwd)"
  # Add BIN_DIR to PATH so we can call the wrappers
  export PATH="$BIN_DIR:$PATH"

  # Find the REAL xclip (not our wrapper)
  REAL_XCLIP=""
  IFS=':' read -r -a path_entries <<< "$PATH"
  for path_entry in "${path_entries[@]}"; do
    if [[ "$path_entry" == "$BIN_DIR" ]]; then continue; fi
    if [[ -x "$path_entry/xclip" ]]; then
      REAL_XCLIP="$path_entry/xclip"
      break
    fi
  done
  export REAL_XCLIP
}

@test "copies text to xclip if DISPLAY is set" {
  if [[ -z "$DISPLAY" ]]; then
    skip "DISPLAY is not set"
  fi
  if [[ -z "$REAL_XCLIP" ]]; then
    skip "xclip is not installed"
  fi

  # Ensure no interference from SSH/TMUX
  unset SSH_TTY
  unset TMUX
  unset SSH_CONNECTION
  unset WAYLAND_DISPLAY

  echo "hello-xclip" | clipboard-copy
  
  run "$REAL_XCLIP" -selection clipboard -o
  [ "$status" -eq 0 ]
  [[ "$output" == "hello-xclip" ]]
}

@test "xclip wrapper works for input" {
  if [[ -z "$DISPLAY" ]]; then
    skip "DISPLAY is not set"
  fi
  if [[ -z "$REAL_XCLIP" ]]; then
    skip "xclip is not installed"
  fi

  # Ensure no interference from SSH/TMUX
  unset SSH_TTY
  unset TMUX
  unset SSH_CONNECTION
  unset WAYLAND_DISPLAY

  echo "hello-wrapper" | xclip -selection clipboard
  
  run "$REAL_XCLIP" -selection clipboard -o
  [ "$status" -eq 0 ]
  [[ "$output" == "hello-wrapper" ]]
}

@test "osc52-copy outputs correct escape sequence" {
  # We don't need X11 for this
  unset DISPLAY
  unset WAYLAND_DISPLAY
  export SSH_TTY=/dev/pts/0

  run bash -c "echo 'hello-osc52' | clipboard-copy"
  [ "$status" -eq 0 ]
  # Base64 of 'hello-osc52' is 'aGVsbG8tb3NjNTI='
  [[ "$output" == *$'\e]52;c;aGVsbG8tb3NjNTI=\a'* ]]
}
