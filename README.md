# dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/nogunix/dotfiles/actions/workflows/bats.yml/badge.svg?branch=main)](https://github.com/nogunix/dotfiles/actions/workflows/bats.yml)
[![Lint](https://github.com/nogunix/dotfiles/actions/workflows/shellcheck.yml/badge.svg?branch=main)](https://github.com/nogunix/dotfiles/actions/workflows/shellcheck.yml)


A personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/).
Includes automatic setup for:

- Zsh (`.zshrc`) with [Zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Neovim (`init.lua` and other configs)
- Tmux (`tmux.conf`)
- Universal Ctags (`ctags`)
- OSC 52 clipboard helpers for SSH/tmux sessions

## Requirements

- Git
- GNU Stow
- Curl
- Optional: Zsh, Tmux, Neovim
- The `ctags` CLI is installed automatically if `ctags` is in the package list

The `bootstrap.sh` script will check for these and attempt to install missing packages using your system package manager (`dnf`, `apt-get`, or `pacman`).

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
   - Install required packages
   - Stow the default packages (`zsh`, `nvim`, `tmux`, `ctags`)
   - Backup conflicting files with a `.bak.<timestamp>` suffix
   - Install Zinit if `zsh` is in the package list

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
| `--no-install`   | Skip installing dependencies |
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
transport:

- X11 forwarding when `$DISPLAY` is available on the remote host
- OSC 52 when no display server is forwarded but the client terminal supports it

### What works

- `tmux` copy-mode yanks (`y`, mouse selection)
- `clip`
- `xclip` and `xsel` copy-style usage on the remote host
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

### Typical usage on the remote host

```bash
printf 'hello\n' | clip
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

## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE) for details.

This is my personal project. It is created and maintained in my personal capacity, and has no relation to my employer's business or confidential information.
