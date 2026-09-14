#!/usr/bin/env bats

# tmux.conf and its two helper scripts. The status bar is rendered by tmux
# itself, so almost everything here is a format string that costs no processes
# at all; git-branch.sh is the single exception and runs once per
# status-interval. Two things are therefore worth guarding:
#
#   - the perf invariant: exactly one `#()` in the whole config, and no plugin
#     manager to parse at load time;
#   - portability: os-label.sh branches on `uname -s` and has to survive
#     macOS's bash 3.2, where printf '\uHHHH' does not exist.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TMUX_DIR="$REPO_ROOT/tmux/.config/tmux"
  TMUX_CONF="$TMUX_DIR/tmux.conf"
  TEST_TMP="$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/tmux-conf.XXXXXX")" && pwd -P)"
  SOCKET="dotfiles-test-$$"
}

teardown() {
  tmux -L "$SOCKET" kill-server 2>/dev/null || true
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

# A HOME that looks like the stowed layout, so the paths tmux.conf uses to
# reach its own helper scripts are exercised rather than assumed.
stowed_home() {
  local home="$TEST_TMP/home"
  mkdir -p "$home/.config"
  ln -sfn "$TMUX_DIR" "$home/.config/tmux"
  printf '%s\n' "$home"
}

@test "tmux parses tmux.conf without errors" {
  command -v tmux >/dev/null || skip "tmux not installed"

  run env HOME="$(stowed_home)" \
    tmux -L "$SOCKET" -f "$TMUX_CONF" new-session -d -x 80 -y 24
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  # A config error surfaces as an extra window holding the message.
  run tmux -L "$SOCKET" list-windows -a
  [ "$(printf '%s\n' "$output" | grep -c .)" -eq 1 ]

  tmux -L "$SOCKET" kill-server
}

@test "the status bar forks for the git chip and nothing else" {
  # Every other segment is a plain tmux format. Each extra `#()` would be a
  # fresh process per client per status-interval, which is exactly what
  # dropping tmux-powerline bought back.
  run grep -c '#(' "$TMUX_CONF"
  [ "$output" -eq 1 ]

  run grep -n '#(' "$TMUX_CONF"
  [[ "$output" == *"git-branch.sh"* ]]
  [[ "$output" == *"status-right"* ]]
}

@test "tmux.conf pulls in no plugin manager" {
  # "powerline" on its own is still a legitimate word here — it names the
  # separator glyphs — so match the plugin machinery rather than the term.
  run grep -nE '@plugin|plugins/tpm|TMUX_PLUGIN_MANAGER_PATH|powerline\.sh' "$TMUX_CONF"
  [ "$status" -ne 0 ]
}

@test "tmux.conf defines every user option the helper emits" {
  local opt
  for opt in @git_pre @git_post @git_none; do
    grep -q "set -g $opt " "$TMUX_CONF" || {
      printf 'tmux.conf does not define %s\n' "$opt" >&2
      return 1
    }
    grep -q "$opt" "$TMUX_DIR/git-branch.sh" || {
      printf 'git-branch.sh never emits %s\n' "$opt" >&2
      return 1
    }
  done
}

# --- os-label.sh -------------------------------------------------------------

@test "os-label renders a label for this platform" {
  run "$TMUX_DIR/os-label.sh"
  [ "$status" -eq 0 ]
  [ -n "$output" ]

  case "$(uname -s)" in
    Darwin) [[ "$output" == *"macOS"* ]] ;;
    # Linux/BSD show the kernel version with any distro suffix stripped.
    *)      [[ "$output" == *"$(uname -r | cut -d- -f1)"* ]]
            [[ "$output" != *"-"* ]] ;;
  esac
}

@test "os-label works under bash 3.2 printf semantics" {
  # printf '\uHHHH' was added in bash 4.2, so the script must emit its glyph
  # as raw \xHH bytes. Reject the escape that silently breaks on macOS.
  run grep -n '\\u[0-9a-fA-F]\{4\}' "$TMUX_DIR/os-label.sh"
  [ "$status" -ne 0 ]

  # The rendered glyph must be real UTF-8, not a literal backslash escape.
  run "$TMUX_DIR/os-label.sh"
  [[ "$output" != *'\x'* ]]
  [[ "$output" != *'\u'* ]]
}

# The script branches on `uname -s`, so the two branches this host is not
# running can still be checked by putting a fake uname in front of PATH. That
# is the only way CI on Linux ever sees the macOS rendering, and vice versa.
render_label_as() {
  local os="$1" release="$2" product="${3:-}"
  local fake="$TEST_TMP/fake-$os"
  mkdir -p "$fake"

  cat >"$fake/uname" <<STUB
#!/bin/bash
case "\$1" in
  -s) printf '%s\n' '$os' ;;
  -r) printf '%s\n' '$release' ;;
  *)  printf '%s\n' '$os' ;;
esac
STUB
  chmod +x "$fake/uname"

  # Always stub sw_vers, even to simulate it failing: on a real Mac the system
  # one is still further down PATH and would answer for it.
  if [ -n "$product" ]; then
    cat >"$fake/sw_vers" <<STUB
