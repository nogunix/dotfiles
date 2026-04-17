#==============================================================================
# Compile .zshrc only if it has been updated, to speed up Zsh startup
#==============================================================================
if [[ -f ~/.zshrc && ~/.zshrc -nt ~/.zshrc.zwc ]]; then
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
typeset -a _existing_fpath
typeset _fpath_dir _completion_link
integer _has_broken_completion

for _fpath_dir in "${fpath[@]}"; do
  [[ -d "$_fpath_dir" ]] || continue

  _has_broken_completion=0
  for _completion_link in "$_fpath_dir"/_*(N); do
    if [[ -L "$_completion_link" && ! -e "$_completion_link" ]]; then
      _has_broken_completion=1
      break
    fi
  done

  (( _has_broken_completion == 0 )) && _existing_fpath+=("$_fpath_dir")
done
fpath=("${_existing_fpath[@]}")

unset _existing_fpath _fpath_dir _completion_link _has_broken_completion

autoload -Uz compinit; compinit
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
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light rupa/z
### End of Zinit's installer chunk

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

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk
