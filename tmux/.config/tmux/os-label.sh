#!/usr/bin/env bash
# Print the OS label shown in the tmux status bar's second chip.
#
# e.g. on Linux:   7.1.3          (Tux + kernel major.minor.patch)
#      on macOS:   macOS 14.5     (Apple + product version)
#      on BSD:     14.0           (terminal + kernel major.minor.patch)
#
# tmux.conf runs this once at config load and caches the result in the
# @os_label user option, so the status bar never forks for it again.
#
# Glyphs are emitted as raw UTF-8 bytes via printf '\xHH', which bash's builtin
# printf understands everywhere (including macOS's bash 3.2). Note: printf
# '\uHHHH' would NOT work on macOS (added in bash 4.2), so avoid it.
# Requires a Nerd Font.

set -uo pipefail

glyph=
text=
ver=

case "$(uname -s)" in
Darwin)
	glyph='\xef\x85\xb9'                       # U+F179 nf-fa-apple
	ver="$(sw_vers -productVersion 2>/dev/null)"
	text="macOS${ver:+ $ver}"
	;;
Linux)
	glyph='\xef\x85\xbc'                       # U+F17C nf-fa-linux (Tux)
	text="$(uname -r)"; text="${text%%-*}"     # kernel major.minor.patch
	;;
*)
	glyph='\xef\x84\xa0'                       # U+F120 nf-fa-terminal (BSD/other)
	text="$(uname -r)"; text="${text%%-*}"
	;;
esac

# shellcheck disable=SC2059
printf "${glyph} %s\n" "$text"
