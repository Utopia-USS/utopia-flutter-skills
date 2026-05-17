# Templates — Canonical File Shapes

These are the **starting shapes** to copy into a new repo when bootstrapping its `.claude/` layer. They are NOT verbatim files to drop in — placeholders need substitution and per-repo customisation. The discipline is taught in [`../references/bootstrap-procedure.md`](../references/bootstrap-procedure.md) and [`../references/skill-design.md`](../references/skill-design.md).

## What stays in templates (referenced, never copied)

Three things are reference material — readers consult them but they do NOT get copied into the target repo:

| File | Purpose |
|------|---------|
| [`README.md`](README.md) | Full blueprint walkthrough — read once, then design your repo's layer with this as the canonical model. |
| [`conventions/module-style.md`](conventions/module-style.md) | How to write a `<feature>-module.md` reference (user-flow + business intent). |
| [`conventions/pattern-style.md`](conventions/pattern-style.md) | How to write a `<topic>-pattern.md` reference (rules with reasoning, why-first). |
| [`conventions/cheatsheet-style.md`](conventions/cheatsheet-style.md) | How to write a `<topic>-cheatsheet.md` reference (inventory tables, no flows). |
| [`.claude/refs/README.md`](.claude/refs/README.md) | Cross-skill `.claude/refs/` discipline — also reference-only. |

## What gets copied (with placeholder substitution)

Every file below gets adapted into the target repo:

| Template path | Lands at | What to substitute |
|---------------|----------|--------------------|
| [`CLAUDE.md`](CLAUDE.md) | `<repo-root>/CLAUDE.md` | `<repo>`, `<project name>`, skill / agent / command tables |
| [`AGENTS.md`](AGENTS.md) | `<repo-root>/AGENTS.md` | Re-create as symlink: `ln -s CLAUDE.md AGENTS.md` (the template IS a symlink; `cp` may resolve it — verify with `ls -la`) |
| [`.claude/settings.json`](.claude/settings.json) | `<repo-root>/.claude/settings.json` | `<repo>` in script path; permissions list; MCP servers |
| [`.claude/docs/claude-architecture.md`](.claude/docs/claude-architecture.md) | `<repo-root>/.claude/docs/claude-architecture.md` | All 9 sections — **write this FIRST**, before any other artefact |
| [`.claude/agents/REPO-architect.md`](.claude/agents/REPO-architect.md) | `<repo-root>/.claude/agents/<repo>-architect.md` | `<repo>` in name, skill list, body |
| [`.claude/agents/REPO-maintainer.md`](.claude/agents/REPO-maintainer.md) | `<repo-root>/.claude/agents/<repo>-maintainer.md` | Same |
| [`.claude/agents/REPO-reviewer.md`](.claude/agents/REPO-reviewer.md) | `<repo-root>/.claude/agents/<repo>-reviewer.md` | Same |
| [`.claude/agents/REPO-precommit-auditor.md`](.claude/agents/REPO-precommit-auditor.md) | `<repo-root>/.claude/agents/<repo>-precommit-auditor.md` | Same |
| [`.claude/commands/REPO-implement.md`](.claude/commands/REPO-implement.md) | `<repo-root>/.claude/commands/<repo>-implement.md` | `<repo>` in agent calls |
| [`.claude/commands/REPO-audit.md`](.claude/commands/REPO-audit.md) | `<repo-root>/.claude/commands/<repo>-audit.md` | Same |
| [`.claude/commands/REPO-audit-skills.md`](.claude/commands/REPO-audit-skills.md) | `<repo-root>/.claude/commands/<repo>-audit-skills.md` | Same |
| [`.claude/scripts/REPO_quality_check.sh`](.claude/scripts/REPO_quality_check.sh) | `<repo-root>/.claude/scripts/<repo>_quality_check.sh` | `<repo>` everywhere; `<REPO>` env var; `<repo-folder-name>` basename guard; `<repo-specific build_runner / codegen command>`; path → skill case branches |
| [`.claude/scripts/REPO_skills_drift.sh`](.claude/scripts/REPO_skills_drift.sh) | `<repo-root>/.claude/scripts/<repo>_skills_drift.sh` | `<repo>` only |
| [`.claude/skills/REPO-AREA/SKILL.md`](.claude/skills/REPO-AREA/SKILL.md) | `<repo-root>/.claude/skills/<repo>-<area>/SKILL.md` | `<repo>-<area>`, applicability scopes, references table |

