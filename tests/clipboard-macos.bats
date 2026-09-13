#!/usr/bin/env bats

# macOS-only: exercise the pbcopy branch of the clipboard wrappers against the
# real pbcopy/pbpaste. clipboard-backend.bats only fakes OSTYPE, so the actual
# local-macOS path has never been run end to end.

setup() {
  [ "$(uname -s)" = "Darwin" ] || skip "not macOS"
  command -v pbcopy >/dev/null && command -v pbpaste >/dev/null \
    || skip "pbcopy/pbpaste not available"

  # A headless or sandboxed host can have pbcopy present but no pasteboard
  # server; distinguish that from a real wrapper regression.
  printf 'pasteboard-probe' | pbcopy 2>/dev/null || skip "pasteboard unavailable"
  [ "$(pbpaste 2>/dev/null)" = "pasteboard-probe" ] || skip "pasteboard unavailable"

  BIN_DIR="$(cd "$BATS_TEST_DIRNAME/../zsh/.local/bin" && pwd -P)"
  export PATH="$BIN_DIR:$PATH"
}

# A local desktop session: no remote-session hints, no X11/Wayland.
local_session() {
  unset SSH_TTY SSH_CONNECTION TMUX DISPLAY WAYLAND_DISPLAY
}

@test "clipboard-backend selects the real pbcopy in a local macOS session" {
  local_session

  run "$BIN_DIR/clipboard-backend"
  [ "$status" -eq 0 ]
  [[ "$output" == "pbcopy:"* ]]

  # It must resolve to the system binary, never back to our own wrapper dir.
  resolved="${output#pbcopy:}"
  [ -x "$resolved" ]
  [[ "$resolved" != "$BIN_DIR/"* ]]
}

@test "clip round-trips through the macOS pasteboard" {
  local_session

  printf 'hello-pbcopy' | clip
  run pbpaste
  [ "$status" -eq 0 ]
  [ "$output" = "hello-pbcopy" ]
}

@test "clipboard-copy round-trips multi-line input" {
  local_session

  printf 'line one\nline two\n' | clipboard-copy
  run pbpaste
  [ "$status" -eq 0 ]
  [ "$output" = "line one
line two" ]
}

@test "a remote session still prefers OSC 52 over pbcopy" {
  # Invariant from AGENTS.md: SSH/tmux beats local pbcopy, so a copy made over
  # SSH lands in the user's own terminal rather than the remote pasteboard.
  local_session
  export SSH_TTY=/dev/ttys000

  printf 'sentinel-not-copied' | pbcopy
  run bash -c "printf 'hello-osc52' | clipboard-copy"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]52;c;aGVsbG8tb3NjNTI='* ]]

  # The pasteboard must be untouched.
  run pbpaste
  [ "$output" = "sentinel-not-copied" ]
}
