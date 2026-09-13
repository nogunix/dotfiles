#!/usr/bin/env bats

# Argument handling and backend routing in the xclip/xsel compatibility
# wrappers. clipboard-backend.bats only covers which backend gets *chosen*;
# this covers what each wrapper then does with it, which is where the
# copy-style compatibility promised in AGENTS.md actually lives.

setup() {
  BIN_DIR="$(cd "$BATS_TEST_DIRNAME/../zsh/.local/bin" && pwd -P)"
  TEST_TMP="$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/clipwrap.XXXXXX")" && pwd -P)"
  COPY_LOG="$TEST_TMP/copy.log"

  # An isolated bin dir so the backend choice is ours and not the host's: a
  # real xclip in /usr/bin would otherwise decide these tests for us. Only the
  # wrappers run with this PATH — the test body keeps the normal one.
  ISO="$TEST_TMP/bin"
  mkdir -p "$ISO"
  # bash too: the wrappers start with #!/usr/bin/env bash, which searches PATH.
  for cmd in bash cat base64 tr dirname; do
    ln -s "$(command -v "$cmd")" "$ISO/$cmd"
  done
}

teardown() {
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

# Run a wrapper seeing only the repo's bin dir and our stubs. Note `env -u`
# rather than `env -i`: a cleared environment would also drop the variables
# kcov uses to trace bash, so coverage runs would see none of this. stdin is
# closed too:
# a backend that reads it would otherwise block on the terminal whenever a test
# passes its payload as a file argument instead of on a pipe.
iso() {
  run env -u WAYLAND_DISPLAY -u DISPLAY -u SSH_TTY -u SSH_CONNECTION -u TMUX \
    PATH="$BIN_DIR:$ISO" COPY_LOG="$COPY_LOG" \
    ${WAYLAND_DISPLAY:+WAYLAND_DISPLAY="$WAYLAND_DISPLAY"} \
    ${DISPLAY:+DISPLAY="$DISPLAY"} \
    ${SSH_TTY:+SSH_TTY="$SSH_TTY"} \
    ${TMUX:+TMUX="$TMUX"} \
    "$@" </dev/null
}

# Same, but for a pipeline: the command string is evaluated by bash with the
# restricted PATH in force.
iso_sh() {
  iso /bin/bash -c "$1"
}

# A backend that records how it was invoked and what it was fed.
stub_backend() {
  cat >"$ISO/$1" <<'STUB'
#!/bin/bash
printf 'argv: %s\n' "$*" >>"$COPY_LOG"
printf 'stdin: ' >>"$COPY_LOG"
cat >>"$COPY_LOG"
printf '\n' >>"$COPY_LOG"
STUB
  chmod +x "$ISO/$1"
}

log() { cat "$COPY_LOG" 2>/dev/null; }

# --- refusing to read the clipboard ------------------------------------------

@test "xclip -o refuses instead of pretending readback works" {
  stub_backend xclip
  DISPLAY=:0 iso xclip -o -selection clipboard

  [ "$status" -eq 1 ]
  [[ "$output" == *"reading the local terminal clipboard over SSH is not supported"* ]]
  [ ! -e "$COPY_LOG" ]
}

@test "xsel -o refuses instead of pretending readback works" {
  stub_backend xsel
  DISPLAY=:0 iso xsel --output --clipboard

  [ "$status" -eq 1 ]
  [[ "$output" == *"reading the local terminal clipboard over SSH is not supported"* ]]
}

# --- selection parsing -------------------------------------------------------

@test "xclip rejects a selection it cannot honour" {
  stub_backend xclip
  DISPLAY=:0 iso_sh "printf 'x' | xclip -selection secondary"

  [ "$status" -eq 1 ]
  [[ "$output" == *'unsupported selection "secondary"'* ]]
}

@test "xclip accepts every spelling of the selection flag" {
  # Real xclip takes -sel as an abbreviation of -selection, with the value
  # either as the next argument or after an =.
  for spelling in "-sel primary" "-selection primary" \
                  "-sel=primary" "-selection=primary"; do
    : >"$COPY_LOG"
    stub_backend xclip
    DISPLAY=:0 iso_sh "printf 'to-primary' | xclip $spelling"

    [ "$status" -eq 0 ] || {
      echo "failed for '$spelling': $output"
      false
    }
    [[ "$(log)" == *"argv: -selection primary"* ]] || {
      echo "wrong argv for '$spelling': $(log)"
      false
    }
    [[ "$(log)" == *"stdin: to-primary"* ]]
  done
}

@test "xclip skips over an option that takes an argument" {
  stub_backend xclip
  DISPLAY=:0 iso_sh "printf 'targeted' | xclip -t UTF8_STRING -selection clipboard"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: -selection clipboard"* ]]
  [[ "$(log)" == *"stdin: targeted"* ]]
}

# --- file arguments ----------------------------------------------------------

@test "xclip passes a file argument to the backend" {
  stub_backend xclip
  printf 'from-file' >"$TEST_TMP/a.txt"
  DISPLAY=:0 iso xclip "$TEST_TMP/a.txt"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"a.txt"* ]]
}

