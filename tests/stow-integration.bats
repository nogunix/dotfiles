#!/usr/bin/env bats

# End-to-end coverage for bootstrap.sh against the REAL GNU stow binary.
#
# bootstrap.bats stubs stow out and only asserts the argv, so nothing there
# exercises what actually differs per platform: symlink creation, stow's
# directory folding, the find/readlink/mv conflict backup, and unstow. Those
# are also the parts that behave differently between GNU coreutils and the BSD
# tools on macOS.
#
# Everything runs against a throwaway copy of the repo, so a regression here
# can never rename a file in the real working tree.

setup() {
  command -v stow >/dev/null || skip "stow not installed"

  SRC_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  # Resolve the temp dir physically: on macOS $TMPDIR is under /var, which is a
  # symlink to /private/var, so the paths these tests compare against pwd -P
  # output would never match otherwise.
  TEST_TMP="$(cd -- "$(mktemp -d "${TMPDIR:-/tmp}/stow-int.XXXXXX")" && pwd -P)"

  # Minimal standalone copy: bootstrap.sh plus one stow package. ctags is
  # enough to exercise linking, folding, backup and unstow, and keeping the
  # copy small keeps each test cheap.
  REPO_ROOT="$TEST_TMP/repo"
  mkdir -p "$REPO_ROOT"
  cp "$SRC_ROOT/bootstrap.sh" "$REPO_ROOT/"
  cp -R "$SRC_ROOT/ctags" "$REPO_ROOT/"

  export HOME="$TEST_TMP/home"
  mkdir -p "$HOME"

  PKG_FILE="$REPO_ROOT/ctags/.ctags.d/universal.ctags"
  STOWED="$HOME/.ctags.d/universal.ctags"
  PKG_SUM="$(checksum "$PKG_FILE")"
}

teardown() {
  [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

checksum() {
  if command -v sha256sum >/dev/null; then
    sha256sum <"$1" | cut -d' ' -f1
  else
    shasum -a 256 <"$1" | cut -d' ' -f1   # macOS has no sha256sum
  fi
}

# Run from inside the copy: a bootstrap.sh that forgets to pass -d to stow
# would otherwise fall back to the cwd and stow out of the real working tree.
bootstrap() {
  run env HOME="$HOME" bash -c \
    "cd '$REPO_ROOT' && /bin/bash ./bootstrap.sh --no-install $*"
}

# Resolve a path physically without readlink -f, which older BSD/macOS lacks:
# resolve the parent with pwd -P, then follow a symlinked final component.
resolved_path() {
  local dir base target depth=0
  dir="$(cd -- "$(dirname -- "$1")" && pwd -P)"
  base="$(basename -- "$1")"

  while [ -L "$dir/$base" ] && [ "$depth" -lt 16 ]; do
    target="$(readlink -- "$dir/$base")"
    case "$target" in
      /*) : ;;
      *)  target="$dir/$target" ;;
    esac
    dir="$(cd -- "$(dirname -- "$target")" && pwd -P)"
    base="$(basename -- "$target")"
    depth=$((depth + 1))
  done

  printf '%s/%s\n' "$dir" "$base"
}

# stow folds a whole directory into one symlink when nothing conflicts, so
# assert on where the file lands rather than on which node is the symlink.
assert_stowed() {
  [ -f "$1" ]
  [[ "$(resolved_path "$1")" == "$REPO_ROOT"/* ]]
}

# The package directory must come out of any bootstrap run byte-identical.
assert_package_intact() {
  [ -f "$PKG_FILE" ]
  [ "$(checksum "$PKG_FILE")" = "$PKG_SUM" ]
  run bash -c "ls -A '$REPO_ROOT/ctags/.ctags.d'"
  [ "$output" = "universal.ctags" ]
}

@test "stows a file that resolves back into the repo" {
  bootstrap -p "ctags"
  [ "$status" -eq 0 ]

  assert_stowed "$STOWED"
  [ "$(checksum "$STOWED")" = "$PKG_SUM" ]
}

@test "backs up a conflicting regular file before linking" {
  mkdir -p "$HOME/.ctags.d"
  printf 'user-managed\n' >"$HOME/.ctags.d/universal.ctags"

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]

  backup="$(echo "$HOME"/.ctags.d/universal.ctags.bak.*)"
  [ -f "$backup" ]
  [ "$(cat "$backup")" = "user-managed" ]
  assert_stowed "$STOWED"
}

@test "re-stowing is idempotent and never touches the repo" {
  bootstrap -p "ctags"
  [ "$status" -eq 0 ]

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]

  assert_stowed "$STOWED"
  # Regression guard: with the package folded into a single directory symlink,
  # the conflict backup used to resolve through it and rename the repo's own
  # file to universal.ctags.bak.<ts>, compounding on every run.
  assert_package_intact
  run bash -c "ls -A '$HOME/.ctags.d'"
  [ "$output" = "universal.ctags" ]
}

@test "re-stowing over a per-file symlink makes no backup either" {
  # With a conflict in the way, stow links each file individually instead of
  # folding the directory. The second run then meets its own symlink, whose
  # parent is a real directory in $HOME — a different code path from the folded
  # case above, and the one the readlink check exists for.
  mkdir -p "$HOME/.ctags.d"
  printf 'user-managed\n' >"$HOME/.ctags.d/universal.ctags"

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [ -L "$STOWED" ]

  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  [ -L "$STOWED" ]
  assert_stowed "$STOWED"
  assert_package_intact

  # Exactly one backup, from the first run: the symlink must not be re-backed.
  run bash -c "ls -A '$HOME'/.ctags.d/ | grep -c '\.bak\.'"
  [ "$output" -eq 1 ]
}

@test "works when invoked from an unrelated working directory" {
  # stow defaults its stow dir to the cwd, so bootstrap.sh has to pass -d.
  run env HOME="$HOME" bash -c "cd / && /bin/bash '$REPO_ROOT/bootstrap.sh' --no-install -p ctags"
  [ "$status" -eq 0 ]

  assert_stowed "$STOWED"
  assert_package_intact
}

@test "dry-run creates no links" {
  bootstrap -p "ctags" -n
  [ "$status" -eq 0 ]
  [ ! -e "$STOWED" ]
  assert_package_intact
}

@test "unstow removes what it created" {
  bootstrap -p "ctags"
  [ "$status" -eq 0 ]
  assert_stowed "$STOWED"

  bootstrap -u "ctags"
  [ "$status" -eq 0 ]
  [ ! -e "$STOWED" ]
  assert_package_intact
}
