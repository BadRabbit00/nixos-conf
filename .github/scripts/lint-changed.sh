#!/usr/bin/env bash
# Run statix + deadnix on .nix files changed against BASE_SHA and fail only on
# NEW findings: a changed file fails when a tool reports more findings than on
# the base version of that file, or when a new file has any finding.
# The repository as a whole is not lint-clean, so existing findings are only
# printed (informational). Requires: statix, deadnix, jq, git.
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
printf 'linting %d file(s) against base %s:\n' "${#files[@]}" "${base:0:12}"
printf '  %s\n' "${files[@]}"

root="$(git rev-parse --show-toplevel)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# count_statix <file>: number of statix diagnostics (0 if none).
count_statix() {
  { statix check --config "$root" --format json "$1" 2>/dev/null || true; } |
    jq -s '[.[].report[]?.diagnostics | length] | add // 0'
}
# count_deadnix <file>: number of deadnix results (0 if none).
count_deadnix() {
  { deadnix --output-format json "$1" 2>/dev/null || true; } |
    jq -s '[.[].results | length] | add // 0'
}

rc=0
for f in "${files[@]}"; do
  echo
  echo "=== $f"
  # Informational: full human-readable findings of the head version, no colour.
  statix check --config "$root" "$f" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true
  deadnix "$f" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' || true

  declare -A head_n=() base_n=()
  head_n[statix]="$(count_statix "$f")"
  head_n[deadnix]="$(count_deadnix "$f")"

  base_file="$tmp/base/$f"
  if git cat-file -e "$base:$f" 2>/dev/null; then
    mkdir -p "$(dirname "$base_file")"
    git show "$base:$f" >"$base_file"
    base_n[statix]="$(count_statix "$base_file")"
    base_n[deadnix]="$(count_deadnix "$base_file")"
  else
    base_n[statix]=0
    base_n[deadnix]=0
    echo "(new file: base counts are 0)"
  fi

  for tool in statix deadnix; do
    if [ "${head_n[$tool]}" -gt "${base_n[$tool]}" ]; then
      echo "FAIL $f $tool: base ${base_n[$tool]} -> head ${head_n[$tool]} (new findings)"
      rc=1
    else
      echo "ok   $f $tool: base ${base_n[$tool]} -> head ${head_n[$tool]}"
    fi
  done
done
exit "$rc"
