# dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/nogunix/dotfiles/actions/workflows/bats.yml/badge.svg?branch=main)](https://github.com/nogunix/dotfiles/actions/workflows/bats.yml)
[![Lint](https://github.com/nogunix/dotfiles/actions/workflows/shellcheck.yml/badge.svg?branch=main)](https://github.com/nogunix/dotfiles/actions/workflows/shellcheck.yml)


A personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/).
It is structured as an operational setup repo: `bootstrap.sh` installs prerequisites,
stows packages into `$HOME`, and backs up conflicting files before linking them.

Includes managed configuration for:

- Zsh (`.zshrc`) with [Zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Neovim (`init.lua` and other configs)
- Tmux (`tmux.conf`)
- Universal Ctags (`ctags`)
- Clipboard wrappers that prefer Wayland/X11/macOS tools locally and OSC 52 for remote sessions

## Requirements

- Git
- GNU Stow
- Curl
- Optional: Zsh, Tmux, Neovim
- Optional: Universal Ctags when the `ctags` stow package is selected

The `bootstrap.sh` script checks for missing tools and attempts to install them
using `dnf`, `apt-get`, `pacman`, or Homebrew.

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/nogunix/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Run the bootstrap script**
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```
   This will:
   - Install required base packages when possible
   - Stow the default packages (`zsh`, `nvim`, `tmux`, `ctags`)
   - Backup conflicting files with a `.bak.<timestamp>` suffix
   - Install Zinit if `zsh` is in the selected package list
   - Attempt to install Universal Ctags if `ctags` is selected and no `ctags` binary is available

3. **Reload configurations**
   - Zsh: `exec zsh` or restart your terminal
   - Neovim: Launch `nvim` to verify plugins and configs

## Usage

```bash
./bootstrap.sh [options]
```

### Options

| Option          | Description |
|-----------------|-------------|
| `-p "pkg1 pkg2"` | Specify stow packages (default: `zsh nvim tmux ctags`) |
| `-a`             | Use `--adopt` to move existing files into the repo |
| `-n`             | Dry run (show what would happen) |
| `-u "pkg1 pkg2"` | Unstow only the listed packages (implies `-U`) |
| `-U`             | Unstow (remove symlinks) |
| `--no-install`   | Skip installing base dependencies and ctags |
| `-h`, `--help`   | Show help message |

### Examples

- Stow only `zsh` and `tmux`:
  ```bash
  ./bootstrap.sh -p "zsh tmux"
  ```
- Adopt existing config into repo:
  ```bash
  ./bootstrap.sh -a
  ```
- Dry run to see changes:
  ```bash
  ./bootstrap.sh -n
  ```
- Remove all symlinks:
  ```bash
  ./bootstrap.sh -U
  ```
- Remove only the `tmux` symlinks:
  ```bash
  ./bootstrap.sh -u "tmux"
  ```

## Remote Clipboard over SSH

This repository includes clipboard helpers that auto-select the best available
copy backend:

- Wayland via `wl-copy` when `$WAYLAND_DISPLAY` is available
- X11 via `xclip` or `xsel` when `$DISPLAY` is available
- OSC 52 when running in `tmux` or over SSH without a usable display server
- `pbcopy` for local macOS sessions
- OSC 52 as the final fallback

### What works

- `tmux` copy-mode yanks (`y`, mouse selection)
- `clip`
- `clipboard-copy`
- `xclip` and `xsel` copy-style usage
- Neovim/Vim yanks through the available clipboard provider

### What does not work portably

- Reading the local desktop clipboard from the remote host (`xclip -o`, `xsel -o`)

OSC 52 is primarily a remote-to-local copy mechanism. If you need bidirectional
clipboard sync, use X11 forwarding, a desktop agent, or terminal-specific tooling.

### Terminal prerequisites

- iTerm2:
  Enable the setting that allows terminal apps to access the clipboard.
- gnome-terminal / other VTE-based terminals:
  Prefer `ssh -X` or `ssh -Y` so the remote host gets a working `$DISPLAY`.
  The helper scripts will then use the remote system `xclip`/`xsel` instead of OSC 52.

### Typical usage

```bash
printf 'hello\n' | clip
printf 'hello\n' | clipboard-copy
printf 'hello\n' | xclip -selection clipboard
printf 'hello\n' | xsel --clipboard --input
```

Inside `tmux`, enter copy-mode and press `y` to send the selection to the local
terminal clipboard.

With `gnome-terminal`, connect using X11 forwarding:

```bash
ssh -Y user@server
```

## Adding New Configs

1. Create a new folder in the repo with the package name:
   ```bash
   mkdir -p newpkg/.config/newpkg
   ```
2. Place your config files inside that folder using the same relative path from `$HOME`.
3. Stow it:
   ```bash
   ./bootstrap.sh -p "newpkg"
   ```

## Backup Strategy

When not using `--adopt`, any existing file that would conflict is automatically backed up with a `.bak.<timestamp>` suffix in its original location.

## Validation

Run these after changing the repo:

```bash
bats tests/
shellcheck bootstrap.sh zsh/.local/bin/*
shellcheck tests/nvim-headless.sh
tests/nvim-headless.sh
```

Additional focused checks:

```bash
bats tests/bootstrap.bats
bats tests/clipboard-backend.bats
bats tests/clipboard-integration.bats
tests/nvim-headless.sh --health
```

## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE) for details.

This is my personal project. It is created and maintained in my personal capacity, and has no relation to my employer's business or confidential information.
