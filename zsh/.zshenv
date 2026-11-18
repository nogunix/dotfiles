# Read by every zsh: login or not, interactive or not. That includes the plain
# `zsh -c` an editor's agent or a script runs commands in, which never reaches
# .zprofile or .zshrc -- so the PATH entries those commands need live here.
#
# It runs for every zsh, scripts included, so keep it to cheap assignments: no
# subprocesses, no output. Directories already on PATH are left where they are,
# so an order set up by a login shell (and inherited by tmux panes) survives.
() {
  local dir
  local -a brew
  # Only probe the platform's own Homebrew prefix: /home is an autofs mount
  # point on macOS, and a stat under it costs ~45 ms per shell.
  case $OSTYPE in
    darwin*) brew=( /opt/homebrew/{sbin,bin} ) ;;
    linux*)  brew=( /home/linuxbrew/.linuxbrew/{sbin,bin} ) ;;
  esac
  # Prepended in reverse, so ~/.local/bin ends up first.
  for dir in $brew $HOME/.local/bin; do
    [[ -d $dir ]] && (( ! ${path[(Ie)$dir]} )) && path=( $dir $path )
  done
}
