---
title: Two-Layer Model — Foundation vs Project
impact: CRITICAL
tags: architecture, layering, scope, foundation, project
---

# Two-Layer Model — Foundation vs Project

## What this is

Every Utopia repo's AI architecture has exactly two layers, hard-separated:

1. **Foundation** — the `utopia-hooks` plugin. Marketplace-installed, ambient, repo-agnostic. Teaches Screen / State / View, the hook catalog, async patterns, global state, DI, `IList`/`IMap`/`ISet`, lambda style, strict analyzer. **Knows nothing about your repo.**
2. **Project** — `.claude/` inside the repo, plus `CLAUDE.md` / `AGENTS.md`. Only the concerns that exist because of *this* project's domain, monorepo topology, and workflow.

```
┌──────────────────────────────────────────────────────────┐
│                       PROJECT LAYER                      │
│  .claude/  +  CLAUDE.md  +  AGENTS.md ──symlink─→ CLAUDE │
│                                                          │
│  - <prefix>-architect, -maintainer, -reviewer, -auditor  │
│  - <prefix>-<area> skills (your domain)                  │
│  - /<prefix>-implement, /<prefix>-audit, ...             │
│  - <prefix>_quality_check.sh path-→-skill nudges         │
│  - .claude/refs/ — cross-skill shared markdown           │
│  - .claude/docs/claude-architecture.md — decision log    │
└──────────────────────────────────────────────────────────┘
                          ▲ referenced, never duplicated
                          │
┌──────────────────────────────────────────────────────────┐
│                     FOUNDATION LAYER                     │
│            `utopia-hooks` plugin (marketplace)           │
│                                                          │
│  - Screen / State / View pattern                         │
│  - Hook catalog (useState, useSubmitState, ...)          │
│  - Async patterns, global state, DI                      │
│  - IList / IMap / ISet, lambda style, strict analyzer    │
└──────────────────────────────────────────────────────────┘
```

## When this applies

- Designing the skill split for a new repo
- Deciding whether content belongs in the foundation or the project layer
- Reviewing a SKILL.md / reference that's drifted into foundation territory
- Recording a decision in `claude-architecture.md` about where a concern lives

## Rules

### 1. Project references foundation, never duplicates.

Cross-link via `utopia-hooks:references/<file>.md` or a plain reference to the file path. Every project SKILL.md opens with a "Relationship to the foundation" table that lists what `utopia-hooks` owns and explicitly disclaims those concerns.

> "Project references foundation, never duplicates. Cross-reference via `utopia-hooks:references/<file>.md`. If utopia renames something, we find out and fix; we don't inherit silently." — `qbt-black-phone/.claude/docs/claude-architecture.md:88-91`

**Why.** A repo that restates "use IList not List" inside its own skill diverges silently the day `utopia-hooks` updates its convention. A cross-link breaks loud — the link or the rule on the other end is what fails review, not behaviour months later.

### 2. Foundation concerns stay in the foundation.

These belong to `utopia-hooks`, NEVER to a project skill:

- Screen / State / View triplet shape (`*_screen.dart`, `*_screen_state.dart`, `*_screen_view.dart`)
- Hook catalog (`useState`, `useMemoized`, `useEffect`, `useSubmitState`, `useAutoComputedState`, `useMemoizedStream`, `usePaginatedComputedState`, `useProvided`, `useInjected`, etc.)
- Global state mechanics (`_providers`, `HasInitialized`, `MutableValue`)
- Async download / upload / stream patterns
- `IList` / `IMap` / `ISet`, lambda style (`it.foo`), strict analyzer
- DI bridge hook + `useInjected`

**Why.** Restating these in a project skill (a) adds maintenance, (b) creates the temptation to subtly diverge under WIP pressure, (c) makes the foundation feel optional when it isn't.

### 3. Project layer owns domain, topology, and workflow.

A concern is project-level when it requires knowing your repo's specifics:

- Monorepo topology (which workspace owns what — `phone/`, `admin/`, `core_messaging/`, `packages/dske/`)
- Domain logic (E2E crypto pipeline, party-game rooms, classroom lessons, daily packs)
- Design system tokens / components specific to this product
- Backend contracts (Supabase RLS, gRPC proto, Firestore rules, Cloud Functions)
- External integrations (Linear, ClickUp, paper.design, RevenueCat)
- Build-runner / codegen specifics (proto, freezed, retrofit, route, localization)
- Toolchain canon (FVM yes/no — a binary repo-level choice)

### 4. Within `.claude/`, refs and docs are different things.

```
.claude/refs/  — CONTENT for the agent (cross-skill shared markdown)
.claude/docs/  — META about the layer (decision log, authoring helpers)
```

