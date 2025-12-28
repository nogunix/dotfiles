#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit here if you add more stow packages) ---
# Add "ctags" so we can manage ~/.ctags.d via GNU Stow
DEFAULT_STOW_PKGS=("zsh" "nvim" "tmux" "ctags")

# --- Globals ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
TARGET_DIR="$HOME"
ADOPT=false
DRY_RUN=false
UNSTOW=false
NO_INSTALL=false
STOW_PKGS=("${DEFAULT_STOW_PKGS[@]}")
UNSTOW_PKGS=()

# --- Helpers ---
log()  { printf '[bootstrap] %s\n' "$*"; }
err()  { printf '[bootstrap][error] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [options]

Options:
  -p "pkg1 pkg2"  Stow packages to apply (default: "zsh nvim tmux ctags")
  -a              Use 'stow --adopt' (take over existing files into repo)
  -n              Dry-run (show what would happen)
  -u "pkg1 pkg2"  Unstow only the specified packages (implies -U)
  -U              Unstow (remove symlinks) instead of stowing
  --no-install    Skip package installation (git/stow/neovim/tmux/zsh/curl/ctags)
  -h, --help      Show this help

Examples:
  ./bootstrap.sh
  ./bootstrap.sh -p "zsh tmux" -a
  ./bootstrap.sh -n
  ./bootstrap.sh -U
  ./bootstrap.sh -u "tmux"
EOF
}

have() { command -v "$1" >/dev/null 2>&1; }

detect_pm_and_install_base() {
  $NO_INSTALL && { log "Skipping base package install (--no-install)."; return; }

  local need=()
  for bin in git stow curl; do
    have "$bin" || need+=("$bin")
  done
  # Optional QoL tools (ignore if already installed)
  for bin in neovim tmux zsh; do
    have "$bin" || need+=("$bin")
  done

  ((${#need[@]}==0)) && { log "All required base tools already installed."; return; }

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

# Install ctags CLI if "ctags" package is selected
install_ctags_cli_if_requested() {
  $NO_INSTALL && { log "Skipping ctags install (--no-install)."; return; }

  case " ${STOW_PKGS[*]} " in
    *" ctags "*) ;;
    *) return 0;;
  esac

  # If any viable ctags is present, we're good.
  if have ctags; then
    log "ctags CLI already available: $(ctags --version 2>/dev/null | head -n1 || echo present)"
    return 0
  fi

  log "ctags CLI not found. Attempting to install Universal Ctags…"

  if have dnf; then
    # Fedora/RHEL-based systems
    if sudo dnf install -y universal-ctags; then
      log "Installed universal-ctags via dnf."
      return 0
    fi
  elif have apt-get; then
    # Debian/Ubuntu-based systems (universal-ctags package available in recent years)
    sudo apt-get update -y || true
    if sudo apt-get install -y universal-ctags; then
      log "Installed universal-ctags via apt-get."
      return 0
    fi
    # Fallback (for older environments): exuberant-ctags
    if sudo apt-get install -y exuberant-ctags; then
      log "Installed exuberant-ctags via apt-get (fallback)."
      return 0
    fi
  elif have pacman; then
    # Arch-based systems (community/universal-ctags)
    if sudo pacman -Sy --noconfirm universal-ctags; then
      log "Installed universal-ctags via pacman."
      return 0
    fi
    # Fallback: possibility of ctags remaining as is
    if sudo pacman -Sy --noconfirm ctags; then
      log "Installed ctags via pacman (fallback)."
      return 0
    fi
  fi

  err "Failed to install ctags automatically."
  err "Please install Universal Ctags manually or ensure 'ctags' is in PATH."
  return 1
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

validate_selected_packages() {
  local p
  for p in "${STOW_PKGS[@]}"; do
    [[ -d "$REPO_ROOT/$p" ]] || die "Selected package '$p' not found in repo: $REPO_ROOT/$p"
  done
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
    -u)
      shift
      [[ "${1:-}" ]] || die "Missing package list for -u."
      IFS=' ' read -r -a _tmp_unstow <<< "${1:-}"
      UNSTOW=true
      UNSTOW_PKGS+=("${_tmp_unstow[@]}")
      ;;
    -U) UNSTOW=true;;
    --no-install) NO_INSTALL=true;;
    -h|--help) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 2;;
  esac
  shift || true
done

# If specific packages were requested for unstow, operate on those
if $UNSTOW && ((${#UNSTOW_PKGS[@]} > 0)); then
  STOW_PKGS=("${UNSTOW_PKGS[@]}")
fi

# --- Main ---
log "Repo: $REPO_ROOT"
log "Target: $TARGET_DIR"
log "Packages: ${STOW_PKGS[*]}"

# Ensure selected packages exist before doing anything
validate_selected_packages

# Install base toolchain (git/stow/curl/neovim/tmux/zsh)
$UNSTOW || detect_pm_and_install_base

# If user chose the "ctags" package, ensure ctags CLI exists
$UNSTOW || install_ctags_cli_if_requested || true

# Perform stow/unstow
run_stow

# Post steps
if [[ " ${STOW_PKGS[*]} " == *" zsh "* && $UNSTOW == false ]]; then
  install_zinit
fi

log "Done."
