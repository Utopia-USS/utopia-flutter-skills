---
name: utopia-ai-arch
description: >
  Create and maintain the Claude Code `.claude/` layer in Utopia Flutter projects —
  agents, skills, slash commands, hooks, refs, CLAUDE.md, and the architecture
  decision log. Applies when bootstrapping a repo's AI architecture, adding a
  skill / agent / command / hook, recording a rejected alternative, auditing
  for drift, splitting or graduating content, or evolving an existing layer.
  Encodes the project-claude-layer blueprint plus the invariants and decision
  criteria distilled from qbt-black-phone, jolly-phonics-apps, and madrosc-tlumu.
  Layered on top of the upstream `utopia-hooks` plugin — this skill stays
  silent on hook idioms / Screen-State-View / Dart conventions (foundation concerns).
license: MIT
metadata:
  author: UtopiaSoftware
  tags: claude-code, ai-architecture, agents, skills, blueprint, project-layer, hooks, flutter
---

# utopia-ai-arch — Project `.claude/` Layer

## Overview

Holistic guide for the **AI architecture** of a Utopia Flutter project — everything under `.claude/` plus `CLAUDE.md` / `AGENTS.md`. Two layers: the **foundation** (the `utopia-hooks` plugin, ambient, repo-agnostic) and the **project** (your repo's `.claude/`, only what exists because of *this* project's domain, topology, and workflow). This skill teaches the project layer — how to **create** it from the blueprint, **maintain** it as the repo evolves, and avoid the drift modes that have actually happened in production repos.

Project skills cross-link to foundation references; they never restate foundation content. A skill whose description matches every Dart file but only adds project-specific content is a router-in-disguise — split or merge until each skill has a real positive AND negative scope.

## Skill Format

Each reference file follows a hybrid format for fast lookup and deep understanding:

- **What this is** + **When it applies** — one-paragraph framing for fast pattern matching
- **Rules / Decision criteria** — each rule with **what** + **why** (cargo-cult-proof)
- **Concrete shape** — verbatim file skeletons / diffs / decision trees
- **Anti-patterns** — drift symptoms observed in production, each with quoted evidence
- **Impact ratings**: CRITICAL (always apply), HIGH (significant correctness/quality gain), MEDIUM (worthwhile)

## When to Apply

Reference these guidelines when:

- Bootstrapping `.claude/` in a new Utopia repo
- Adding a new skill, agent, slash command, hook script, or `.claude/refs/` entry
- Editing an existing agent prompt, SKILL.md, or `claude-architecture.md`
- Reviewing whether a proposed agent / skill / command should exist at all
- Splitting a skill, graduating a memory entry into a reference, or deleting a stale skill
- Recording a rejected alternative or a new toolchain canon decision
- Auditing the layer for drift (`/<prefix>-audit-skills` style scans)
- Diagnosing why the agent keeps losing a convention while developing the project

## Priority-Ordered Guidelines

| Priority | Category                                | Impact   | Reference |
|----------|-----------------------------------------|----------|-----------|
| 1        | Two-layer model & scope discipline      | CRITICAL | [layer-model.md][layer-model] |
| 2        | Agent roster (blueprint 4 + when to extend) | CRITICAL | [agent-roster.md][agent-roster] |
| 3        | Skill design (applicability, splits, no-router) | CRITICAL | [skill-design.md][skill-design] |
| 4        | Enforcement hooks (quality_check, skills_drift) | CRITICAL | [enforcement-hooks.md][enforcement-hooks] |
| 5        | Evolution & drift (operations + failure modes) | CRITICAL | [evolution-and-drift.md][evolution-and-drift] |
| 6        | Slash commands (3-base + when to extend) | HIGH    | [slash-commands.md][slash-commands] |
| 7        | Architecture decision log               | HIGH     | [architecture-doc.md][architecture-doc] |
| 8        | CLAUDE.md & AGENTS.md symlink           | HIGH     | [claude-md.md][claude-md] |
| 9        | Bootstrap procedure (new repo)          | HIGH     | [bootstrap-procedure.md][bootstrap-procedure] |
| 10       | settings.json shape                     | MEDIUM   | [settings-json.md][settings-json] |

## Quick Reference

