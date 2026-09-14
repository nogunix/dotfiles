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
- `tmux/.config/tmux/`: `tmux.conf` (behavior, clipboard integration and the
  status bar) plus the two helpers it calls, `os-label.sh` and `git-branch.sh`.
- `tests/`: Bats coverage for bootstrap, stow, clipboard, tmux and config
  portability, plus `run.sh` (suite + skip report), `lint.sh` (shellcheck) and
  `coverage.sh` (kcov).

## Change Rules

- Keep OS- or environment-specific logic inside `bootstrap.sh` or wrapper scripts.
- Do not bypass the clipboard wrappers when changing clipboard behavior.
  The backend decision belongs in `zsh/.local/bin/clipboard-backend`.
- Prefer relative or `$HOME`-based paths over hardcoded absolute paths when practical.
- Keep shell scripts POSIX/Bash-friendly and compatible with `shellcheck`.
- Update tests when behavior changes. Do not change behavior silently.

## Codex Specifics

- **Research First**: Before modifying `bootstrap.sh` or core clipboard scripts, read the existing logic carefully. The bootstrap script handles multiple package managers (`dnf`, `apt-get`, `pacman`, `brew`).
- **Surgical Edits**: Make narrow changes that preserve user-managed files and existing stow behavior.
- **Atomic Operations**: When adding a feature that spans multiple files (for example, a new stow package), keep `bootstrap.sh`, docs, and tests in sync in the same turn.
- **Tooling**: Prefer shell commands for validation (`bats`, `shellcheck`, `tests/nvim-headless.sh`) over manual inspection alone.

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
- Backend priority belongs in `zsh/.local/bin/clipboard-backend` and should remain `wl-copy` -> `xclip`/`xsel` -> `osc52` for SSH/tmux -> `pbcopy` on local macOS -> final `osc52` fallback unless intentionally changed.
- `xclip` and `xsel` wrappers should preserve copy-style compatibility where possible.
- OSC 52 is copy-only here; do not pretend remote clipboard readback is portable.
- tmux clipboard integration should continue to work over SSH sessions.

## tmux Status Bar Invariants

- The status bar is rendered by tmux's own format strings. There is no plugin
  and no plugin manager; do not reintroduce TPM or tmux-powerline to add a
  segment.
- `tmux.conf` must contain exactly one `#(...)`, the git chip. Every other
  `#(...)` is a process per client per `status-interval`, which is what made
  the old setup cost ~212 ms every 5 s.
- Anything that cannot change while the server is up (the OS label, say)
  belongs in a user option resolved once by `run-shell` at config load, not in
  a format that re-runs on every redraw.
- Colours live in the `%hidden` palette at the top of the status section.
  `git-branch.sh` emits `@git_pre` / `@git_post` / `@git_none` references
  rather than colours of its own, so keep the two in sync.
- tmux re-expands the output of `#(...)` as a format, so anything interpolated
  from the outside world (a branch name) must have its `#` escaped as `##`.

## Validation

Run these after any change:

```bash
# Run all tests, with a summary of which tests skipped and why
tests/run.sh

# Individual test files if scope is narrow
bats tests/bootstrap.bats            # bootstrap.sh argv, with stow stubbed
bats tests/bootstrap-packages.bats   # dnf/apt-get/pacman/brew dispatch, stubbed
bats tests/stow-integration.bats     # bootstrap.sh against the real stow
bats tests/clipboard-backend.bats    # which backend gets chosen
bats tests/clipboard-wrappers.bats   # what each wrapper does with it
bats tests/clipboard-integration.bats
bats tests/clipboard-macos.bats      # macOS only; skips elsewhere
bats tests/osc52.bats
bats tests/config-portability.bats   # zsh -n / bash -n / lua / hardcoded $HOME
bats tests/tmux-config.bats

# Lint every shell script, including the extensionless wrappers
tests/lint.sh

# Coverage (needs kcov; Fedora packages it, Ubuntu no longer does)
tests/coverage.sh

# Verify Neovim config and plugin startup headlessly
tests/nvim-headless.sh

# Optional: include :checkhealth output (may be noisier in restricted environments)
tests/nvim-headless.sh --health
```

Skips are the thing to read. Almost every suite here guards behaviour that only
exists when the tool is installed, so a machine without `zsh`, `nvim`, `tmux`,
`stow` or a clipboard goes green while testing very little. `tests/run.sh`
prints the skip list; `tests/run.sh --strict` turns any skip into a failure.

### CI

`.github/workflows/bats.yml` runs the suite on ubuntu-latest, on fedora-latest
and fedora-rawhide (container jobs — GitHub has no Fedora runner), and twice on
macos-latest: once with the system bash 3.2 and once with Homebrew bash first on
`PATH`. `.github/workflows/shellcheck.yml` runs `tests/lint.sh` on Ubuntu and
Fedora. A `coverage` job runs the suite under kcov in a Fedora container and
uploads the Cobertura report to Codecov; `codecov.yml` keeps both statuses
informational, since much of `bootstrap.sh` only runs against a real package
manager.

Two consequences worth remembering when writing tests:

- Container jobs run as **root**, so anything asserting that a permission bit is
  enforced must skip when `id -u` is 0.
- macOS has no `sha256sum`, no GNU `readlink -f` guarantee, and `/bin/bash` is
  3.2 — no `mapfile`, no `printf '\uHHHH'`, no associative arrays.
- Isolate a subprocess's environment with `env -u NAME ...`, never `env -i`.
  A cleared environment also drops what kcov uses to trace bash, so the run
  still passes but contributes nothing to coverage.

### Tests must not touch the working tree

`tests/stow-integration.bats` runs the real `stow`, so it copies `bootstrap.sh`
and the package under test into a temp dir and runs from there. Any new test
that stows, backs up, or writes files must do the same: a regression in
`bootstrap.sh` should fail a test, never rename a tracked file.

## Coding Standards

- **Shell**: Use `#!/usr/bin/env bash` for scripts requiring bashisms, or `#!/bin/sh` for pure POSIX. Always use `set -euo pipefail`.
- **Lua**: Follow standard Neovim Lua conventions. Use 2-space indentation.
- **Git**: Use descriptive commit messages. Propose a draft before committing.

## Documentation

- Put user-facing setup and usage in `README.md`.
- Put maintainer-facing constraints and editing guidance here.
- Keep `README.md` and `AGENTS.md` aligned when install flow, validation steps, or clipboard behavior changes.
- If adding a new managed package, update `bootstrap.sh`, docs, and tests as needed.