@test "xclip treats everything after -- as a file" {
  stub_backend xclip
  printf 'one' >"$TEST_TMP/one.txt"
  printf 'two' >"$TEST_TMP/two.txt"
  DISPLAY=:0 iso xclip -- "$TEST_TMP/one.txt" "$TEST_TMP/two.txt"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"one.txt"* ]]
  [[ "$(log)" == *"two.txt"* ]]
}

@test "xclip -f echoes the file back after copying" {
  # xsel is a non-exec branch, so the filter tail is actually reached.
  stub_backend xsel
  printf 'filtered' >"$TEST_TMP/f.txt"
  DISPLAY=:0 iso xclip -f "$TEST_TMP/f.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *"filtered"* ]]
}

# --- backend routing ---------------------------------------------------------

@test "xclip falls back to xsel when only xsel is installed" {
  stub_backend xsel
  DISPLAY=:0 iso_sh "printf 'via-xsel' | xclip -selection clipboard"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: --clipboard --input"* ]]
  [[ "$(log)" == *"stdin: via-xsel"* ]]
}

@test "xclip routes to OSC 52 when there is no display server" {
  SSH_TTY=/dev/pts/0 iso_sh "printf 'hello-osc52' | xclip -selection clipboard"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]52;c;aGVsbG8tb3NjNTI='* ]]
}

@test "xsel routes to xclip when only xclip is installed" {
  stub_backend xclip
  DISPLAY=:0 iso_sh "printf 'via-xclip' | xsel --clipboard --input"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: -selection clipboard"* ]]
  [[ "$(log)" == *"stdin: via-xclip"* ]]
}

@test "xsel copies a file argument through the OSC 52 fallback" {
  printf 'xsel-file' >"$TEST_TMP/x.txt"
  SSH_TTY=/dev/pts/0 iso xsel "$TEST_TMP/x.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]52;c;'* ]]
}

@test "clipboard-copy hands off to wl-copy under Wayland" {
  stub_backend wl-copy
  WAYLAND_DISPLAY=wayland-0 iso_sh "printf 'wayland-payload' | clipboard-copy"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"stdin: wayland-payload"* ]]
}

@test "clipboard-copy hands off to xsel when that is the backend" {
  stub_backend xsel
  DISPLAY=:0 iso_sh "printf 'xsel-payload' | clipboard-copy"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: --clipboard --input"* ]]
  [[ "$(log)" == *"stdin: xsel-payload"* ]]
}

@test "clip delegates to clipboard-copy" {
  stub_backend xclip
  DISPLAY=:0 iso_sh "printf 'via-clip' | clip"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: -selection clipboard"* ]]
  [[ "$(log)" == *"stdin: via-clip"* ]]
}

