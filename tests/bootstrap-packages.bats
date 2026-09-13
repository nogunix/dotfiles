#!/usr/bin/env bats

# Package-manager dispatch in bootstrap.sh. This is the part of the repo that
# only ever runs on a fresh machine, which is exactly when a mistake is most
# expensive and least likely to be noticed — and until now only the Homebrew
# path had any coverage at all.
#
# Every package manager is a stub that records its argv, so nothing is
# installed and no network is touched.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  TEST_TMP="$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/bootstrap-pm.XXXXXX")" && pwd -P)"
  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"

  BIN="$TEST_TMP/bin"
  mkdir -p "$BIN"
  export PM_LOG="$TEST_TMP/pm.log"
  export STOW_LOG="$TEST_TMP/stow.log"

  # Only the handful of real tools bootstrap.sh shells out to. Notably absent:
  # every package manager, so each test decides which ones exist.
  # bash too: install_zinit pipes the fetched installer into it.
  for cmd in find date mv readlink head cat bash; do
    ln -s "$(command -v "$cmd")" "$BIN/$cmd"
  done

  stub stow
  # sudo has to stay transparent so the package-manager stub sees the real argv.
  cat >"$BIN/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB
  chmod +x "$BIN/sudo"
}

teardown() {
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

# stub <name> [exit-status] — record the argv, then exit with the given status.
stub() {
  local name="$1" rc="${2:-0}"
  cat >"$BIN/$name" <<STUB
#!/bin/bash
printf '$name %s\n' "\$*" >>"\$PM_LOG"
exit $rc
STUB
  chmod +x "$BIN/$name"
}

# A stub that fails only when its argv contains a given word.
stub_failing_on() {
  local name="$1" needle="$2"
  cat >"$BIN/$name" <<STUB
#!/bin/bash
printf '$name %s\n' "\$*" >>"\$PM_LOG"
case " \$* " in
  *" $needle "*) exit 1 ;;
esac
exit 0
STUB
  chmod +x "$BIN/$name"
}

bootstrap() {
  # -u rather than -i: an emptied environment would also drop the variables
  # kcov uses to trace bash, so a coverage run would miss every line below.
  # The XDG ones are cleared because install_tpm derives its path from them.
  run env -u XDG_DATA_HOME -u XDG_CONFIG_HOME -u XDG_CACHE_HOME \
    HOME="$HOME" PATH="$BIN" PM_LOG="$PM_LOG" STOW_LOG="$STOW_LOG" \
    /bin/bash "$REPO_ROOT/bootstrap.sh" "$@" </dev/null
}

pm_log() { cat "$PM_LOG" 2>/dev/null; }

# --- base tool install -------------------------------------------------------

@test "installs the base tools with dnf" {
  stub dnf

  bootstrap -p "nvim"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"dnf install -y git curl neovim tmux zsh"* ]]
}

@test "installs the base tools with apt-get, refreshing the index first" {
  stub apt-get

  bootstrap -p "nvim"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"apt-get update -y"* ]]
  [[ "$(pm_log)" == *"apt-get install -y git curl neovim tmux zsh"* ]]
}

@test "installs the base tools with pacman" {
  stub pacman

  bootstrap -p "nvim"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"pacman -Sy --noconfirm git curl neovim tmux zsh"* ]]
}

@test "prefers dnf over the other package managers" {
  stub dnf
  stub apt-get
  stub pacman
  stub brew

  bootstrap -p "nvim"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == "dnf install -y"* ]]
  [[ "$(pm_log)" != *"apt-get"* ]]
  [[ "$(pm_log)" != *"pacman"* ]]
  [[ "$(pm_log)" != *"brew"* ]]
}

@test "asks for nothing when every base tool is already present" {
  stub dnf
  # `have` only consults PATH, so these never actually run.
  for cmd in git curl neovim tmux zsh; do
    stub "$cmd"
  done

  bootstrap -p "nvim"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All required base tools already installed"* ]]
  [[ "$(pm_log)" != *"dnf"* ]]
}

# --- ctags -------------------------------------------------------------------

@test "installs universal-ctags with dnf for the ctags package" {
  stub dnf

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"dnf install -y universal-ctags"* ]]
}

@test "falls back to exuberant-ctags when apt-get has no universal-ctags" {
  stub_failing_on apt-get universal-ctags

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"apt-get install -y universal-ctags"* ]]
  [[ "$(pm_log)" == *"apt-get install -y exuberant-ctags"* ]]
}

