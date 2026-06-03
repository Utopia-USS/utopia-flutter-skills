---
description: Orchestrate a focused implementation with the review loop (plan? → code ↔ review → exit). Does NOT commit.
argument-hint: "<scope or plan reference> [--plan-first] [--no-analyze-baseline]"
allowed-tools: Task, Read, Bash, Glob, Grep, Edit
model: inherit
---

<!-- BLUEPRINT — adapt per-repo. Strip this banner after substitution. -->

# /<repo>-implement — code ↔ review orchestrator

Workflow:

1. **Plan (optional).** If the user passes `--plan-first` or the scope
   is a free-form description, delegate to `<repo>-architect` for a
   plan. Stop and confirm with the user before step 2.

2. **Baseline.** Capture analyzer / test baseline so you can
   distinguish regressions from pre-existing issues. Skip with
   `--no-analyze-baseline`.

3. **Implement.** Delegate to `<repo>-maintainer` with the plan and
   the affected skill list.

4. **Review.** Delegate the resulting diff to `<repo>-reviewer`.

5. **Loop.** If the reviewer returns BLOCK or SHOULD-FIX, send the
   classified list back to the maintainer. Repeat steps 3–5 until
   the reviewer returns clean (NITs may be left for the user).

6. **Hand off.** Do NOT commit. Summarise per-area changes, what was
   actually run vs only proposed, and any open NITs.
