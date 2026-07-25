# shellcheck shell=bash
# Custom tmux-powerline segment: OS / Linux distribution badge (icon + name).
# The Nerd Font glyph is emitted from its Unicode codepoint via printf, so it
# survives regardless of this file's encoding. Requires a Nerd Font.

run_segment() {
	local cp name   # Nerd Font codepoint (hex) + display name

	case "$(uname -s)" in
	Darwin)
		cp='f179'; name='macOS'   # nf-fa-apple
		;;
	Linux)
		if [ -r /etc/os-release ]; then
			# Runs inside a command substitution, so sourcing is contained.
			# shellcheck disable=SC1091
			. /etc/os-release
			case "${ID:-}" in
			fedora) cp='f30a'; name='Fedora' ;;   # nf-linux-fedora
			ubuntu) cp='f31b'; name='Ubuntu' ;;   # nf-linux-ubuntu
			debian) cp='f306'; name='Debian' ;;   # nf-linux-debian
			arch)   cp='f303'; name='Arch'   ;;   # nf-linux-archlinux
			*)
				name="${NAME:-Linux}"
				case " ${ID_LIKE:-} " in
				*fedora*|*rhel*)   cp='f30a' ;;
				*debian*|*ubuntu*) cp='f306' ;;
				*arch*)            cp='f303' ;;
				*)                 cp='f17c' ;;   # nf-fa-linux (generic Tux)
				esac
				;;
			esac
		else
			cp='f17c'; name='Linux'
		fi
		;;
	*)
		cp='f17c'; name="$(uname -s)"
		;;
	esac

	# shellcheck disable=SC2059
	printf "\u${cp} %s\n" "$name"
	return 0
}
