# shellcheck shell=bash
# Custom tmux-powerline segment: OS / Linux distribution badge (icon + name).
#
# The Nerd Font glyph is emitted as its raw UTF-8 bytes via printf '\xHH', which
# bash's builtin printf understands everywhere (including macOS's bash 3.2).
# Note: printf '\uHHHH' would NOT work on macOS (added in bash 4.2), so avoid it.
# Requires a Nerd Font.

run_segment() {
	local glyph name   # UTF-8 byte-escapes + display name

	case "$(uname -s)" in
	Darwin)
		glyph='\xef\x85\xb9'; name='macOS'   # U+F179 nf-fa-apple
		;;
	Linux)
		if [ -r /etc/os-release ]; then
			# Runs inside a command substitution, so sourcing is contained.
			# shellcheck disable=SC1091
			. /etc/os-release
			case "${ID:-}" in
			fedora) glyph='\xef\x8c\x8a'; name='Fedora' ;;   # U+F30A nf-linux-fedora
			ubuntu) glyph='\xef\x8c\x9b'; name='Ubuntu' ;;   # U+F31B nf-linux-ubuntu
			debian) glyph='\xef\x8c\x86'; name='Debian' ;;   # U+F306 nf-linux-debian
			arch)   glyph='\xef\x8c\x83'; name='Arch'   ;;   # U+F303 nf-linux-archlinux
			*)
				name="${NAME:-Linux}"
				case " ${ID_LIKE:-} " in
				*fedora*|*rhel*)   glyph='\xef\x8c\x8a' ;;
				*debian*|*ubuntu*) glyph='\xef\x8c\x86' ;;
				*arch*)            glyph='\xef\x8c\x83' ;;
				*)                 glyph='\xef\x85\xbc' ;;   # U+F17C nf-fa-linux (Tux)
				esac
				;;
			esac
		else
			glyph='\xef\x85\xbc'; name='Linux'
		fi
		;;
	*)
		glyph='\xef\x85\xbc'; name="$(uname -s)"
		;;
	esac

	# shellcheck disable=SC2059
	printf "${glyph} %s\n" "$name"
	return 0
}
