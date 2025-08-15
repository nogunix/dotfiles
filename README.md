# dotfiles

A personal dotfiles repository managed with [GNU Stow](https://www.gnu.org/software/stow/).
Includes automatic setup for:

- Zsh (`.zshrc`) with [Zinit](https://github.com/zdharma-continuum/zinit) plugin manager
- Neovim (`init.lua` and other configs)
- Tmux (`tmux.conf`) with [TPM](https://github.com/tmux-plugins/tpm) plugin manager

## Requirements

- Git
- GNU Stow
- Curl
- Optional: Zsh, Tmux, Neovim

The `bootstrap.sh` script will check for these and attempt to install missing packages using your system package manager (`dnf`, `apt-get`, or `pacman`).

## Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/<your-username>/dotfiles.git ~/dotfiles
   cd ~/dotfiles
   ```

2. **Run the bootstrap script**
   ```bash
   chmod +x bootstrap.sh
   ./bootstrap.sh
   ```
   This will:
   - Install required packages
   - Stow the default packages (`zsh`, `nvim`, `tmux`)
   - Backup conflicting files with a `.bak.<timestamp>` suffix
   - Install TPM if `tmux` is in the package list
   - Install Zinit if `zsh` is in the package list

3. **Reload configurations**
   - Zsh: `exec zsh` or restart your terminal
   - Tmux: Press <kbd>prefix</kbd> + <kbd>I</kbd> (capital i) to install plugins
   - Neovim: Launch `nvim` to verify plugins and configs

## Usage

```bash
./bootstrap.sh [options]
```

### Options

| Option          | Description |
|-----------------|-------------|
| `-p "pkg1 pkg2"` | Specify stow packages (default: `zsh nvim tmux`) |
| `-a`             | Use `--adopt` to move existing files into the repo |
| `-n`             | Dry run (show what would happen) |
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