## Placeholder vocabulary

| Placeholder | Meaning | Example |
|-------------|---------|---------|
| `<repo>` (lowercase) | Project prefix (matches repo folder name) | `acme`, `acme`, `acme` |
| `<REPO>` (uppercase) | Env-var prefix — only in `<REPO>_QUALITY_MODE` | `BP`, `JOLLY`, `TLUMU` |
| `<repo>-<area>` | A skill's slug | `acme-flutter`, `acme-api`, `acme-functions` |
| `<repo>-<domain>-auditor` | Optional domain-auditor agent | `acme-domain-auditor` |
| `<project name>` | Human-readable repo name | "Example Project", "Example Monorepo" |
| `<repo-folder-name>` | On-disk directory name (used by hook basename guard) | `example-monorepo`, `example-monorepo` |
| `<area-N-paths>` | Path patterns inside hook `case "$repo_rel" in ... esac` | `phone/lib/*`, `packages/app/lib/*` |
| `<feature>`, `<topic>`, `<other-area>`, `<shared-doc>` | Reference filenames inside SKILL.md | |
| `<repo-specific build_runner / codegen command>` | Hook's hint when blocking generated-file edits | `dart run build_runner build --delete-conflicting-outputs --workspace` |

## Apply order

Per [`../references/bootstrap-procedure.md`](../references/bootstrap-procedure.md):

1. **Phase 0 — Gather** (do NOT touch files yet)
2. **Phase 1 — Design the skill split** (positive + negative scopes per skill)
3. **Phase 2 — Draft `.claude/docs/claude-architecture.md`** FIRST (so it decides, not narrates)
4. **Phase 3 — Copy the shapes from this templates directory** and sed-replace placeholders
5. **Phase 4 — Wire `.claude/settings.json`** (see [`../references/settings-json.md`](../references/settings-json.md))
6. **Phase 5 — Trim `CLAUDE.md`** to inventory-only (see [`../references/claude-md.md`](../references/claude-md.md))
7. **Phase 6 — Symlink `AGENTS.md → CLAUDE.md`** (`ln -s`, not copy)
8. **Phase 7 — Validate** (throwaway edits to trigger each hook rule; `<repo>-audit-skills` clean)

## What to remove after substitution

Each blueprint file has banner comments (`<!-- BLUEPRINT — adapt per-repo. ... -->` near the top, plus long header explainers in the agent / command files). **Strip them once substitutions are made.**

## Workflow-templates — opt-in bundles

The `.claude/` files above are the **always-copy base layer**. Beyond that, [`workflow-templates/`](workflow-templates/) ships **opt-in bundles** for project-specific commands and workflow-style skills. Open each bundle ONLY when its corresponding signal — auto-inspectable (web build, docker-compose, etc.) or user-driven (Phase 0.5 user-prompt) — is positive. See [`workflow-templates/README.md`](workflow-templates/README.md) for the full decision matrix.

Five bundles, each in its own subdirectory:

| Bundle | Shape | Open when | Production precedent |
|---|---|---|---|
| [`workflow-templates/browser-testing/`](workflow-templates/browser-testing/) | skill-only | Repo serves any web build (auto-inspectable) | All 3 repos |
| [`workflow-templates/design/`](workflow-templates/design/) | **skill + command pair** | Team uses paper.design / Figma / handoff bundle (user-prompt) | Jolly |
| [`workflow-templates/ship/`](workflow-templates/ship/) | command-only | Team uses Linear / ClickUp / Jira (user-prompt) | Jolly |
| [`workflow-templates/plan/`](workflow-templates/plan/) | command-only | Routine cross-package PRs (user-prompt) | Qbt |
| [`workflow-templates/team/`](workflow-templates/team/) | command-only | PRs split into ≥2 disjoint parallel chunks routinely (user-prompt) | Qbt |

Each bundle has its own `README.md` explaining when to open it and what to substitute. The decision procedure lives in [`../references/initial-setup.md`](../references/initial-setup.md) §"Walkthrough C.1" (auto-inspectable) and §"Walkthrough C.2" (user-driven). The Phase 0.5 user-prompts that gate the user-driven bundles live in [`../references/bootstrap-procedure.md`](../references/bootstrap-procedure.md) §"0.4 External integrations".

**Bundles you don't copy** → §"Rejected alternative" entry in `claude-architecture.md` with reversal criterion ("reopen when team adopts <tool>"). The template stays available in the upstream skill — when reversal criterion is met later, copy then.
