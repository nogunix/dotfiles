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
