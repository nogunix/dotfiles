#!/usr/bin/env bash
# Shellcheck every shell script in the repo.
#
# The scripts that matter most here — the clipboard wrappers in
# zsh/.local/bin — have no .sh extension, so a plain `shellcheck **/*.sh`
# misses them. Select by extension OR by shebang instead, and keep the list in
# one place so CI and local runs lint exactly the same files.
#
# Deliberately not linted: *.bats (shellcheck cannot parse @test) and
# zsh/.zshrc (zsh syntax; tests/config-portability.bats runs `zsh -n` on it).

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v shellcheck >/dev/null || {
  printf 'tests/lint.sh: shellcheck is not installed\n' >&2
  exit 127
}

# Avoid mapfile: it does not exist in the bash 3.2 that ships with macOS.
files=()
while IFS= read -r f; do
  case "$f" in
    *.sh) files+=("$f"); continue ;;
    *.bats) continue ;;
  esac
  case "$(head -n 1 "$f" 2>/dev/null)" in
    '#!'*bash*|'#!'*/sh|'#!'*env\ sh) files+=("$f") ;;
  esac
done < <(
  find "$repo_root" -name .git -prune -o -type f -print | sort
)

if [ ${#files[@]} -eq 0 ]; then
  printf 'tests/lint.sh: no shell scripts found\n' >&2
  exit 1
fi

printf '==> %s on %s files:\n' "$(shellcheck --version | sed -n 's/^version: /shellcheck /p')" "${#files[@]}"
for f in "${files[@]}"; do
  printf '  %s\n' "${f#"$repo_root"/}"
done
printf '\n'

shellcheck "${files[@]}"
printf 'shellcheck: clean\n'
