#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit here if you add more stow packages) ---
DEFAULT_STOW_PKGS=("zsh" "nvim" "tmux")

# --- Globals ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
TARGET_DIR="$HOME"
ADOPT=false
DRY_RUN=false
UNSTOW=false
NO_INSTALL=false
STOW_PKGS=("${DEFAULT_STOW_PKGS[@]}")

# --- Helpers ---
log()  { printf '[bootstrap] %s\n' "$*"; }
err()  { printf '[bootstrap][error] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Options:
  -p "pkg1 pkg2"  Stow packages to apply (default: "zsh nvim tmux")
  -a              Use 'stow --adopt' (take over existing files into repo)
  -n              Dry-run (show what would happen)
  -U              Unstow (remove symlinks) instead of stowing
  --no-install    Skip package installation (git/stow/neovim/tmux/zsh/curl)
  -h, --help      Show this help

Examples:
  ./bootstrap.sh
  ./bootstrap.sh -p "zsh tmux" -a
  ./bootstrap.sh -n
  ./bootstrap.sh -U
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

detect_pm_and_install() {
  $NO_INSTALL && { log "Skipping package install (--no-install)."; return; }

  local need=()
  for bin in git stow curl; do
    have "$bin" || need+=("$bin")
  done
  # Optional QoL tools (ignore if already installed)
  for bin in neovim tmux zsh; do
    have "$bin" || need+=("$bin")
  done

  ((${#need[@]}==0)) && { log "All required tools already installed."; return; }

  if have dnf; then
    log "Installing with dnf: ${need[*]}"
    sudo dnf install -y "${need[@]}"
  elif have apt-get; then
    log "Installing with apt-get: ${need[*]}"
    sudo apt-get update -y
    sudo apt-get install -y "${need[@]}"
  elif have pacman; then
    log "Installing with pacman: ${need[*]}"
    sudo pacman -Sy --noconfirm "${need[@]}"
  else
    die "No supported package manager found. Install manually: ${need[*]}"
  fi
}

# back up a path if it exists and is NOT a symlink into this repo
backup_if_conflict() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    if [[ -L "$path" ]]; then
      local target
      target="$(readlink -f -- "$path" || true)"
      [[ "${target:-}" == "$REPO_ROOT"* ]] && return 0
    fi
    local ts bak
    ts="$(date +%Y%m%d-%H%M%S)"
    bak="${path}.bak.${ts}"
    log "Backing up existing: $path -> $bak"
    $DRY_RUN || mv -- "$path" "$bak"
  fi
}

# scan stow package to pre-backup potential conflicts
prebackup_for_pkg() {
  local pkg="$1" rel dst base
  base="$REPO_ROOT/$pkg"
  [[ -d "$base" ]] || die "Stow package not found: $pkg ($base)"
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"
    dst="$TARGET_DIR/$rel"
    backup_if_conflict "$dst"
  done < <(cd "$base" && find . -type f -print0)
}

run_stow() {
  local sim_flag=()
  $DRY_RUN && sim_flag=(-n)
  local adopt_flag=()
  $ADOPT && adopt_flag=(--adopt)

  if $UNSTOW; then
    log "Unstowing: ${STOW_PKGS[*]}"
    (set -x; stow "${sim_flag[@]}" -D -v -t "$TARGET_DIR" "${STOW_PKGS[@]}")
  else
    if ! $ADOPT; then
      for p in "${STOW_PKGS[@]}"; do
        prebackup_for_pkg "$p"
      done
    fi
    log "Stowing: ${STOW_PKGS[*]} (adopt=${ADOPT}, dry-run=${DRY_RUN})"
    (set -x; stow "${sim_flag[@]}" "${adopt_flag[@]}" -v -t "$TARGET_DIR" "${STOW_PKGS[@]}")
  fi
}

install_tpm() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  if [[ -d "$tpm_dir" ]]; then
    log "TPM already installed at $tpm_dir"
  else
    log "Installing TPM (tmux plugin manager)..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi
}

install_zinit() {
  local zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
  if [[ -d "$zinit_home" ]]; then
    log "Zinit already installed at $zinit_home"
  else
    log "Installing Zinit (zsh plugin manager)..."
    bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
  fi
}

# --- Parse args ---
while (( "$#" )); do
  case "${1:-}" in
    -p) shift; IFS=' ' read -r -a STOW_PKGS <<< "${1:-}";;
    -a) ADOPT=true;;
    -n) DRY_RUN=true;;
    -U) UNSTOW=true;;
    --no-install) NO_INSTALL=true;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 2;;
  esac
  shift || true
done

# --- Main ---
log "Repo: $REPO_ROOT"
log "Target: $TARGET_DIR"
log "Packages: ${STOW_PKGS[*]}"

$UNSTOW || detect_pm_and_install
run_stow

# Post steps
if [[ " ${STOW_PKGS[*]} " == *" tmux "* && $UNSTOW == false ]]; then
  install_tpm
fi
if [[ " ${STOW_PKGS[*]} " == *" zsh "* && $UNSTOW == false ]]; then
  install_zinit
fi

log "Done."