**Why.** Mixing them invites the agent to load decision-log content as guidance, or to skip shared markdown thinking it's internal docs. They render the same in markdown viewers; only the directory split keeps the agent's loading model honest.

> "`.claude/refs/` — content for the agent (cross-skill shared markdown). `.claude/docs/` — meta about the layer (decisions, architecture log, authoring helpers). Mixing them invites the agent to load decision-log content as guidance, or to skip shared markdown thinking it's internal docs." — blueprint `README.md:624-633`

### 5. Foundation hooks and project hooks coexist; guarded scope is mandatory.

`<prefix>_quality_check.sh` and the foundation hook fire on the same `Edit|Write|MultiEdit` events. They must coexist without conflict. Each script proves it's in scope (jq, file type, pubspec, repo-basename match) BEFORE doing anything. Out-of-scope = silent `exit 0`. See [enforcement-hooks.md](enforcement-hooks.md).

> "Hooks from different layers coexist without conflict." — `qbt-black-phone/.claude/docs/claude-architecture.md:75`

## Concrete shape

The post-bootstrap tree:

```
myrepo/
├── CLAUDE.md                       agent context (top-of-context inventory)
├── AGENTS.md  →  CLAUDE.md         symlink for OpenAI/Codex tools
└── .claude/
    ├── settings.json               hook wiring + plugin enablement + permissions
    ├── docs/
    │   └── claude-architecture.md  per-repo decision log (rationale, alternatives)
    ├── refs/                       cross-skill shared markdown (passive — only via "See also")
    │   ├── README.md
    │   └── <shared-doc>.md
    ├── agents/
    │   ├── <prefix>-architect.md
    │   ├── <prefix>-maintainer.md
    │   ├── <prefix>-reviewer.md
    │   └── <prefix>-precommit-auditor.md
    ├── commands/
    │   ├── <prefix>-implement.md
    │   ├── <prefix>-audit.md
    │   └── <prefix>-audit-skills.md
    ├── scripts/
    │   ├── <prefix>_quality_check.sh
    │   └── <prefix>_skills_drift.sh
    └── skills/
        └── <prefix>-<area>/
            ├── SKILL.md
            └── references/
                └── *.md
```

`AGENTS.md` is a real symlink (not a copy). Git preserves symlinks natively. Copies drift. See [claude-md.md](claude-md.md) for the rationale.

## Anti-patterns

### "A foundation skill could just include the project's components.md"

❌ Adding repo-specific component / design-token content to `utopia-hooks/references/`.
✅ Cross-link from the project skill into foundation refs; keep design-system docs inside `<prefix>/references/components.md` or `.claude/refs/components.md`.

### "Why have foundation if we restate everything anyway?"

This is the symptom: a project skill that restates Screen/State/View, hook idioms, or IList rules. Fix: replace the restatement with a one-line "see foundation: utopia-hooks" and delete the duplicated material. The cross-link is the contract — restatement is silent divergence.

### Mixing `.claude/refs/` and `.claude/docs/`

❌ `.claude/docs/components.md` (decision-log dir, but it's content).
❌ `.claude/refs/claude-architecture.md` (refs dir, but it's meta).
✅ `.claude/refs/components.md` and `.claude/docs/claude-architecture.md`.

### Cross-skill content stuck inside one skill's references/

If `<prefix>/references/foo.md` is referenced by two or more sister skills, it doesn't belong in one skill — it belongs in `.claude/refs/`, linked from each consuming SKILL.md's See also section. See [skill-design.md](skill-design.md) for the cross-link discipline rule.

### "We don't need utopia-hooks, we write our own conventions"

> "A Claude config for this repo without `utopia-hooks` is missing the foundation this codebase is written on — do not score its absence as self-containment; score it as missing baseline alignment." — `qbt-black-phone/.claude/docs/claude-architecture.md:120`

If the code uses utopia_hooks / utopia_arch, the foundation plugin is non-optional. A "self-contained" `.claude/` is a layer missing its base.

## See also

- [skill-design.md](skill-design.md) — applicability scopes, no-router rule, cross-link discipline
- [enforcement-hooks.md](enforcement-hooks.md) — guarded scope, foundation+project hook coexistence
- [claude-md.md](claude-md.md) — AGENTS.md symlink, top-of-context inventory
- [bootstrap-procedure.md](bootstrap-procedure.md) — applying the blueprint to a new repo
- Foundation plugin: `utopia-hooks` at https://github.com/Utopia-USS/utopia-flutter-skills
- Inline templates: [`../templates/`](../templates/) — canonical placeholder files for bootstrap; see [`../templates/TEMPLATES.md`](../templates/TEMPLATES.md) for the map
