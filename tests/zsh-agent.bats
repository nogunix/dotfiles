#!/usr/bin/env bats

# zsh/.zshrc gives shells driven by a coding agent a plain setup (no plugins,
# no pager, no editor) and zsh/.zshenv puts the PATH entries non-interactive
# agent shells need where they will see them. These run inside whatever agent
# is running the suite, so every test sets or clears the markers explicitly.

setup() {
  command -v zsh >/dev/null || skip "zsh not installed"
  ZSH_BIN="$(command -v zsh)"
  T="$(mktemp -d "${TMPDIR:-/tmp}/zsh-agent.XXXXXX")"
  # A copy, so nothing a shell writes next to its rc file lands in the repo.
  mkdir -p "$T/zdot" "$T/home"
  cp "$BATS_TEST_DIRNAME/../zsh/.zshrc" "$BATS_TEST_DIRNAME/../zsh/.zshenv" "$T/zdot/"
}

teardown() {
  rm -rf "$T"
}

# Run an interactive zsh on the copied rc files as an agent would.
agent_zsh() {
  env -u ANTIGRAVITY_AGENT -u CLAUDECODE -u PAGER -u GIT_PAGER -u GIT_EDITOR \
    HOME="$T/home" ZDOTDIR="$T/zdot" "$@" \
    "$ZSH_BIN" -i -c 'print -r -- "$PAGER|$GIT_PAGER|$GIT_EDITOR|${+functions[zinit]}"'
}

@test "an Antigravity agent shell gets no plugins and nothing that blocks" {
  run agent_zsh ANTIGRAVITY_AGENT=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"cat|cat|true|0" ]]
  # zinit was neither loaded nor installed (that would mean a git clone).
  [ ! -e "$T/home/.local/share/zinit" ]
}

@test "a Claude Code shell is treated the same way" {
  run agent_zsh CLAUDECODE=1
  [ "$status" -eq 0 ]
  [[ "$output" == *"cat|cat|true|0" ]]
}

@test "a shell without an agent marker keeps its pager and editor" {
  # The full .zshrc would install zinit here, so run only the detection block.
  awk '/^_zsh_agent_markers=\(/,/^fi$/' "$T/zdot/.zshrc" >"$T/detect.zsh"
  [ -s "$T/detect.zsh" ]
  run env -u ANTIGRAVITY_AGENT -u CLAUDECODE -u GIT_EDITOR PAGER=less "$ZSH_BIN" -f -c \
    "source '$T/detect.zsh'; print -r -- \"\$_zsh_agent|\$PAGER|\${GIT_EDITOR-unset}\""
  [ "$status" -eq 0 ]
  [ "$output" = "0|less|unset" ]
}

# --- .zshenv -----------------------------------------------------------------

env_path() {
  env -u ZDOTDIR HOME="$T/home" ZDOTDIR="$T/zdot" PATH="$1" "$ZSH_BIN" -c 'print -r -- $PATH'
}

@test ".zshenv puts ~/.local/bin on PATH for a non-interactive shell" {
  mkdir -p "$T/home/.local/bin"
  run env_path /usr/bin:/bin
  [ "$status" -eq 0 ]
  [[ "$output" == "$T/home/.local/bin:"* ]]
}

@test ".zshenv leaves an existing PATH order alone" {
  # Homebrew may still be prepended if this host has it and PATH lacked it;
  # what must not happen is ~/.local/bin being moved ahead of /usr/bin.
  mkdir -p "$T/home/.local/bin"
  run env_path "/usr/bin:$T/home/.local/bin:/bin"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/usr/bin:$T/home/.local/bin:/bin" ]]
  [ "$(printf '%s\n' "$output" | tr ':' '\n' | grep -c "^$T/home/.local/bin\$")" -eq 1 ]
}

@test ".zshenv skips directories that do not exist" {
  run env_path /usr/bin:/bin
  [ "$status" -eq 0 ]
  [[ "$output" != *"$T/home/.local/bin"* ]]
}

@test ".zshenv stops Debian's global compinit" {
  # /etc/zsh/zshrc on Debian/Ubuntu runs compinit unless this is set; that
  # doubles .zshrc's own and can stop at an "insecure directories" prompt.
  run env HOME="$T/home" ZDOTDIR="$T/zdot" "$ZSH_BIN" -c 'print -r -- "${skip_global_compinit-unset}"'
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}
