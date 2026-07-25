# shellcheck shell=bash
# Custom tmux-powerline segment: OS / Linux distribution badge (icon + name + version).
#
# The Nerd Font glyph is emitted as its raw UTF-8 bytes via printf '\xHH', which
# bash's builtin printf understands everywhere (including macOS's bash 3.2).
# Note: printf '\uHHHH' would NOT work on macOS (added in bash 4.2), so avoid it.
# Requires a Nerd Font.

run_segment() {
	local glyph base ver name   # UTF-8 byte-escapes, distro name, version

	case "$(uname -s)" in
	Darwin)
		glyph='\xef\x85\xb9'; base='macOS'   # U+F179 nf-fa-apple
		ver="$(sw_vers -productVersion 2>/dev/null)"
		;;
	Linux)
		if [ -r /etc/os-release ]; then
			# Runs inside a command substitution, so sourcing is contained.
			# shellcheck disable=SC1091
			. /etc/os-release
			ver="${VERSION_ID:-}"
			case "${ID:-}" in
			fedora) glyph='\xef\x8c\x8a'; base='Fedora' ;;   # U+F30A nf-linux-fedora
			ubuntu) glyph='\xef\x8c\x9b'; base='Ubuntu' ;;   # U+F31B nf-linux-ubuntu
			debian) glyph='\xef\x8c\x86'; base='Debian' ;;   # U+F306 nf-linux-debian
			arch)   glyph='\xef\x8c\x83'; base='Arch'   ;;   # U+F303 nf-linux-archlinux
			*)
				base="${NAME:-Linux}"
				case " ${ID_LIKE:-} " in
				*fedora*|*rhel*)   glyph='\xef\x8c\x8a' ;;
				*debian*|*ubuntu*) glyph='\xef\x8c\x86' ;;
				*arch*)            glyph='\xef\x8c\x83' ;;
				*)                 glyph='\xef\x85\xbc' ;;   # U+F17C nf-fa-linux (Tux)
				esac
				;;
			esac
		else
			glyph='\xef\x85\xbc'; base='Linux'; ver=''
		fi
		;;
	*)
		glyph='\xef\x85\xbc'; base="$(uname -s)"; ver=''
		;;
	esac

	# Append the version only when one is available.
	name="${base}${ver:+ $ver}"

	# shellcheck disable=SC2059
	printf "${glyph} %s\n" "$name"
	return 0
}
