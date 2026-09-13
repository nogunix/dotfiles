#!/usr/bin/env bash
# Run the Bats suite under kcov and write a Codecov-compatible report.
#
# The interesting code here runs as subprocesses of the tests — bootstrap.sh
# and the clipboard wrappers are executed, not sourced — and kcov follows those
# forks, so the numbers reflect the scripts rather than the test harness.
#
# Usage: tests/coverage.sh [output-dir]   (default: <repo>/coverage)

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
out_dir="${1:-$repo_root/coverage}"

command -v kcov >/dev/null || {
  printf 'tests/coverage.sh: kcov is not installed\n' >&2
  printf '  Fedora: dnf install kcov\n' >&2
  printf '  macOS:  not packaged; run this on Linux\n' >&2
  exit 127
}
command -v bats >/dev/null || {
  printf 'tests/coverage.sh: bats is not installed\n' >&2
  exit 127
}

rm -rf "$out_dir"
mkdir -p "$out_dir"

# The suite itself is excluded: what matters is how much of the shipped
# scripts the tests reach, not how much of the tests ran.
kcov \
  --include-path="$repo_root" \
  --exclude-path="$repo_root/tests,$repo_root/.git,$out_dir" \
  "$out_dir" \
  bats "$repo_root/tests"

report="$(find "$out_dir" -name coverage.json -print | head -n 1)"
[ -n "$report" ] || {
  printf 'tests/coverage.sh: kcov produced no coverage.json\n' >&2
  exit 1
}

# kcov buries its reports under a per-run directory name. Publish the Cobertura
# file at a fixed path so CI can point at it without globbing.
cobertura="$(dirname -- "$report")/cobertura.xml"
if [ -f "$cobertura" ]; then
  cp -- "$cobertura" "$out_dir/cobertura.xml"
else
  printf 'tests/coverage.sh: kcov produced no cobertura.xml\n' >&2
  exit 1
fi

printf '\n==> coverage (%s)\n' "${report#"$out_dir"/}"
awk '
  match($0, /"file" *: *"[^"]*"/) {
    f = substr($0, RSTART, RLENGTH); gsub(/.*: *"|"$/, "", f)
  }
  match($0, /"percent_covered" *: *"?[0-9.]+/) {
    p = substr($0, RSTART, RLENGTH); gsub(/.*: *"?/, "", p)
    if (f != "") { printf "  %6s%%  %s\n", p, f; f = "" }
    else total = p
  }
  END { printf "\n  total: %s%%\n", total }
' "$report" | sed "s|$repo_root/||"
