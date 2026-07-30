#!/usr/bin/env bats

# Exercises _zsh_prune_broken_completions from zsh/.zshrc, which removes the
# dangling completion symlinks zinit leaves behind after a plugin update.

setup() {
  command -v zsh >/dev/null || skip "zsh not installed"

  TMPDIR="$(mktemp -d)"
  FPATH_DIR="$TMPDIR/completions"
  mkdir -p "$FPATH_DIR" "$TMPDIR/src"

  # The function is defined inside .zshrc, which cannot be sourced here (it
  # bootstraps zinit), so pull just that function out of the real file.
  awk '/^_zsh_prune_broken_completions\(\) \{/,/^\}/' \
    "$BATS_TEST_DIRNAME/../zsh/.zshrc" >"$TMPDIR/prune.zsh"
  [ -s "$TMPDIR/prune.zsh" ]
}

teardown() {
  chmod u+w "$FPATH_DIR" 2>/dev/null || true
  rm -rf "$TMPDIR"
}

# Runs the function against $FPATH_DIR and reports its exit status, which is 0
# only when something was actually removed.
run_prune() {
  run zsh -f -c "
    source '$TMPDIR/prune.zsh'
    fpath=( '$FPATH_DIR' )
    _zsh_prune_broken_completions
    print -r -- \"rc=\$?\"
  "
}

@test "removes a dangling completion symlink" {
  ln -s "$TMPDIR/src/_gone" "$FPATH_DIR/_gone"

  run_prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=0"* ]]
  [ ! -L "$FPATH_DIR/_gone" ]
}

@test "keeps completions whose target exists" {
  touch "$TMPDIR/src/_alive"
  ln -s "$TMPDIR/src/_alive" "$FPATH_DIR/_alive"
  touch "$FPATH_DIR/_plain"

  run_prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=1"* ]]
  [ -L "$FPATH_DIR/_alive" ]
  [ -f "$FPATH_DIR/_plain" ]
}

@test "removes only the broken link, not the whole directory" {
  touch "$TMPDIR/src/_alive"
  ln -s "$TMPDIR/src/_alive" "$FPATH_DIR/_alive"
  ln -s "$TMPDIR/src/_gone" "$FPATH_DIR/_gone"

  run_prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=0"* ]]
  [ ! -L "$FPATH_DIR/_gone" ]
  [ -L "$FPATH_DIR/_alive" ]
}

@test "leaves broken links in non-writable directories alone" {
  ln -s "$TMPDIR/src/_gone" "$FPATH_DIR/_gone"
  chmod u-w "$FPATH_DIR"

  run_prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=1"* ]]
  [ -L "$FPATH_DIR/_gone" ]
}

@test "ignores files that are not completions" {
  ln -s "$TMPDIR/src/notacomp" "$FPATH_DIR/notacomp"

  run_prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"rc=1"* ]]
  [ -L "$FPATH_DIR/notacomp" ]
}
