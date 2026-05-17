#!/usr/bin/env bash
# BLUEPRINT — adapt per-repo. Strip this banner after substitution.
# <repo>_skills_drift.sh — Drift scan over .claude/**/*.md and CLAUDE.md.
#
# Finds dead markdown links inside the .claude/ layer. Writes a
# report to stderr; exit 0 = clean, exit 1 = drift found.

set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root" || exit 0

errors=0

scan_file() {
  local file="$1"
  # Extract markdown links of the form [text](path)
  while IFS= read -r link; do
    # Resolve relative to the file's directory
    local target_dir
    target_dir="$(dirname "$file")"
    local target="$target_dir/$link"

    # Skip URLs and anchors-only
    case "$link" in
      http*|"#"*) continue ;;
    esac

    # Strip any #anchor
    target="${target%%#*}"

    if [[ ! -e "$target" ]]; then
      echo "  $file: dead link → $link" >&2
      errors=$((errors + 1))
    fi
  done < <(grep -oE '\]\([^)]+\)' "$file" | sed -E 's/^\]\(([^)]+)\)$/\1/')
}

# Scan CLAUDE.md and .claude/**/*.md
[[ -f "CLAUDE.md" ]] && scan_file "CLAUDE.md"
while IFS= read -r f; do
  scan_file "$f"
done < <(find .claude -type f -name '*.md' 2>/dev/null)

if [[ $errors -gt 0 ]]; then
  echo "" >&2
  echo "<repo>_skills_drift: $errors dead link(s) found" >&2
  exit 1
fi

exit 0