#!/bin/bash
printf '%s\n' '$product'
STUB
  else
    cat >"$fake/sw_vers" <<'STUB'
#!/bin/bash
exit 1
STUB
  fi
  chmod +x "$fake/sw_vers"

  run env PATH="$fake:$PATH" "$TMUX_DIR/os-label.sh"
}

@test "os-label renders the macOS product version" {
  render_label_as Darwin 23.5.0 14.5

  [ "$status" -eq 0 ]
  [[ "$output" == *"macOS 14.5"* ]]
  # The Apple glyph, as raw UTF-8 rather than a printf escape.
  [[ "$output" == *$''* ]]
}

@test "os-label still says macOS when sw_vers gives nothing" {
  render_label_as Darwin 23.5.0 ""   # "" makes the sw_vers stub fail

  [ "$status" -eq 0 ]
  [[ "$output" == *"macOS"* ]]
  [[ "$output" != *"macOS "* ]]
}

@test "os-label strips the distro suffix from a Linux kernel release" {
  render_label_as Linux 6.11.3-200.fc40.x86_64

  [ "$status" -eq 0 ]
  [[ "$output" == *"6.11.3"* ]]
  [[ "$output" != *"fc40"* ]]
  [[ "$output" == *$''* ]]
}

@test "os-label falls back to a terminal glyph on other systems" {
  render_label_as FreeBSD 14.0-RELEASE

  [ "$status" -eq 0 ]
  [[ "$output" == *"14.0"* ]]
  [[ "$output" != *"RELEASE"* ]]
  [[ "$output" == *$''* ]]
}

@test "tmux.conf resolves the OS label once, at config load" {
  command -v tmux >/dev/null || skip "tmux not installed"

  env HOME="$(stowed_home)" \
    tmux -L "$SOCKET" -f "$TMUX_CONF" new-session -d -x 80 -y 24

  # The label is cached in a user option, not recomputed on every redraw.
  run tmux -L "$SOCKET" show -gv @os_label
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  [[ "$output" == *"$("$TMUX_DIR/os-label.sh")"* ]]

  run tmux -L "$SOCKET" display -p '#{E:status-left}'
  [[ "$output" == *"$("$TMUX_DIR/os-label.sh")"* ]]

  tmux -L "$SOCKET" kill-server
}

# --- git-branch.sh -----------------------------------------------------------

# A throwaway repo, so the test never depends on the branch this repo is on.
make_repo() {
  local dir="$TEST_TMP/repo"
  mkdir -p "$dir"
  git -c init.defaultBranch="${1:-work}" init -q "$dir"
  git -C "$dir" -c user.name=t -c user.email=t@e commit -q --allow-empty -m init
  printf '%s\n' "$dir"
}

@test "git-branch prints the chip for a repo" {
  command -v git >/dev/null || skip "git not installed"

  run "$TMUX_DIR/git-branch.sh" "$(make_repo work)"
  [ "$status" -eq 0 ]
  [ "$output" = '#{@git_pre}work#{@git_post}' ]
}

@test "git-branch prints only the separator outside a repo" {
  run "$TMUX_DIR/git-branch.sh" "$TEST_TMP"
  [ "$status" -eq 0 ]
  [ "$output" = '#{@git_none}' ]

  # No argument at all (an unexpanded format, say) must not error either.
  run "$TMUX_DIR/git-branch.sh"
  [ "$status" -eq 0 ]
  [ "$output" = '#{@git_none}' ]
}

@test "git-branch shows the short sha on a detached HEAD" {
  command -v git >/dev/null || skip "git not installed"
  local repo sha
  repo="$(make_repo work)"
  sha="$(git -C "$repo" rev-parse --short HEAD)"
  git -C "$repo" checkout -q --detach HEAD

  run "$TMUX_DIR/git-branch.sh" "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = "#{@git_pre}:${sha}#{@git_post}" ]
}

@test "git-branch truncates a long branch name" {
  command -v git >/dev/null || skip "git not installed"
  local repo
  repo="$(make_repo aaaaaaaaaabbbbbbbbbbccccccccccdddd)"   # 34 chars

  run "$TMUX_DIR/git-branch.sh" "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = '#{@git_pre}aaaaaaaaaabbbbbbbbbbccc…#{@git_post}' ]
}

@test "git-branch escapes a hash in the branch name" {
  command -v git >/dev/null || skip "git not installed"
  # tmux re-expands this output as a format, where '#' is the escape character,
  # so an unescaped one would eat the rest of the chip.
  local repo
  repo="$(make_repo 'fix/#42')"

  run "$TMUX_DIR/git-branch.sh" "$repo"
  [ "$status" -eq 0 ]
  [ "$output" = '#{@git_pre}fix/##42#{@git_post}' ]
}

# --- portability -------------------------------------------------------------

@test "tmux config and helpers point at paths that are not user-specific" {
  # A stowed config has to work on every machine, so $HOME or ~ rather than one
  # developer's home directory.
  run grep -rnE '/(home|Users)/[a-zA-Z0-9._-]+/' "$TMUX_DIR"
  [ "$status" -ne 0 ]
}
