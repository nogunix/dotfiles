# dotfiles

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Tests](https://github.com/nogunix/dotfiles/actions/workflows/bats.yml/badge.svg?branch=main)](https://github.com/nogunix/dotfiles/actions/workflows/bats.yml)
[![Lint](https://github.com/nogunix/dotfiles/actions/workflows/shellcheck.yml/badge.svg?branch=main)](https://github.com/nogunix/dotfiles/actions/workflows/shellcheck.yml)
[![codecov](https://codecov.io/gh/nogunix/dotfiles/branch/main/graph/badge.svg)](https://codecov.io/gh/nogunix/dotfiles)


A personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/).
It is structured as an operational setup repo: `bootstrap.sh` installs prerequisites,
stows packages into `$HOME`, and backs up conflicting files before linking them.

Includes managed configuration for:

- Zsh (`.zshrc`) with [Zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Neovim (`init.lua` and other configs)
- Tmux (`tmux.conf`), with a status bar rendered by tmux itself — no plugin
  manager, but it does need a Nerd Font
- Universal Ctags (`ctags`)
- Clipboard wrappers that prefer Wayland/X11/macOS tools locally and OSC 52 for remote sessions

## Requirements

- Git
- GNU Stow
- Curl
- Optional: Zsh, Tmux, Neovim
- Optional: Universal Ctags when the `ctags` stow package is selected
- Optional: a [Nerd Font](https://www.nerdfonts.com/) in the terminal, required
  by the tmux status bar (see [Tmux Status Bar](#tmux-status-bar))

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
| `--no-install`   | Skip every install step: base packages, ctags, Zinit |
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

## Testing

```bash
tests/run.sh          # the whole Bats suite, with a summary of what skipped
tests/lint.sh         # shellcheck every shell script, incl. the extensionless ones
tests/run.sh --strict # additionally fail if any test skipped
tests/coverage.sh     # the suite under kcov, with a per-file coverage report
tests/nvim-headless.sh  # install/load the Neovim plugins headlessly
```

Most of the suite guards behaviour that only exists when the real tools are
installed, so `tests/run.sh` prints which tests skipped and why — a job missing
`zsh`, `nvim`, `tmux`, `stow` or a clipboard otherwise passes while testing
almost nothing.

CI runs it on:

| Job | What it adds |
|-----|--------------|
| `ubuntu-latest` | apt tool versions, X11 clipboard under Xvfb |
| `fedora-latest` / `fedora-rawhide` | dnf tool versions, in the official container (rawhide is advisory) |
| `macos-latest` (system bash) | the BSD userland and the bash 3.2 that ships with macOS |
| `macos-latest` (Homebrew bash) | the same host with bash 5 first on `PATH` |
| `nvim plugins` (Linux + macOS) | a real lazy.nvim bootstrap and headless load |
| `coverage` (Fedora) | the suite under kcov, uploaded to Codecov |

Linting runs on Ubuntu and Fedora, because the two ship different shellcheck
versions.

Coverage measures the shipped scripts, not the tests. kcov follows forks, so
`bootstrap.sh` and the clipboard wrappers are counted even though the suite
runs them as subprocesses. It is reported as a signal, never as a gate.

What is left uncovered is deliberate: the `pbcopy` arm of `clipboard-copy`
needs a real macOS pasteboard (the macOS jobs exercise it, but coverage only
runs on Fedora), and two `return 1` arms in `bootstrap.sh` are unreachable
defensive code.

## Tmux Status Bar

The status bar is rendered by tmux's own format strings — there is no plugin and
no plugin manager — and it **assumes a [Nerd Font](https://www.nerdfonts.com/)**
in the terminal that displays the session.

Glyphs in use:

| Glyph | Code point | Where |
|-------|------------|-------|
| `` `` | U+E0B0 / U+E0B2 | powerline separators between chips (`tmux.conf`) |
| `` | U+E0A0 | the git branch chip (`tmux.conf`) |
| `` | U+F179 | the OS chip on macOS (`os-label.sh`) |
| `` | U+F17C | the OS chip on Linux (`os-label.sh`) |
| `` | U+F120 | the OS chip on BSD and anything else (`os-label.sh`) |

Without a Nerd Font the bar still works, but those five characters render as
tofu boxes (`□`).

### Installing one

Any patched font works; the examples use Fira Code.

```bash
# macOS
brew install --cask font-fira-code-nerd-font

# Arch
sudo pacman -S ttf-firacode-nerd

# Fedora / Debian / Ubuntu — check for a packaged build first,
# the names are not stable across releases
dnf search nerd-fonts
apt-cache search nerd | grep -i font
```

If the distro has no package, install into the user font directory:

```bash
mkdir -p ~/.local/share/fonts
curl -fsSLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip -d ~/.local/share/fonts FiraCode.zip
fc-cache -f
```

Then select the patched font in the terminal's profile. Over SSH the font is a
property of the *local* terminal, so install it on the machine you are sitting
at, not on the remote host.

### Running without one

Blank the three glyph variables near the top of the status section in
`tmux/.config/tmux/tmux.conf`:

```tmux
%hidden SEP_R=""
%hidden SEP_L=""
%hidden GIT_SYM=""
```

and drop the `glyph=` assignments in `tmux/.config/tmux/os-label.sh`. The chips
keep their colours; they just lose the pointed edges and the icons.

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
