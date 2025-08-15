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
# Clipboard copy shortcut:
# Automatically choose wl-copy for Wayland or xclip for X11
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  alias clip='wl-copy'
else
  alias clip='xclip -selection c'
fi

# Enable colored output for ls
alias ls='ls --color=auto'

# Environment variables
# export LIBVA_DRIVER_NAME=radeonsi
