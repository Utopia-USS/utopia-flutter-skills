#!/usr/bin/env bash
# session_start.sh - SessionStart hook: deterministic skill activation.
#
# Detects utopia_cms (or a utopia_cms_* delegate package) in the project's
# pubspec(s), or an admin/cms/panel-named package, and on a hit prints a short
# context note instructing Claude to use the utopia-cms skill.
# Contract:
#   - stdout on exit 0 is appended to the session context
#   - silent exit 0 for non-CMS projects (zero noise outside the ecosystem)
# Compatible with macOS bash 3.2 (no mapfile, no assoc arrays).

set -u

root="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -d "$root" ]] || exit 0

# Shallow scan: root pubspec plus nested package pubspecs (melos monorepos).
# Depth-limited and build/platform dirs pruned, so it stays fast on big repos.
found=""
while IFS= read -r pubspec; do
  if grep -qE '^[[:space:]]*utopia_cms(_firebase|_supabase|_hasura|_graphql)?[[:space:]]*:' "$pubspec" 2>/dev/null; then
    found="$pubspec"
    break
  fi
  pkg_name="$(grep -E '^name:' "$pubspec" 2>/dev/null | head -1 | sed -E 's/^name:[[:space:]]*//; s/[[:space:]]*$//')"
  case "$pkg_name" in
    *admin*|*cms*|*panel*|*backoffice*|*back_office*|*management*)
      found="$pubspec"
      break
    ;;
  esac
done < <(find "$root" -maxdepth 3 -name pubspec.yaml \
  -not -path '*/build/*' -not -path '*/.dart_tool/*' -not -path '*/.symlinks/*' \
  -not -path '*/ios/*' -not -path '*/android/*' -not -path '*/macos/*' \
  -not -path '*/windows/*' -not -path '*/linux/*' -not -path '*/.git/*' \
  2>/dev/null | head -40)

[[ -z "$found" ]] && exit 0

cat <<'EOF'
This project contains an admin / CMS package (utopia_cms dependency or
admin/cms/panel-named package). Admin tables, create/edit/delete flows, and
per-row actions follow the CmsTablePage + CmsDelegate pattern from the
utopia-cms skill.

Before writing or modifying any admin screen, table, delegate, entry list,
filter, or custom action, invoke the utopia-cms skill (Skill tool) and follow
the matching reference file. A PostToolUse hook enforces the core conventions
on every Dart edit - code written without the skill usually fails it.
EOF
exit 0
