# shellcheck shell=bash
# Custom tmux-powerline segment: "[session] window:name".
# Emits tmux format placeholders; tmux expands them when drawing the status bar.

run_segment() {
	echo "[#S] #I:#W"
	return 0
}