@test "falls back to plain ctags when pacman has no universal-ctags" {
  stub_failing_on pacman universal-ctags

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"pacman -Sy --noconfirm universal-ctags"* ]]
  [[ "$(pm_log)" == *"pacman -Sy --noconfirm ctags"* ]]
}

@test "leaves an existing ctags alone" {
  stub dnf
  stub ctags

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ctags CLI already available"* ]]
  [[ "$(pm_log)" != *"universal-ctags"* ]]
}

@test "reports when ctags cannot be installed at all" {
  stub_failing_on dnf universal-ctags

  bootstrap -p "ctags"
  # The failure is tolerated by design (|| true in the caller), but it has to
  # be visible rather than silent.
  [ "$status" -eq 0 ]
  [[ "$output" == *"Failed to install ctags automatically"* ]]
}

@test "stops with a clear message when no package manager exists" {
  # $BIN deliberately holds no dnf/apt-get/pacman/brew.
  bootstrap -p "nvim"
  [ "$status" -ne 0 ]
  [[ "$output" == *"No supported package manager found"* ]]
  [[ "$output" == *"git curl neovim tmux zsh"* ]]
}

@test "installs universal-ctags with Homebrew" {
  stub brew

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"brew install universal-ctags"* ]]
}

# --- zinit -------------------------------------------------------------------

@test "bootstraps zinit for the zsh package" {
  stub dnf
  # The installer is fetched and piped into bash; a stub curl keeps that
  # offline while still exercising the real code path.
  cat >"$BIN/curl" <<'STUB'
#!/bin/bash
printf 'curl %s\n' "$*" >>"$PM_LOG"
printf ':\n'
STUB
  chmod +x "$BIN/curl"

  bootstrap -p "zsh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing Zinit"* ]]
  [[ "$(pm_log)" == *"zdharma-continuum/zinit"* ]]
}

@test "skips zinit under --no-install" {
  # --no-install has to mean no network at all. install_zinit used to run
  # regardless, so `--no-install` still curled the installer from GitHub.
  cat >"$BIN/curl" <<'STUB'
#!/bin/bash
printf 'curl %s\n' "$*" >>"$PM_LOG"
printf ':\n'
STUB
  chmod +x "$BIN/curl"

  bootstrap -p "zsh" --no-install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping Zinit install (--no-install)"* ]]
  [[ "$output" != *"Installing Zinit"* ]]
  [ ! -e "$PM_LOG" ] || [[ "$(pm_log)" != *"curl"* ]]
  [ ! -d "$HOME/.local/share/zinit/zinit.git" ]
}

@test "leaves an existing zinit checkout in place" {
  stub dnf
  stub curl
  mkdir -p "$HOME/.local/share/zinit/zinit.git"

  bootstrap -p "zsh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Zinit already installed"* ]]
  [[ "$(pm_log)" != *"curl"* ]]
}

# --- argument handling -------------------------------------------------------

@test "rejects an unknown option with the usage text" {
  stub dnf

  bootstrap --definitely-not-an-option
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option: --definitely-not-an-option"* ]]
  [[ "$output" == *"Usage:"* ]]
}

@test "refuses -u without a package list" {
  stub dnf

  bootstrap -u
  [ "$status" -ne 0 ]
  [[ "$output" == *"Missing package list for -u"* ]]
}

# --- post-install steps ------------------------------------------------------

@test "skips the tmux plugin manager under --no-install" {
  bootstrap -p "tmux" --no-install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Skipping TPM install"* ]]
}

@test "installs TPM and its plugins for the tmux package" {
  stub dnf
  stub git
  stub tmux

  bootstrap -p "tmux"
  [ "$status" -eq 0 ]
  [[ "$(pm_log)" == *"git clone --depth 1 https://github.com/tmux-plugins/tpm"* ]]
  [[ "$output" == *"Installing tmux plugins via TPM"* ]]
}

@test "leaves an existing TPM checkout in place" {
  stub dnf
  stub git
  mkdir -p "$HOME/.local/share/tmux/plugins/tpm"

  bootstrap -p "tmux"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TPM already installed"* ]]
  [[ "$(pm_log)" != *"git clone"* ]]
}

@test "tells the user how to finish when tmux itself is missing" {
  stub dnf
  stub git

  bootstrap -p "tmux"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tmux not found; skipping plugin install"* ]]
}