Each pattern is a one-paragraph pointer — follow the link for the full contract. Do not extrapolate from the summary.

### Two-layer model → [layer-model.md][layer-model]

Foundation = `utopia-hooks` plugin (ambient, marketplace-installed, repo-agnostic). Project = `.claude/` in the repo (only domain / topology / workflow concerns). Project references foundation, never duplicates. `.claude/refs/` = content for the agent; `.claude/docs/` = meta about the layer — never mix.

### Agent roster → [agent-roster.md][agent-roster]

Exactly four standard agents per repo: `<prefix>-architect` (read-only planner), `<prefix>-maintainer` (write, only writer), `<prefix>-reviewer` (read-only post-impl review, output BLOCKER/SHOULD-FIX/NIT), `<prefix>-precommit-auditor` (read-only staged-diff gate). Each agent's frontmatter preloads `[<prefix>-<master-skill>, utopia-hooks]`. Add a domain auditor (`<prefix>-<domain>-auditor`) ONLY when an incident or threat surface justifies it; per-area maintainers are rejected unless ≥3-area PRs are routine.

### Skill design → [skill-design.md][skill-design]

Every skill needs a positive AND negative applicability scope. "Cross-cutting" or "shared" is not a scope — it's an admission of no scope. Three reference styles: **module** (user-flow + business intent), **pattern** (rules with reasoning, why-first), **cheatsheet** (inventory tables, no flows). Graduation gradient: memory → `references/<feature>-module.md` → own skill. Reversible.

### Enforcement hooks → [enforcement-hooks.md][enforcement-hooks]

`<prefix>_quality_check.sh` is a PostToolUse hook on `Edit|Write|MultiEdit`. Contract: exit 0 silent, exit 1 warn, exit 2 block. Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.pb*.dart`, `*.config.dart`) ALWAYS exit 2 regardless of mode. Guards prove scope (jq, .dart, pubspec, repo basename) before any nudging. Hooks from different layers coexist — don't ask Claude to remember a rule when a script can run.

### Evolution & drift → [evolution-and-drift.md][evolution-and-drift]

The pillar this skill exists for. Operations on a live layer (graduate / split / collapse / delete a skill, add or remove a path nudge, add a domain auditor mid-project, record a rejected alternative) paired with the 22-symptom drift catalogue distilled from production. Triggers for re-reading `claude-architecture.md` before acting: new techstack, new MCP, new external integration, recent incident, roster proposal.

## Templates — `.claude/` Starting Shapes

Canonical placeholder files for bootstrapping a new repo's `.claude/` layer live in [`templates/`][templates] inside this skill. The map of what-goes-where, the placeholder vocabulary (`<repo>`, `<REPO>`, `<area>`, …), and the apply order is in [`templates/TEMPLATES.md`][templates-readme].

```
templates/
├── TEMPLATES.md                    map: each template → target path + substitutions
├── README.md                       full blueprint walkthrough (read once; do NOT copy)
├── CLAUDE.md                       → <repo-root>/CLAUDE.md
├── AGENTS.md  →  CLAUDE.md         symlink (preserve as symlink in target)
├── conventions/                    module / pattern / cheatsheet authoring (do NOT copy)
└── .claude/                        copy this whole subtree, sed-replace <repo>
    ├── settings.json
    ├── docs/claude-architecture.md (write this FIRST, before any other file)
    ├── refs/README.md              do NOT copy (reference-only)
    ├── agents/REPO-{architect,maintainer,reviewer,precommit-auditor}.md
    ├── commands/REPO-{implement,audit,audit-skills}.md
    ├── scripts/REPO_{quality_check,skills_drift}.sh
    └── skills/REPO-AREA/SKILL.md
