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
  by the tmux status bar (see [Tmux](#tmux))

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

## Neovim

### LSP servers

Servers are enabled from the `servers` table at the top of
`nvim/.config/nvim/lua/plugins/mason.lua`, and start when a file is opened.
mason is only used to install them: it loads for `:Mason` and friends, or by
itself when a listed server is not installed yet, and otherwise never — it
costs ~20 ms to load. A server installed through `:Mason` therefore has to be
added to that table before it runs.

`lua_ls` indexes Neovim's own runtime only, not every plugin on the
runtimepath, which brings it up in ~1.4 s instead of ~3.7 s. The trade-off:
when editing this config, plugin modules (`require('lazy')` and so on) are not
type-checked.

### Files changed outside Neovim

A buffer whose file changes on disk (an AI agent or another editor working in
the same tree, a `git checkout`) reloads within about a second, even while
Neovim keeps focus, with a `Reloaded <file>` message. A buffer with unsaved
edits is never reloaded behind your back; the usual "file changed" prompt comes
when you next enter it or focus Neovim.

## Zsh

### Agent shells

Coding agents (Antigravity, Claude Code, ...) run commands through a terminal
and parse the output, so a shell they drive gets a plain setup: no zinit
plugins (autosuggestions redraws the line), `PAGER=cat` and `GIT_PAGER=cat`,
and `GIT_EDITOR=true`, so `git log` or a stray `git commit` never sits waiting
for a key nobody presses. A shell is treated this way when one of the variables
in `_zsh_agent_markers` near the top of `zsh/.zshrc` is set; your own shells,
in any terminal or editor, are unaffected.

`zsh/.zshenv` puts `~/.local/bin` and Homebrew on `PATH` for every zsh,
including the non-interactive ones an agent may run commands in, which never
read `.zprofile` or `.zshrc`. It only adds what is missing, so an existing
order is kept. It also sets `skip_global_compinit=1`: Debian and Ubuntu's
`/etc/zsh/zshrc` otherwise runs a second compinit before `.zshrc`, which can
stop at an "insecure directories" prompt. `EDITOR` and `VISUAL` are `nvim` when it is installed.

## Tmux

### Status bar: Nerd Font required

The status bar is rendered by tmux's own format strings — there is no plugin and
no plugin manager — and it **assumes a [Nerd Font](https://www.nerdfonts.com/)**
in the terminal that displays the session.

Glyphs in use:

| Glyph | Code point | Where |
|-------|------------|-------|
| `` `` | U+E0B0 / U+E0B2 | powerline separators between chips (`tmux.conf`) |
| `` | U+E0A0 | the git branch chip (`tmux.conf`) |
| `` | U+F0F3 | the bell chip (`tmux.conf`) |
| `` | U+F179 | the OS chip on macOS (`os-label.sh`) |
| `` | U+F17C | the OS chip on Linux (`os-label.sh`) |
| `` | U+F120 | the OS chip on BSD and anything else (`os-label.sh`) |

Without a Nerd Font the bar still works, but those six characters render as
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

Blank the four glyph variables near the top of the status section in
`tmux/.config/tmux/tmux.conf`:

```tmux
%hidden SEP_R=""
%hidden SEP_L=""
%hidden GIT_SYM=""
%hidden BELL_SYM=""
```

and drop the `glyph=` assignments in `tmux/.config/tmux/os-label.sh`. The chips
keep their colours; they just lose the pointed edges and the icons.

### Key bindings

The prefix is the default `C-b`.

| Key | What it does |
|-----|--------------|
| `prefix` + `F` | Focus mode: hide the status bar and zoom the current pane |
| `prefix` + `m` | Toggle mouse mode |
| `prefix` + `r` | Reload `~/.config/tmux/tmux.conf` |
| `y` (copy-mode) | Copy the selection through `clip` to the local clipboard |

Focus mode gives a long agent transcript the whole terminal, and `prefix` + `F`
again puts the chrome back. The zoom is conditional in both directions: a pane
you had already zoomed yourself stays zoomed when focus mode starts, and one you
unzoomed by hand is not re-zoomed when it ends.

`focus-events` is on, so applications in a pane are told when the terminal
gains or loses focus. Neovim uses this to fire `FocusGained` / `FocusLost`,
which lets `autoread` reload a file another tool changed while you were away.

A yellow chip appears after the session chip when a window other than the
current one rings the bell, listing those windows (`2!`) until you visit them:
a long build, or an AI agent in another window reporting it is done. The window
list is hidden, so this is where that shows.

`extended-keys` is on, so an application that asks for it can tell
`Shift`+`Enter` (a newline in most agent CLIs) from `Enter` (submit). The
outer terminal has to report modified keys to tmux too; that is enabled for
terminals whose `TERM` starts with `xterm`, which most modern ones do.

### Pane startup

New panes and windows start zsh as a **non-login** shell, so `~/.zprofile` (and
on macOS `/etc/zprofile`'s `path_helper`) runs only in the shell that started
the tmux server, not again in every pane. Panes inherit that server's
environment, so put PATH setup in `~/.zprofile` or `~/.zshenv` and start tmux
from a terminal as usual. A server launched some other way (launchd, systemd)
will not have it. `escape-time` is 10 ms, so Esc in Neovim is not held back.

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

### `~/.local/bin` is a real directory

Stow normally *folds* a directory it can own outright into a single symlink, so
`~/.local/bin` used to become a link to `zsh/.local/bin` — and every binary an
installer dropped there (Claude Code, uv, pipx, ...) ended up in the repo.
`bootstrap.sh` now always creates `~/.local/bin` as a real directory and links
the wrappers into it one by one. Other directories (`~/.config/nvim`, for one)
still fold, so a new file created there still lands in the repo.

On a machine stowed before this change, re-running `./bootstrap.sh` unfolds the
old symlink. Anything that had been installed through it is still sitting in
`zsh/.local/bin` as an untracked file; bootstrap lists those, and they should be
moved to `~/.local/bin` by hand.

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
