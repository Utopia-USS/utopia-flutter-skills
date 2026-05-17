---
description: Pre-commit audit of staged changes for commit-readiness. Read-only.
argument-hint: "[optional scope note, e.g. 'only <area> changes']"
allowed-tools: Task
---

<!-- BLUEPRINT — adapt per-repo. Strip this banner after substitution. -->

Use the Task tool to launch the `<repo>-precommit-auditor` subagent with
the staged diff (`git diff --staged`). Surface its output verbatim. Do
not auto-fix.
