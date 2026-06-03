---
description: Drift scan over `.claude/**/*.md` and `CLAUDE.md` — finds dead markdown links, orphan references, and stale frontmatter. Optionally proposes repairs.
argument-hint: ["fix" to propose repairs; omit for report-only]
allowed-tools: Bash, Read, Edit
---

<!-- BLUEPRINT — adapt per-repo. Strip this banner after substitution. -->

Run `bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/<repo>_skills_drift.sh"`.

If `$ARGUMENTS` is `fix`: for each finding, propose a concrete repair
(file + line + replacement) and ask before applying. Do not batch-apply.

If no arguments: report-only.
