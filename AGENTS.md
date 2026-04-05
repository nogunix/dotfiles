# AGENTS.md

This repository manages a personal shell/editor environment with GNU Stow.
Treat it as an operational repo, not just a collection of config files.

## Purpose

- Keep the setup reproducible across machines with `bootstrap.sh` and Stow.
- Prefer small, portable shell utilities over machine-specific one-offs.
- Preserve remote clipboard behavior across local, SSH, tmux, Wayland, and X11 sessions.

## Repo Shape

- `bootstrap.sh`: entrypoint for install, stow, unstow, backup, and optional package installation.
- `zsh/.local/bin/`: compatibility wrappers and helper commands.
- `zsh/.zshrc`: interactive shell behavior and plugin loading.
- `nvim/.config/nvim/`: Neovim configuration.
- `tmux/.config/tmux/tmux.conf`: tmux behavior and clipboard integration.
- `tests/`: Bats coverage for bootstrap and clipboard behavior.

## Change Rules

- Keep OS- or environment-specific logic inside `bootstrap.sh` or wrapper scripts.
- Do not bypass the clipboard wrappers when changing clipboard behavior.
  The backend decision belongs in `zsh/.local/bin/clipboard-backend`.
- Prefer relative or `$HOME`-based paths over hardcoded absolute paths when practical.
- Keep shell scripts POSIX/Bash-friendly and compatible with `shellcheck`.
- Update tests when behavior changes. Do not change behavior silently.

## Clipboard Invariants

- `clip` should remain the stable user-facing copy command.
- `clipboard-copy` should delegate to the selected backend.
- `xclip` and `xsel` wrappers should preserve copy-style compatibility where possible.
- OSC 52 is copy-only here; do not pretend remote clipboard readback is portable.
- tmux clipboard integration should continue to work over SSH sessions.

## Validation

Run these after meaningful changes:

```bash
bats tests
```

If shell scripts changed, also run `shellcheck` if available.

## Documentation

- Put user-facing setup and usage in `README.md`.
- Put maintainer-facing constraints and editing guidance here.
- If adding a new managed package, update `bootstrap.sh`, docs, and tests as needed.
