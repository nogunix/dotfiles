# shellcheck shell=bash
# shellcheck disable=SC2034  # vars/arrays here are consumed by tmux-powerline
# tmux-powerline configuration — reproduces the original hand-written status bar.
#
# Sourced BEFORE the built-in theme (which only assigns unset values), so
# everything below wins without a custom theme file. Requires a Nerd Font.
#
# Original look: a blue chip "[session] win:name" on the left, the pane's
# current path on the right, a dark-blue (#2A2F41) bar, window list hidden.

# --- General -----------------------------------------------------------------
export TMUX_POWERLINE_PATCHED_FONT_IN_USE="true"
export TMUX_POWERLINE_THEME="default"
export TMUX_POWERLINE_STATUS_JUSTIFICATION="left"
export TMUX_POWERLINE_STATUS_INTERVAL="5"
export TMUX_POWERLINE_STATUS_LEFT_LENGTH="150"
export TMUX_POWERLINE_STATUS_RIGHT_LENGTH="100"
export TMUX_POWERLINE_DIR_USER_SEGMENTS="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-powerline/segments"

# --- Palette (original) ------------------------------------------------------
tn_blue='#7aa2f7'   # chip background
tn_bar='#2A2F41'    # bar background + chip text
tn_fg='#c0caf5'     # foreground
tn_gray='#414868'   # secondary chip (OS badge)

export TMUX_POWERLINE_DEFAULT_BACKGROUND_COLOR="$tn_bar"
export TMUX_POWERLINE_DEFAULT_FOREGROUND_COLOR="$tn_fg"

# --- Separators (Nerd Font) --------------------------------------------------
TMUX_POWERLINE_SEPARATOR_LEFT_BOLD=""    # U+E0B2
TMUX_POWERLINE_SEPARATOR_LEFT_THIN=""    # U+E0B3
TMUX_POWERLINE_SEPARATOR_RIGHT_BOLD=""   # U+E0B0
TMUX_POWERLINE_SEPARATOR_RIGHT_THIN=""   # U+E0B1

# Match the git branch symbol to the gray chip's light text. The segment
# hardcodes a `colour<N>` (256-palette) prefix, so use the nearest index to #c0caf5.
export TMUX_POWERLINE_SEG_VCS_BRANCH_GIT_SYMBOL_COLOUR="189"   # #d7d7ff, ~ #c0caf5

# --- Left: session (blue) | OS (gray) ----------------------------------------
TMUX_POWERLINE_LEFT_STATUS_SEGMENTS=(
	"session_label $tn_blue $tn_bar"
	"os_icon $tn_gray $tn_fg"
)

# --- Right: git branch (gray) | pane current path (blue) ----------------------
# Mirrors the left (outer = blue, inner = gray). branch shows only in a repo.
TMUX_POWERLINE_RIGHT_STATUS_SEGMENTS=(
	"vcs_branch $tn_gray $tn_fg"
	"pane_path $tn_blue $tn_bar"
)

# --- Window list: hidden (as in the original) --------------------------------
# A no-op style directive renders nothing but keeps the array non-empty so the
# plugin does not fall back to its default window formats.
TMUX_POWERLINE_WINDOW_STATUS_CURRENT=("#[default]")
TMUX_POWERLINE_WINDOW_STATUS_FORMAT=("#[default]")
