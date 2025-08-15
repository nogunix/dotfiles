# Zshの起動を高速化するために、.zshrcが更新された場合のみコンパイルする
if [[ -f ~/.zshrc && ~/.zshrc -nt ~/.zshrc.zwc ]]; then
  zcompile ~/.zshrc
fi

#==============================================================================
# History
#==============================================================================
HISTFILE=$HOME/.zsh_history     # 履歴を保存するファイル
HISTSIZE=100000                 # メモリ上に保存する履歴のサイズ
SAVEHIST=1000000                # 上述のファイルに保存する履歴のサイズ

setopt inc_append_history       # 実行時に履歴をファイルにに追加していく
setopt share_history            # 履歴を他のシェルとリアルタイム共有する
setopt hist_ignore_all_dups     # ヒストリーに重複を表示しない
setopt hist_save_no_dups        # 重複するコマンドが保存されるとき、古い方を削除する。
setopt extended_history         # コマンドのタイムスタンプをHISTFILEに記録する
setopt hist_expire_dups_first   # HISTFILEのサイズがHISTSIZEを超える場合は、最初に重複を削除します

#==============================================================================
# Completion
#==============================================================================
autoload -Uz compinit; compinit
autoload -Uz colors; colors

# Tabで選択できるようにする
zstyle ':completion:*:default' menu select=2
# 補完で大文字小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
# ファイル補完候補に色を付ける
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

#==============================================================================
# Shell Options
#==============================================================================
setopt auto_param_slash       # ディレクトリ名の補完で末尾の / を自動的に付加
setopt auto_param_keys        # カッコを自動補完
setopt mark_dirs              # ファイル名の展開でディレクトリにマッチした場合 末尾に / を付加
setopt auto_menu              # 補完キー連打で順に補完候補を自動で補完
# setopt correct              # スペルミス訂正 (無効)
setopt interactive_comments   # コマンドラインでも # 以降をコメントと見なす
setopt magic_equal_subst      # --prefix=/usr などの = 以降でも補完できる
setopt complete_in_word       # 語の途中でもカーソル位置で補完
setopt print_eight_bit        # 日本語ファイル名を表示可能にする
setopt auto_cd                # ディレクトリ名だけでcdする
setopt no_beep                # ビープ音を消す

#==============================================================================
# Keybindings
#==============================================================================
# コマンドを途中まで入力後、historyから絞り込み (Ctrl+P/Ctrl+N)
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

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
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
# --- Aliases ---
# クリップボードへのコピー。
# Wayland/X11環境を自動で判別し、適切なコマンド (wl-copy/xclip) を使います。
if [[ -n "$WAYLAND_DISPLAY" ]]; then
  alias clip='wl-copy'
else
  alias clip='xclip -selection c'
fi

# --- Exports ---
export LIBVA_DRIVER_NAME=radeonsi
alias ls='ls --color=auto'
