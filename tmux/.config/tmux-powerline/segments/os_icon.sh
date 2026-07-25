# shellcheck shell=bash
# Custom tmux-powerline segment: kernel version with an OS-appropriate glyph.
#
# e.g. on Linux:   7.1.3
#      on macOS:   23.5.0
#
# The glyph is emitted as raw UTF-8 bytes via printf '\xHH', which bash's
# builtin printf understands everywhere (including macOS's bash 3.2). Note:
# printf '\uHHHH' would NOT work on macOS (added in bash 4.2), so avoid it.
# Requires a Nerd Font.

run_segment() {
	local kglyph kernel

	case "$(uname -s)" in
	Linux) kglyph='\xef\x85\xbc' ;;   # U+F17C nf-fa-linux (Tux)
	*)     kglyph='\xef\x80\x93' ;;   # U+F013 nf-fa-cog (macOS/other)
	esac

	# Kernel major.minor.patch (strip distro/arch suffix, e.g. 7.1.3-201.fc44 -> 7.1.3).
	kernel="$(uname -r)"
	kernel="${kernel%%-*}"

	# shellcheck disable=SC2059
	printf "${kglyph} %s\n" "$kernel"
	return 0
}
