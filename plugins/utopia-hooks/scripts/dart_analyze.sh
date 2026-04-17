#!/usr/bin/env bash
# dart_analyze.sh — thin wrapper around `dart analyze`
#
# Usage: dart_analyze.sh [<path>...]
#   Runs `dart analyze` scoped to the given paths (or CWD by default).
#   Returns:
#     0 if clean (no output)
#     1 if issues found (issues printed to stderr)
#     127 if `dart` is not on PATH

set -u

if ! command -v dart >/dev/null 2>&1; then
  exit 127
fi

# Walk up to find pubspec.yaml
start="${1:-$PWD}"
dir="$(cd "$(dirname -- "$start")" 2>/dev/null && pwd)" || dir="$PWD"
project_root=""
while [[ "$dir" != "/" && -n "$dir" ]]; do
  if [[ -f "$dir/pubspec.yaml" ]]; then
    project_root="$dir"
    break
  fi
  dir="$(dirname -- "$dir")"
done

[[ -z "$project_root" ]] && exit 0

cd "$project_root" || exit 0

if [[ $# -eq 0 ]]; then
  output="$(dart analyze 2>&1)"
else
  output="$(dart analyze "$@" 2>&1)"
fi
status=$?

if [[ $status -ne 0 ]]; then
  echo "$output" >&2
  exit 1
fi

exit 0