```

Read [`bootstrap-procedure.md`][bootstrap-procedure] before applying — Phase 0 (Gather) and Phase 1 (Design the skill split) come BEFORE any file copy.

## References

Full documentation with verbatim file skeletons and quoted invariants in [references/][references]:

| File | Impact | Description |
|------|--------|-------------|
| [layer-model.md][layer-model] | CRITICAL | Two-layer model, foundation-vs-project boundary, `.claude/refs/` vs `.claude/docs/` discipline, "project references foundation, never duplicates" |
| [agent-roster.md][agent-roster] | CRITICAL | 4-agent blueprint (architect / maintainer / reviewer / precommit-auditor), invariants per role, hand-off chain, frontmatter shape, output classifications, when (and when NOT) to add domain auditors or per-area maintainers, agent-prompt style (description as router) |
| [skill-design.md][skill-design] | CRITICAL | Positive+negative applicability, no-router/no-shared rules, when to split a skill, primitive sister skills, `.claude/refs/` cross-link discipline, 3 reference styles (module / pattern / cheatsheet) with decision test, graduation gradient |
| [enforcement-hooks.md][enforcement-hooks] | CRITICAL | `<prefix>_quality_check.sh` shape (contract / guards / generated-file block / path nudges / mode env var), `<prefix>_skills_drift.sh` shape, when to add a SessionStart hook (jolly precedent), why NO push-guard, when to add a path nudge (≥2-references rule) |
| [evolution-and-drift.md][evolution-and-drift] | CRITICAL | Operations on a live layer (graduate / split / collapse / delete a skill, add/remove path nudges, add a domain auditor mid-project, record a rejected alternative) paired with the 22-symptom drift catalogue from production (qbt / jolly / tlumu). Triggers for re-reading the architecture doc + audit grep one-liners |
| [slash-commands.md][slash-commands] | HIGH | 3-base commands (/implement, /audit, /audit-skills), implement-loop shape with retry cap = 2, never-commit/never-push/reviewer-fresh-context rules, when to add `/plan` `/team` `/design` `/ship`, anti-pattern: slash wrapper around a single agent |
| [architecture-doc.md][architecture-doc] | HIGH | `.claude/docs/claude-architecture.md` 9-section spine, rejected-alternative 4-field entry shape, toolchain canon, MCP-assumption rules, how to add a new entry without re-litigating settled choices |
| [claude-md.md][claude-md] | HIGH | What belongs in `CLAUDE.md` (always-loaded inventory) vs deep content (references), table shapes (skills / agents / commands / when-to-invoke), `AGENTS.md` symlink convention and rationale |
| [bootstrap-procedure.md][bootstrap-procedure] | HIGH | Step-by-step "create the Claude layer for a new repo" — what to gather first (domain risk, monorepo topology, tech stacks, ticketing tool, design tool), 7-step apply, validation checklist |
| [settings-json.md][settings-json] | MEDIUM | Canonical settings.json shape: `extraKnownMarketplaces`, `enabledPlugins`, `permissions.allow` (why git push is OFF), `hooks.PostToolUse` matcher, MCP wiring, plugin scope choice |

## Searching References

```bash
# Find patterns by concept
grep -rl "applicability" references/         # scope discipline, positive/negative
grep -rl "router skill" references/          # the no-router rule
grep -rl "domain auditor" references/        # when to add one
grep -rl "rejected alternative" references/  # decision-log discipline
grep -rl "retry cap" references/             # /implement loop limits
grep -rl "fresh context" references/         # reviewer independence
grep -rl "exit 0" references/                # hook scope-guard pattern
grep -rl "<prefix>" references/              # placeholder substitution
grep -rl "graduation" references/            # memory → module → skill
grep -rl "drift" references/                 # symptoms catalogue
grep -rl "module-style\|pattern-style\|cheatsheet-style" references/  # reference styles
```

## Problem → Skill Mapping

| Problem | Start With |
|---------|------------|
| Bootstrapping `.claude/` in a new repo | [bootstrap-procedure.md][bootstrap-procedure] |
| What does `.claude/` even contain? | [layer-model.md][layer-model] |
| Adding a new agent | [agent-roster.md][agent-roster] |
| Adding a new skill | [skill-design.md][skill-design] |
| Designing the skill split for a multi-stack monorepo | [skill-design.md][skill-design] + [bootstrap-procedure.md][bootstrap-procedure] Phase 1 |
| Should we have a browser-testing / design / deployment skill? | [skill-design.md][skill-design] §"Workflow-style skills" + [bootstrap-procedure.md][bootstrap-procedure] §0.4 |
| Should this content live in `.claude/refs/` or in a skill? | [skill-design.md][skill-design] + [layer-model.md][layer-model] |
| Wiring path nudges in `<prefix>_quality_check.sh` | [enforcement-hooks.md][enforcement-hooks] |
| Adding a new slash command | [slash-commands.md][slash-commands] |
| Adding a new hook script or path nudge | [enforcement-hooks.md][enforcement-hooks] |
| Adding a new `.claude/refs/` shared markdown | [skill-design.md][skill-design] (cross-link discipline) |
| Editing `claude-architecture.md` | [architecture-doc.md][architecture-doc] |
| Editing `CLAUDE.md` | [claude-md.md][claude-md] |
| Editing `.claude/settings.json` | [settings-json.md][settings-json] |
| Designing the skill split for a new monorepo | [skill-design.md][skill-design] + [layer-model.md][layer-model] |
| Choosing module vs pattern vs cheatsheet for a reference | [skill-design.md][skill-design] |
| "Should we add a `<prefix>-security-auditor` agent?" | [agent-roster.md][agent-roster] (decision criteria) |
| "Should we add a `/<prefix>-design` command?" | [slash-commands.md][slash-commands] |
| "Should we have a `<prefix>-shared` skill?" | [skill-design.md][skill-design] (NO — read why) |
| "Should we add a `git push` guard hook?" | [enforcement-hooks.md][enforcement-hooks] (NO — read why) |
| Agent keeps inventing skills that don't exist | [agent-roster.md][agent-roster] + [evolution-and-drift.md][evolution-and-drift] |
| Agent loses conventions when developing the project | [evolution-and-drift.md][evolution-and-drift] |
| A skill no longer fires / fires on the wrong files | [skill-design.md][skill-design] + [evolution-and-drift.md][evolution-and-drift] |
| `dart_fix` keeps bulldozing the user's WIP | [evolution-and-drift.md][evolution-and-drift] (symptom G) |
| Generated-file edits keep slipping through | [enforcement-hooks.md][enforcement-hooks] (hard-block contract) |
| Recording why we *didn't* pick approach X | [architecture-doc.md][architecture-doc] (rejected-alternative entry shape) |
| New techstack joining the repo | [skill-design.md][skill-design] (primitive sister skill criteria) |
| New external integration (Linear / paper.design) | [slash-commands.md][slash-commands] + [evolution-and-drift.md][evolution-and-drift] |
| Reviewer accepting blocker findings that don't cite a rule | [agent-roster.md][agent-roster] (reviewer invariants) |
| Memory entry that's outgrown user-level scope | [evolution-and-drift.md][evolution-and-drift] (graduation) |
| Skill whose `references/` has accumulated cross-cutting content | [evolution-and-drift.md][evolution-and-drift] (symptom A) |
| MCP server referenced in agents but not installed | [evolution-and-drift.md][evolution-and-drift] (symptom P) + [settings-json.md][settings-json] |
| Worktrees silently producing no-op Dart edits | [evolution-and-drift.md][evolution-and-drift] (symptom H) |
| Stale `dart mcp-server` processes accumulating memory | [enforcement-hooks.md][enforcement-hooks] (SessionStart hook criteria) |

[references]: references/
[templates]: templates/
[templates-readme]: templates/TEMPLATES.md
[layer-model]: references/layer-model.md
[agent-roster]: references/agent-roster.md
[skill-design]: references/skill-design.md
[enforcement-hooks]: references/enforcement-hooks.md
[evolution-and-drift]: references/evolution-and-drift.md
[slash-commands]: references/slash-commands.md
[architecture-doc]: references/architecture-doc.md
[claude-md]: references/claude-md.md
[bootstrap-procedure]: references/bootstrap-procedure.md
[settings-json]: references/settings-json.md

## Non-Negotiable Rules

- **Project layer is layered on top of the foundation, not in competition.** A Claude config for a Utopia repo without `utopia-hooks` is missing the foundation the codebase is written on — score its absence as missing baseline alignment, not as self-containment.
- **Project references foundation, never duplicates.** Cross-link via `utopia-hooks:references/<file>.md`. If utopia renames something, find out and fix; don't inherit silently.
- **No router skill.** Routing is the job of `CLAUDE.md` (always-on), the quality-check hook (deterministic path nudge), and per-skill description frontmatter (probabilistic). A skill that "routes" to other skills loses both ways.
- **No cross-cutting "shared" skill.** Cross-skill content lives in `.claude/refs/`, linked from each consuming `SKILL.md`'s "See also" section — not buried in a reference, where it's two hops from visibility.
- **Every skill needs positive AND negative applicability.** If you can't write the negative scope, the skill is trying to be a router. Split or merge.
- **The four-agent roster is the standard.** Architect / maintainer / reviewer / precommit-auditor. Adding a fifth (domain auditor) requires a documented incident or threat-surface justification. Per-area maintainers are rejected unless ≥3-area PRs in a single branch are routine.
- **Maintainer is the only write-capable agent.** Reviewer, architect, precommit-auditor, and domain auditors are read-only. Compromising this collapses the code↔review loop.
- **Reviewer runs on fresh context.** `/<prefix>-implement` withholds the maintainer's self-report — independence is the reviewer's only superpower. Don't leak reasoning across the boundary.
- **Retry cap = 2.** Maintainer → reviewer → maintainer → reviewer. Still failing? Hand both reports to the user. Scope stays constant across retries; retry is for fixing mistakes, not expanding scope.
- **/implement never commits, never pushes.** Hand-off ends at user discretion. Commit gate is `/<prefix>-audit`.
- **Generated files are hook-blocked (exit 2, regardless of mode).** Extensions vary per project (`*.g.dart`, `*.freezed.dart`, plus protobuf / route variants where applicable). Always blocked. Regenerate via the repo's build-runner command — never edit.
- **Hooks are guarded.** Each script proves it's in scope (file type, pubspec, repo-basename match) before doing anything. Out-of-scope → silent `exit 0`. Foundation and project hooks coexist without conflict.
- **Prefix can differ from repo-folder-name; basename guard uses repo-folder-name.** The `<prefix>` is the artifact-name slug (e.g. `bp`); the `<repo-folder-name>` is the on-disk basename (e.g. `qbt-black-phone`). The hook's `basename "$repo_root"` match MUST use the folder name, not the prefix — otherwise the hook silently never fires.
- **No `git push` guard hook.** Two layers already cover it: `permissions.allow` deliberately omits `git push` (every push prompts the user), and GitHub branch protection covers the remote. Reintroduce only in a repo that has neither.
- **Description as router.** A skill's `description:` is the only signal for auto-invocation — written as "WHEN to apply" not "WHAT I am". Keep it precise and path-scoped.
- **Cross-link discipline.** Cross-skill markdown links live in `SKILL.md` itself (in `References` or `See also`), never deep in a reference. `SKILL.md` always loads when the skill matches; references are doc-on-demand.
- **`.claude/refs/` ≠ `.claude/docs/`.** Refs are content the agent should load; docs are meta about the layer (decision log, authoring helpers). Mixing them invites the agent to load decision-log content as guidance.
- **Rejected alternatives section pays for itself.** Every removed/considered-and-rejected design choice gets an entry with `alternative / case for / case against here / reversal criterion`. Future-you re-litigates settled choices without this section.
- **`AGENTS.md` is a symlink to `CLAUDE.md`.** Single source of truth. Hard links don't survive git; two independent files drift.
- **Don't reference an MCP server that isn't installed.** Listing permissions for a server that isn't installed pollutes the allowlist; agent prompts referencing absent tools confuse the model.
- **Patterns describe what IS, not what should be.** A pattern reference for code that doesn't yet follow the convention is a roadmap document — move it to project memory until the migration lands.
- **Stale cheatsheet entries are worse than missing entries.** When the codebase changes, the cheatsheet follows on the same PR.
- **Comments respond to the code, not the prompt.** No `// Added per user request`, no `// FIXME from review feedback`, no `// AI-generated …` — if the comment wouldn't make sense to a reader who's never seen this conversation, PR, or review thread, delete it.

