#!/usr/bin/env bats

# tmux.conf and the hand-written tmux-powerline segments are the most
# OS-sensitive part of the repo: the segments branch on `uname -s` and have to
# survive macOS's bash 3.2, where printf '\uHHHH' does not exist.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TMUX_CONF="$REPO_ROOT/tmux/.config/tmux/tmux.conf"
  SEGMENTS="$REPO_ROOT/tmux/.config/tmux-powerline/segments"
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/tmux-conf.XXXXXX")"
  SOCKET="dotfiles-test-$$"
}

teardown() {
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

# Source a segment the way tmux-powerline does and print what it renders.
run_segment_file() {
  run bash -c "source '$SEGMENTS/$1' && run_segment"
}

@test "tmux parses tmux.conf without errors" {
  command -v tmux >/dev/null || skip "tmux not installed"

  # TPM is not installed here; its `run` line is expected to be the only
  # complaint, so drop it and check that nothing else is rejected.
  grep -v "plugins/tpm/tpm" "$TMUX_CONF" >"$TEST_TMP/tmux.conf"

  run tmux -L "$SOCKET" -f "$TEST_TMP/tmux.conf" new-session -d -x 80 -y 24
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  tmux -L "$SOCKET" kill-server
}

@test "os_icon segment renders a label for this platform" {
  run_segment_file os_icon.sh
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  case "$(uname -s)" in
    Darwin) [[ "$output" == *"macOS"* ]] ;;
    # Linux/BSD show the kernel version with any distro suffix stripped.
    *)      [[ "$output" == *"$(uname -r | cut -d- -f1)"* ]]
            [[ "$output" != *"-"* ]] ;;
  esac
}

@test "os_icon segment works under bash 3.2 printf semantics" {
  # printf '\uHHHH' was added in bash 4.2, so the segment must emit its glyph
  # as raw \xHH bytes. Reject the escape that silently breaks on macOS.
  run grep -n '\\u[0-9a-fA-F]\{4\}' "$SEGMENTS/os_icon.sh"
  [ "$status" -ne 0 ]

  # The rendered glyph must be real UTF-8, not a literal backslash escape.
  run_segment_file os_icon.sh
  [[ "$output" != *'\x'* ]]
  [[ "$output" != *'\u'* ]]
}

@test "session_label and pane_path emit tmux format placeholders" {
  run_segment_file session_label.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"#S"* ]]

  run_segment_file pane_path.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"#{pane_current_path}"* ]]
}

@test "tmux copy-command points at a path that is not user-specific" {
  # A stowed config has to work on every machine, so the clip wrapper must be
  # addressed through $HOME rather than one developer's home directory.
  run grep -nE '/(home|Users)/[a-zA-Z0-9._-]+/' "$TMUX_CONF"
  [ "$status" -ne 0 ]
}
