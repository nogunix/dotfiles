#!/bin/sh
# Print the git chip of the tmux status bar for the directory given in $1.
#
# This is the only genuinely dynamic part of the bar, so it is the only thing
# tmux still forks for (once per status-interval, one `git` exec in the common
# case). Everything else is a plain tmux format.
#
# The chip's colours live in tmux.conf as the @git_pre / @git_post / @git_none
# user options; tmux re-expands this script's output as a format, so emitting
# the option references keeps the whole palette in one file.
#
#   in a repo:  <@git_pre>branch<@git_post>
#   otherwise:  <@git_none>   (just the separator leading into the path chip)

set -u

max_len=24
trunc='…'

path="${1:-}"
[ -n "$path" ] || { printf '%s\n' '#{@git_none}'; exit 0; }

if ! branch="$(git -C "$path" symbolic-ref --quiet --short HEAD 2>/dev/null)"; then
	# Detached HEAD still has a short sha; anything else is not a repo.
	if sha="$(git -C "$path" rev-parse --short HEAD 2>/dev/null)"; then
		branch=":$sha"
	else
		printf '%s\n' '#{@git_none}'
		exit 0
	fi
fi

if [ "${#branch}" -gt "$max_len" ]; then
	branch="$(printf "%.$((max_len - 1))s" "$branch")$trunc"
fi

# tmux re-expands this output as a format, where '#' is the escape character.
case "$branch" in
*'#'*) branch="$(printf '%s' "$branch" | sed 's/#/##/g')" ;;
esac

printf '%s%s%s\n' '#{@git_pre}' "$branch" '#{@git_post}'