## Self-Audit Checklist

After creating or modifying any `.claude/` artefact, verify:

1. Does this artefact (skill / agent / command / hook) have a real positive AND negative applicability scope? → If not, it's a router-in-disguise; split or merge.
2. Does this skill restate foundation conventions (Screen/State/View, hooks, IList/IMap/ISet, strict analyzer)? → Move references to cross-links into `utopia-hooks`.
3. Does this skill's `references/` contain content that applies cross-skill? → Lift to `.claude/refs/` and link from each consuming SKILL.md's See also.
4. Does a new skill have content yet, or is it a primitive shell preempting future work? → Defer until there's real content; skills with no applicability content fire wrongly.
5. Does a new agent have a documented incident or threat-surface justification? → If not, the 4-agent blueprint covers it.
6. Does a new slash command actually orchestrate multiple steps, or is it a wrapper around a single agent? → Direct agent invocation gives subagent isolation for free; drop the wrapper.
7. Does a new hook script have its scope guards (jq, file type, pubspec, repo-basename) BEFORE doing any work? → Add them or the hook fires in unrelated workspaces.
8. Does a new path nudge in `<prefix>_quality_check.sh` point at ≥2 references the agent should actually consult? → A nudge pointing at "no content yet" wastes a firing.
9. Does a new path nudge match the skill's `applicability` exactly? → Mismatches surface the wrong skill, defeating determinism.
10. Are there `git push` permissions in `settings.json` or a `PreToolUse` push guard? → Remove. Permission allowlist omits it; branch protection covers it.
11. Is `AGENTS.md` a real symlink to `CLAUDE.md` (`ls -la` confirms `->`), not a copy? → Re-create the symlink; copies drift.
12. Does `CLAUDE.md` describe a skill / agent / command that doesn't exist (or vice versa)? → Run `/<prefix>-audit-skills` or fix manually.
13. Does the new artefact have a corresponding entry in `claude-architecture.md`? → Skill in §Skill split; agent in §Agent roster; command in §Slash commands; new pattern in §Rejected alternatives if it's a deliberate omission.
14. Does the architecture doc still reflect reality? → Update §Rollout status; if a rejected alternative was reversed, update its entry, don't delete it.
15. Did this work cross a "trigger" event (new techstack / new MCP / new ticketing integration / recent incident / roster proposal)? → Re-read `claude-architecture.md` before deciding.
16. Generated-file edits in the diff? → Regenerate via build_runner; never accept manual edits.
17. Does an agent prompt reference an MCP server not declared in `enabledMcpjsonServers` or `permissions.allow`? → Remove the reference or install the server.
18. Does this reference repeat what `dart format` / `dart fix` / the analyzer / `utopia_lints` already enforces deterministically? → Delete the reference; rely on the tool.
19. **`<prefix>` vs `<repo-folder-name>` mix-up** — does the hook's `basename "$repo_root"` match the actual repo directory name, or the prefix? If the prefix, the hook silently never fires. See [enforcement-hooks.md][enforcement-hooks] guards.
20. **Concrete-shape filesystem match** — does the `.claude/skills/` directory listing match `claude-architecture.md` §"Skill split" table AND `CLAUDE.md`'s skill inventory? Are there orphan/ghost skill directories (empty `references/`, no `SKILL.md`)? Run `ls .claude/skills/*/SKILL.md` and diff against both inventories. Same for `agents/`, `commands/`, `scripts/`.
21. **AGENTS.md is a real symlink** — `ls -la AGENTS.md` shows `→ CLAUDE.md`, not a regular file size. A copy drifts silently.
22. **Workflow-style skill classification** — if a skill is workflow-oriented (driving an MCP tool, an external service, a browser) and doesn't fit module/pattern/cheatsheet, document it as a recognised exception in `claude-architecture.md` §"Reference styles in use" — do not force-fit the trichotomy. See [skill-design.md][skill-design].

## Companion Plugins

- **[utopia-hooks](https://github.com/Utopia-USS/utopia-flutter-skills)** — the foundation this layer assumes. Always installed alongside.
- **[utopia-hooks-migrate-bloc](https://github.com/Utopia-USS/utopia-flutter-skills)** — orchestrated BLoC → utopia_hooks migration. Independent surface; not part of `.claude/` AI architecture.

## Attribution

Distilled from the production `.claude/` layers of `qbt-black-phone`, `jolly-phonics-apps`, and `madrosc-tlumu`. Built by UtopiaSoftware.