@test "xsel treats everything after -- as a file" {
  stub_backend xsel
  printf 'sep-one' >"$TEST_TMP/s1.txt"
  printf 'sep-two' >"$TEST_TMP/s2.txt"
  DISPLAY=:0 iso xsel -- "$TEST_TMP/s1.txt" "$TEST_TMP/s2.txt"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"s1.txt"* ]]
  [[ "$(log)" == *"s2.txt"* ]]
}

@test "xsel passes files straight to a real xsel backend" {
  stub_backend xsel
  printf 'native' >"$TEST_TMP/n.txt"
  DISPLAY=:0 iso xsel "$TEST_TMP/n.txt"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: --clipboard --input"*"n.txt"* ]]
}

@test "xsel on a pipe execs a real xsel backend directly" {
  stub_backend xsel
  DISPLAY=:0 iso_sh "printf 'piped-native' | xsel --clipboard --input"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: --clipboard --input"* ]]
  [[ "$(log)" == *"stdin: piped-native"* ]]
}

@test "xsel streams a file into an xclip backend" {
  stub_backend xclip
  printf 'streamed' >"$TEST_TMP/s.txt"
  DISPLAY=:0 iso xsel "$TEST_TMP/s.txt"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"argv: -selection clipboard"* ]]
  [[ "$(log)" == *"stdin: streamed"* ]]
}

@test "xsel with no file falls through to OSC 52" {
  SSH_TTY=/dev/pts/0 iso_sh "printf 'xsel-stdin' | xsel --clipboard --input"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]52;c;'* ]]
}

@test "xclip -i is accepted as the explicit input mode" {
  stub_backend xclip
  DISPLAY=:0 iso_sh "printf 'explicit-in' | xclip -i -selection clipboard"

  [ "$status" -eq 0 ]
  [[ "$(log)" == *"stdin: explicit-in"* ]]
}

@test "xclip streams a file into the OSC 52 fallback" {
  printf 'file-to-osc52' >"$TEST_TMP/o.txt"
  SSH_TTY=/dev/pts/0 iso xclip "$TEST_TMP/o.txt"

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\e]52;c;'* ]]
}

# --- defensive branches ------------------------------------------------------

@test "each wrapper reports a backend it does not understand" {
  # A copy of the bin dir whose clipboard-backend names something none of the
  # wrappers know, so the "unsupported backend" arms are reachable at all.
  local dir="$TEST_TMP/bogus"
  mkdir -p "$dir"
  cp "$BIN_DIR"/* "$dir/"
  cat >"$dir/clipboard-backend" <<'STUB'
#!/bin/bash
printf 'telepathy:/nonexistent\n'
STUB
  chmod +x "$dir/clipboard-backend"

  run env -u DISPLAY -u WAYLAND_DISPLAY -u SSH_TTY -u SSH_CONNECTION -u TMUX \
    PATH="$ISO" /bin/bash -c "printf 'x' | '$dir/clipboard-copy'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"clipboard-copy: unsupported backend telepathy"* ]]

  run env -u DISPLAY -u WAYLAND_DISPLAY -u SSH_TTY -u SSH_CONNECTION -u TMUX \
    PATH="$ISO" /bin/bash -c "printf 'x' | '$dir/xclip' -selection clipboard"
  [ "$status" -eq 1 ]
  [[ "$output" == *"xclip wrapper: unsupported backend telepathy"* ]]

  run env -u DISPLAY -u WAYLAND_DISPLAY -u SSH_TTY -u SSH_CONNECTION -u TMUX \
    PATH="$ISO" /bin/bash -c "printf 'x' | '$dir/xsel' --clipboard --input"
  [ "$status" -eq 1 ]
  [[ "$output" == *"xsel wrapper: unsupported backend telepathy"* ]]
}

@test "clipboard-backend falls back to OSC 52 when no native tool exists" {
  # A display is advertised but nothing on PATH can talk to it.
  DISPLAY=:0 iso clipboard-backend

  [ "$status" -eq 0 ]
  [ "$output" = "osc52:$BIN_DIR/osc52-copy" ]
}
