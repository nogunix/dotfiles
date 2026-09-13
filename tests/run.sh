#!/usr/bin/env bash
# Run the bats suite and summarise the result, including which tests skipped.
#
# Skips are the thing to watch in CI: most of this suite guards behaviour that
# only exists when zsh/nvim/tmux/stow/a clipboard are actually installed, so a
# job missing a dependency goes green while testing almost nothing. Printing
# the skip list (and mirroring it into the GitHub step summary) keeps that
# visible instead of silent.
#
# Usage: tests/run.sh [--strict] [bats args...]
#   --strict  exit non-zero if any test skipped

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
strict=0
if [[ "${1:-}" == "--strict" ]]; then
  strict=1
  shift
fi

command -v bats >/dev/null || {
  printf 'tests/run.sh: bats is not installed\n' >&2
  exit 127
}

tap="$(mktemp "${TMPDIR:-/tmp}/bats-tap.XXXXXX")"
trap 'rm -f "$tap"' EXIT

printf '==> bats %s on %s (%s)\n\n' \
  "$(bats --version)" "$(uname -s)" "$(uname -m)"

rc=0
bats --tap "$@" "$repo_root/tests" | tee "$tap" || rc=$?

total=$(grep -c '^\(ok\|not ok\) ' "$tap" || true)
failed=$(grep -c '^not ok ' "$tap" || true)
skipped=$(grep -c '^ok .*# skip' "$tap" || true)
passed=$(( total - failed - skipped ))

printf '\n==> %s: %s tests, %s passed, %s failed, %s skipped\n' \
  "$(uname -s)" "$total" "$passed" "$failed" "$skipped"

if (( skipped > 0 )); then
  printf '\nSkipped:\n'
  sed -n 's/^ok [0-9]* \(.*\) # skip \(.*\)$/  - \1 — \2/p' "$tap"
  sed -n 's/^ok [0-9]* \(.*\) # skip$/  - \1/p' "$tap"
fi

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '### %s — %s\n\n' "${MATRIX_LABEL:-$(uname -s)}" "$(uname -m)"
    printf '%s tests · **%s passed** · %s failed · %s skipped\n' \
      "$total" "$passed" "$failed" "$skipped"
    if (( skipped > 0 )); then
      printf '\n<details><summary>Skipped tests</summary>\n\n'
      # shellcheck disable=SC2016  # the backticks are markdown, not a subshell
      sed -n 's/^ok [0-9]* \(.*\) # skip \(.*\)$/- `\1` — \2/p' "$tap"
      # shellcheck disable=SC2016  # the backticks are markdown, not a subshell
      sed -n 's/^ok [0-9]* \(.*\) # skip$/- `\1`/p' "$tap"
      printf '\n</details>\n'
    fi
    printf '\n'
  } >>"$GITHUB_STEP_SUMMARY"
fi

if (( strict )) && (( skipped > 0 )); then
  printf '\ntests/run.sh: --strict given and %s test(s) skipped\n' "$skipped" >&2
  exit 1
fi

exit "$rc"
