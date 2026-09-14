#!/usr/bin/env bats

# Cheap, platform-independent guards that catch the two things most likely to
# break a stowed config on a second machine: a syntax error that only shows up
# when the real shell parses the file, and a path baked to one user's home.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
}

@test "zshrc parses with the zsh on this machine" {
  command -v zsh >/dev/null || skip "zsh not installed"

  run zsh -n "$REPO_ROOT/zsh/.zshrc"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "shell scripts parse with bash" {
  while IFS= read -r script; do
    run bash -n "$script"
    [ "$status" -eq 0 ] || {
      echo "bash -n failed for $script: $output"
      false
    }
  done < <(
    find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o \
      \( -name '*.sh' -o -path '*/.local/bin/*' \) -type f -print
  )
}

@test "scripts locate themselves when invoked without a path" {
  # `bash <script>` from the script's own directory leaves BASH_SOURCE without
  # a slash, which ${path%/*} does not shorten — so a naive `cd "${path%/*}"`
  # tries to cd into the script itself and the run dies before doing anything.
  run bash -c "cd '$REPO_ROOT' && bash bootstrap.sh --help"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" != *"Not a directory"* ]]

  # Force the OSC 52 backend. What is under test is self-location, but with a
  # DISPLAY and a real xclip — which is exactly the Linux CI jobs, running the
  # suite under xvfb-run — the wrappers reach the real xclip, which daemonises
  # to keep owning the selection and leaves this pipe open. `run` captures
  # through a command substitution and waits for EOF, so the whole job hangs
  # until it is killed. tests/clipboard-integration.bats sidesteps the same
  # trap by calling outside `run` and reaping xclip in its teardown.
  local bin="$REPO_ROOT/zsh/.local/bin"
  for script in clipboard-backend clipboard-copy xclip xsel; do
    run bash -c "cd '$bin' && printf 'x' |
      env -u DISPLAY -u WAYLAND_DISPLAY bash $script </dev/null 2>&1"
    [[ "$output" != *"Not a directory"* ]] || {
      echo "$script could not find its own directory: $output"
      false
    }
  done
}

@test "no stowed config bakes in a specific user's home directory" {
  # Stowed files land in a different $HOME on every machine, and /home/... is
  # not even the right prefix on macOS. Only the files that get linked into
  # $HOME are in scope; machine-local tooling state is not.
  run bash -c "
    cd '$REPO_ROOT' &&
    grep -rnE '/(home|Users)/[a-zA-Z0-9._-]+/' \
      bootstrap.sh zsh nvim tmux ctags || true
  "
  [ -z "$output" ]
}

@test "nvim lua config loads as valid lua" {
  command -v nvim >/dev/null || skip "nvim not installed"

  while IFS= read -r lua; do
    run nvim --headless -u NONE -c "lua assert(loadfile('$lua'))" -c "qa!"
    [ "$status" -eq 0 ] || {
      echo "lua parse failed for $lua: $output"
      false
    }
  done < <(find "$REPO_ROOT/nvim" -name '*.lua' -type f -print)
}
