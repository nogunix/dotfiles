#==============================================================================
# Compile .zshrc only if it has been updated, to speed up Zsh startup
#==============================================================================
# NOTE: zsh's -nt is false when the right-hand file is missing (bash returns
# true), so testing only `.zshrc -nt .zshrc.zwc` never fires on a machine that
# has no .zwc yet -- the guard would wait for the file it is supposed to create.
if [[ -f ~/.zshrc && ( ! -f ~/.zshrc.zwc || ~/.zshrc -nt ~/.zshrc.zwc ) ]]; then
  zcompile ~/.zshrc
fi

#==============================================================================
# History
#==============================================================================
HISTFILE=$HOME/.zsh_history     # File to save command history
HISTSIZE=100000                 # Number of history entries kept in memory
SAVEHIST=1000000                # Number of history entries saved to HISTFILE

setopt inc_append_history       # Append commands to history file immediately
setopt share_history            # Share command history across all shells in real time
setopt hist_ignore_all_dups     # Ignore duplicate commands in history
setopt hist_save_no_dups        # When saving, remove older duplicate entries
setopt extended_history         # Save timestamp along with commands in history
setopt hist_expire_dups_first   # Remove duplicates first when trimming history

#==============================================================================
# Completion
#==============================================================================
typeset -U fpath

# zinit keeps one symlink per installed completion under its completions/ dir.
# When a plugin update drops a file upstream the symlink stays behind pointing at
# nothing, and compinit fails on it:
#   compinit:527: no such file or directory: .../zinit/completions/_sdd
# Delete those links -- a dangling _* symlink can only ever produce that error.
# Dropping the whole fpath entry instead would cost every completion the
# directory provides (~1000 files for zsh-completions) to silence one warning.
# Only writable directories are touched, so root-owned site-functions are left
# alone. Returns true when something was removed.
_zsh_prune_broken_completions() {
  local dir
  local -a broken
  integer pruned=0

  for dir in "${fpath[@]}"; do
    [[ -d $dir && -w $dir ]] || continue
    # (-@) resolves the link and still matches @ only when the target is gone.
    broken=( $dir/_*(N-@) )
    (( $#broken )) || continue
    command rm -f -- "${broken[@]}" && pruned=1
  done

  (( pruned ))
}

# compinit is invoked from zinit's Turbo block below, once every plugin has been
# added to fpath -- running it here would miss zsh-completions entirely. The
# prune has to wait for the same reason: zinit's completions dir only joins
# fpath when zinit is sourced, long after this point in the file.
# The full security audit is done at most once a day; -C reuses the dump otherwise.
_zsh_compinit() {
  autoload -Uz compinit
  local dump=${ZDOTDIR:-$HOME}/.zcompdump

  # A dump written before the prune still maps the completion we just removed.
  if _zsh_prune_broken_completions; then
    command rm -f -- "$dump" "$dump.zwc"
  fi

  if [[ -n ${dump}(#qN.mh+24) ]]; then
    compinit -d "$dump"
    { zcompile -R -- "$dump" } &!
  else
    compinit -C -d "$dump"
  fi
}

autoload -Uz colors; colors

# Enable menu selection with Tab
zstyle ':completion:*:default' menu select=2
# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# Apply LS_COLORS to completion list
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

#==============================================================================
# Shell Options
#==============================================================================
setopt auto_param_slash       # Add trailing slash when completing directory names
setopt auto_param_keys        # Auto-complete brackets
setopt mark_dirs              # Append / when expanding directories
setopt auto_menu              # Auto-complete through multiple matches on repeated Tab
# setopt correct              # Command spelling correction (disabled)
setopt interactive_comments   # Treat text after # as a comment even interactively
setopt magic_equal_subst      # Complete after = in options like --prefix=/usr
setopt complete_in_word       # Complete in the middle of a word
setopt print_eight_bit        # Allow display of non-ASCII filenames
setopt auto_cd                # Change directory by typing its name only
setopt no_beep                # Disable terminal bell

#==============================================================================
# Keybindings
#==============================================================================
# History search from partial input (Ctrl+P/Ctrl+N)
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
bindkey -e

#==============================================================================
# Zinit (Plugin Manager)
#==============================================================================
### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load important annexes (without Turbo)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

# --- Plugins ---
# Turbo mode: these load just after the first prompt is drawn rather than
# blocking it. zinit walks the list one plugin per prompt, so autosuggestions
# becomes active from the second prompt onwards.
zinit wait lucid light-mode for \
    atinit'_zsh_compinit; zicdreplay' \
        zsh-users/zsh-completions \
    atload'_zsh_autosuggest_start' \
        zsh-users/zsh-autosuggestions

# zoxide (replaces rupa/z). Fetched as a prebuilt binary from GitHub releases,
# so no package manager is needed on either macOS or Linux.
zinit ice from"gh-r" as"command" pick"zoxide"
zinit light ajeetdsouza/zoxide
### End of Zinit's installer chunk

#==============================================================================
# zoxide (smarter cd: `z <query>` to jump, `zi` for an interactive pick)
#==============================================================================
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

#==============================================================================
# Aliases & Exports
#==============================================================================
export PATH="$HOME/.local/bin:$PATH"

# Clipboard copy shortcut:
# Prefer the repo helper, but degrade gracefully if the helper is not installed.
clip() {
  local data encoded osc52 max_bytes

  if command -v clipboard-copy >/dev/null 2>&1; then
    command clipboard-copy "$@"
    return
  fi

  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    command wl-copy "$@"
    return
  fi

  if [[ -n "${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
    command xclip -selection clipboard "$@"
    return
  fi

  if [[ -n "${DISPLAY:-}" ]] && command -v xsel >/dev/null 2>&1; then
    command xsel --clipboard --input "$@"
    return
  fi

  if command -v osc52-copy >/dev/null 2>&1; then
    command osc52-copy "$@"
    return
  fi

  max_bytes="${OSC52_MAX_BYTES:-100000}"

  if (($# > 0)); then
    data="$*"
  else
    data="$(cat)"
  fi

  [[ -z "$data" ]] && return 0

  if ((${#data} > max_bytes)); then
    printf 'clip: refusing to copy %d bytes (limit: %d)\n' "${#data}" "$max_bytes" >&2
    return 1
  fi

  if ! command -v base64 >/dev/null 2>&1; then
    printf 'clip: base64 is required for OSC 52 fallback\n' >&2
    return 1
  fi

  encoded="$(printf '%s' "$data" | base64 | tr -d '\r\n')"
  osc52="$(printf '\033]52;c;%s\a' "$encoded")"

  if [[ -n "${TMUX:-}" ]]; then
    # In tmux, we can send OSC 52 directly if 'set-clipboard' is on.
    # This also updates tmux's internal clipboard.
    printf '%s' "$osc52"
  elif [[ "${TERM:-}" == screen* ]]; then
    # Screen passthrough: \eP\e]52;... \a\e\
    printf '\033P\033%s\033\\' "$osc52"
  else
    printf '%s' "$osc52"
  fi
}

# Enable colored output for ls
alias ls='ls --color=auto'
alias rsyncp='rsync -a --info=progress2'
alias vim='nvim'

#==============================================================================
# Local Configuration
#==============================================================================
if [[ -f ~/.zshrc.local ]]; then
  source ~/.zshrc.local
fi
