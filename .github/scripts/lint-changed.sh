#!/usr/bin/env bash
# Run statix + deadnix only on .nix files changed against BASE_SHA.
# The repository as a whole is not lint-clean, so untouched files are ignored.
set -euo pipefail

base="${BASE_SHA:-}"
if [ -z "$base" ] || [ "$base" = "0000000000000000000000000000000000000000" ]; then
  echo "no usable base commit; nothing to lint"
  exit 0
fi

mapfile -t files < <(git diff --name-only --diff-filter=d "$base"...HEAD -- '*.nix')
if [ "${#files[@]}" -eq 0 ]; then
  echo "no changed .nix files"
  exit 0
fi
printf 'linting %d file(s):\n' "${#files[@]}"
printf '  %s\n' "${files[@]}"

rc=0
for f in "${files[@]}"; do
  statix check "$f" || rc=1
done
deadnix --fail "${files[@]}" || rc=1
exit "$rc"
