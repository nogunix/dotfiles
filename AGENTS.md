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
- `nvim/.config/nvim/`: Neovim configuration (Lazy.nvim based).
- `tmux/.config/tmux/tmux.conf`: tmux behavior and clipboard integration.
- `tests/`: Bats coverage for bootstrap and clipboard behavior.

## Change Rules

- Keep OS- or environment-specific logic inside `bootstrap.sh` or wrapper scripts.
- Do not bypass the clipboard wrappers when changing clipboard behavior.
  The backend decision belongs in `zsh/.local/bin/clipboard-backend`.
- Prefer relative or `$HOME`-based paths over hardcoded absolute paths when practical.
- Keep shell scripts POSIX/Bash-friendly and compatible with `shellcheck`.
- Update tests when behavior changes. Do not change behavior silently.

## Gemini CLI Specifics

- **Research First**: Before modifying `bootstrap.sh` or core clipboard scripts, read the existing logic carefully. The bootstrap script handles multiple package managers (`dnf`, `apt`, `pacman`).
- **Surgical Edits**: Use `replace` for configuration changes to avoid overwriting user customizations if they haven't been stowed yet.
- **Atomic Operations**: When adding a new feature that spans multiple files (e.g., a new stow package), use a single turn or a `generalist` sub-agent to ensure consistency.
- **Tooling**: Prefer using `run_shell_command` for validation (bats, shellcheck) over manual inspection.

## Common Procedures

### Adding a New Stow Package
1. Create the directory structure: `mkdir -p <pkgname>/.config/<pkgname>`
2. Add the files to the new directory.
3. Update `DEFAULT_STOW_PKGS` in `bootstrap.sh` if it should be installed by default.
4. Add a test case in `tests/bootstrap.bats` to ensure it stows correctly.

### Modifying Neovim Config
- Plugins are managed via `lazy.nvim` in `nvim/.config/nvim/init.lua`.
- Large plugin configurations should be moved to `nvim/.config/nvim/lua/plugins/`.
- Ensure `lua_ls` diagnostics are clean before finishing.

## Clipboard Invariants

- `clip` should remain the stable user-facing copy command.
- `clipboard-copy` should delegate to the selected backend.
- `xclip` and `xsel` wrappers should preserve copy-style compatibility where possible.
- OSC 52 is copy-only here; do not pretend remote clipboard readback is portable.
- tmux clipboard integration should continue to work over SSH sessions.

## Validation

Run these after any change:

```bash
# Run all tests
bats tests/

# Individual test files if scope is narrow
bats tests/bootstrap.bats
bats tests/clipboard-backend.bats

# Verify Neovim config and plugin startup headlessly
tests/nvim-headless.sh

# Optional: include :checkhealth output (may be noisier in restricted environments)
tests/nvim-headless.sh --health

# Lint shell scripts
shellcheck bootstrap.sh zsh/.local/bin/*
shellcheck tests/nvim-headless.sh
```

## Coding Standards

- **Shell**: Use `#!/usr/bin/env bash` for scripts requiring bashisms, or `#!/bin/sh` for pure POSIX. Always use `set -euo pipefail`.
- **Lua**: Follow standard Neovim Lua conventions. Use 2-space indentation.
- **Git**: Use descriptive commit messages. Propose a draft before committing.

## Documentation

- Put user-facing setup and usage in `README.md`.
- Put maintainer-facing constraints and editing guidance here.
- If adding a new managed package, update `bootstrap.sh`, docs, and tests as needed.
