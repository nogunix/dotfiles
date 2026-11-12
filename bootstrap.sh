#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit here if you add more stow packages) ---
# Add "ctags" so we can manage ~/.ctags.d via GNU Stow
DEFAULT_STOW_PKGS=("zsh" "nvim" "tmux" "ctags")

# Directories that other tools install into (Claude Code, uv, pipx, ...).
# Left alone, stow folds such a directory into one symlink back into the repo,
# or folds its parent when that does not exist yet, and from then on every
# binary installed there lands in the working tree. These are always created
# as real directories, so stow links the package's files into them one by one.
NO_FOLD_DIRS=(".local/bin")

# --- Globals ---
SCRIPT_PATH="${BASH_SOURCE[0]}"
# ${path%/*} leaves a bare filename untouched, so `bash bootstrap.sh` would
# otherwise try to cd into the script itself. Without a slash bash resolved it
# relative to the cwd, so that is the directory to use.
case "$SCRIPT_PATH" in
  */*) SCRIPT_DIR="$(cd -- "${SCRIPT_PATH%/*}" && pwd -P)" ;;
  *)   SCRIPT_DIR="$(pwd -P)" ;;
esac
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
  --no-install    Skip every install step: base packages, ctags, Zinit
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

# Print the first supported package manager found in PATH; return 1 if none.
detect_pm() {
  local pm
  for pm in dnf apt-get pacman brew; do
    have "$pm" && { printf '%s\n' "$pm"; return 0; }
  done
  return 1
}

# pm_install <pm> <pkg...> — install packages via the given package manager.
pm_install() {
  local pm="$1"; shift
  case "$pm" in
    dnf)     sudo dnf install -y "$@";;
    apt-get) sudo apt-get update -y
             sudo apt-get install -y "$@";;
    pacman)  sudo pacman -Sy --noconfirm "$@";;
    brew)    brew install "$@";;
    *)       return 1;;
  esac
}

# pm_install_ctags <pm> — install Universal Ctags with PM-specific fallbacks.
pm_install_ctags() {
  case "$1" in
    dnf)     sudo dnf install -y universal-ctags;;
    apt-get) sudo apt-get update -y || true
             sudo apt-get install -y universal-ctags \
               || sudo apt-get install -y exuberant-ctags;;
    pacman)  sudo pacman -Sy --noconfirm universal-ctags \
               || sudo pacman -Sy --noconfirm ctags;;
    brew)    brew install universal-ctags;;
    *)       return 1;;
  esac
}

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

  local pm
  if ! pm="$(detect_pm)"; then
    die "No supported package manager found (supported: dnf, apt-get, pacman, brew). Install manually: ${need[*]}"
  fi

  log "Installing with $pm: ${need[*]}"
  pm_install "$pm" "${need[@]}"
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

  local pm
  if pm="$(detect_pm)" && pm_install_ctags "$pm"; then
    log "Installed ctags via $pm."
    return 0
  fi

  err "Failed to install ctags automatically."
  err "Please install Universal Ctags manually or ensure 'ctags' is in PATH."
  return 1
}

# back up a path if it exists and does not already resolve into this repo
backup_if_conflict() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    # Once a package is stowed, stow may have folded a whole directory into a
    # single symlink back here. The entries under it are then the repo's own
    # files, and moving one would rename a tracked file out from under git, so
    # resolve the parent physically and bail out when we land inside the repo.
    local parent
    if parent="$(cd -- "${path%/*}" 2>/dev/null && pwd -P)"; then
      [[ "$parent" == "$REPO_ROOT" || "$parent" == "$REPO_ROOT"/* ]] && return 0
    fi
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

# The path a directory symlink resolves to, or nothing if it is dangling.
physical_dir() { (cd -- "$1" 2>/dev/null && pwd -P) || true; }

# ensure_real_dirs — make every NO_FOLD_DIRS entry a selected package ships a
# real directory under $TARGET_DIR, unfolding one an earlier stow left as a
# symlink into this repo. Files already installed through that symlink live in
# the package directory; they are listed so they can be moved out by hand.
ensure_real_dirs() {
  local pkg dir dst resolved
  for pkg in "${STOW_PKGS[@]}"; do
    for dir in "${NO_FOLD_DIRS[@]}"; do
      [[ -d "$REPO_ROOT/$pkg/$dir" ]] || continue
      dst="$TARGET_DIR/$dir"

      if [[ -L "$dst" ]]; then
        resolved="$(physical_dir "$dst")"
        [[ -n "$resolved" ]] || die "Dangling symlink in the way: $dst"
        [[ "$resolved" == "$REPO_ROOT" || "$resolved" == "$REPO_ROOT"/* ]] || continue
        log "Unfolding $dst (was a symlink into the repo)"
        if have git && git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
          local untracked
          untracked="$(git -C "$REPO_ROOT" ls-files --others --exclude-standard -- "$pkg/$dir")"
          [[ -z "$untracked" ]] || err "Untracked files in $pkg/$dir, installed through the old symlink; move them to $dst:"$'\n'"$untracked"
        fi
        $DRY_RUN && continue
        rm -- "$dst"
      fi

      [[ -d "$dst" ]] && continue
      log "Creating $dst"
      $DRY_RUN || mkdir -p -- "$dst"
    done
  done
}

validate_selected_packages() {
  local p
  for p in "${STOW_PKGS[@]}"; do
    [[ -d "$REPO_ROOT/$p" ]] || die "Selected package '$p' not found in repo: $REPO_ROOT/$p"
  done
}

run_stow() {
  local stow_args=(-d "$REPO_ROOT" -v -t "$TARGET_DIR")
  $DRY_RUN && stow_args=(-n "${stow_args[@]}")

  if $UNSTOW; then
    log "Unstowing: ${STOW_PKGS[*]}"
    (set -x; stow -D "${stow_args[@]}" "${STOW_PKGS[@]}")
  else
    ensure_real_dirs
    if ! $ADOPT; then
      for p in "${STOW_PKGS[@]}"; do
        prebackup_for_pkg "$p"
      done
    fi
    $ADOPT && stow_args=(--adopt "${stow_args[@]}")
    log "Stowing: ${STOW_PKGS[*]} (adopt=${ADOPT}, dry-run=${DRY_RUN})"
    (set -x; stow "${stow_args[@]}" "${STOW_PKGS[@]}")
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
  if $NO_INSTALL; then
    log "Skipping Zinit install (--no-install)."
  else
    install_zinit
  fi
fi

log "Done."
