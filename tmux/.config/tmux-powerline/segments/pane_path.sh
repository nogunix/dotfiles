# shellcheck shell=bash
# Custom tmux-powerline segment: the active pane's current path.
# Emits a tmux format placeholder; tmux expands it when drawing the status bar.

run_segment() {
	echo "#{pane_current_path}"
	return 0
}
