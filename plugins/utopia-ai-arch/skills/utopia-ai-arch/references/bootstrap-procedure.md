---
title: Bootstrap Procedure — Create the `.claude/` Layer for a New Repo
impact: HIGH
tags: bootstrap, blueprint-apply, new-repo, validation, gather, skill-split, claude-architecture
---

# Bootstrap Procedure — Create the `.claude/` Layer for a New Repo

## What this is

The step-by-step procedure for **creating** a project's `.claude/` layer from scratch — gather → decide → draft architecture → copy shapes → wire → trim → symlink → validate. Distilled from the blueprint's 7-step "How to apply" procedure (blueprint `README.md:377-433`) augmented with the gather phase (what you collect before touching any file) and the validation checklist (the greps that catch silent bootstrap mistakes).

This is **not `cp -r`**. The blueprint is a model — you read it, design the skill split for your repo, then copy *file shapes* and substitute placeholders. Mechanical copying doesn't substitute for the architectural decision of how to slice your repo.

> "This is not a `cp -r`. The blueprint is a model; applying it is a short architectural exercise plus mechanical copying of file shapes." — blueprint `README.md:378-379`

## When this applies

- Bootstrapping a new Utopia Flutter repo (fresh `.claude/` layer)
- Rebooting a layer that's drifted heavily and needs a coherent re-baseline
- Auditing a `.claude/` layer that "looks complete but feels off" — running the validation checklist against an existing layer catches the silent omissions

## Phase 0 — Gather (BEFORE touching any file)

Architectural decisions later (skill split, agent roster, hook scope, slash commands) all depend on facts you collect here. Skipping this phase is the dominant bootstrap-time mistake — you end up retrofitting the architecture doc to whatever you typed first.

### 0.1 Domain risk

Does this repo handle any of:

- End-to-end crypto / message confidentiality
- Native FFI (DSKE, ML-KEM, platform-keystore bindings)
- Row-level security / multi-tenant data isolation (Supabase RLS, Postgres RLS, Firestore rules)
- Auth tokens, refresh-token flows, OAuth callbacks
- Payments / IAP / revenue (RevenueCat, App Store / Play billing, paywall)
- Push-payload contents (notification payloads that may leak data)

**If yes → plan a domain auditor** (`<prefix>-<domain>-auditor`, read-only fifth agent). See [agent-roster.md](agent-roster.md) "Add a domain auditor" decision criteria. Precedent: qbt's `bp-security-auditor` for E2E messaging.

If no → the standard four agents cover it.

### 0.2 Monorepo topology

List the workspaces and what they each are:

```
<repo>/
├── <workspace-1>/    # purpose · techstack
├── <workspace-2>/    # purpose · techstack
├── ...
└── ...
```

Example (madrosc-tlumu):

```
madrosc-tlumu/
├── packages/app/        # main Flutter app · Dart/Flutter+FVM
├── packages/admin/      # admin Flutter app · Dart/Flutter+FVM
├── packages/core/       # shared Dart code · Dart+FVM
├── packages/tools/      # internal CLIs · Dart+FVM
├── packages/landing/    # marketing site · TypeScript/Next.js
└── functions/           # Cloud Functions · TypeScript/Node
```

Each workspace with **a real Claude content surface** becomes a candidate skill. Workspaces with no Claude work yet are primitive-skill candidates — decision deferred (see Phase 1).

### 0.3 Tech stacks per workspace

Determines what skill applicability scopes look like and whether to open primitive sister skills:

| Stack | Examples | Skill implication |
|-------|----------|-------------------|
| Flutter/Dart with FVM | most Utopia apps | Foundation hook (utopia-hooks) fires; project skill carries domain |
| Flutter/Dart **without** FVM | (rare) | Toolchain canon paragraph reflects bare `dart`/`flutter` |
| Kotlin/Ktor backend | qbt's classroom-api precedent | Separate skill; no foundation hook |
| TypeScript/Next.js | landing sites, marketing | Separate skill; no foundation hook |
| TypeScript/Node Cloud Functions | Firebase, Vercel | Separate (often primitive) skill |
| Deno / other runtimes | Supabase Edge, Cloudflare Workers | Separate skill |

### 0.4 External integrations — USER-PROMPT REQUIRED (not auto-inspectable)

**These integrations cannot be reliably determined from repo state.** A team can be on Linear without a `.linear-config` in the repo; they can plan to use paper.design without the MCP installed yet; they can have routine cross-package PRs without anything recording that fact. **Ask the user explicitly** with the prompts below. The answers gate which `templates/workflow-templates/<bundle>/` to copy.

#### Required user prompts

```text
1. Design tool integration?
   (paper.design MCP / Figma export / claude.design handoff bundle / none)
   → Affects: opening `<prefix>-design` (skill + command pair)
   → Template: workflow-templates/design/

2. Ticketing tool with commit-message conventions?
   (Linear / ClickUp / Jira / none / unstructured)
   → Affects: opening `/<prefix>-ship` command
   → Template: workflow-templates/ship/

3. Cross-package PR frequency?
   (PRs spanning ≥3 packages: routine / occasional / rare)
   → If routine: open `/<prefix>-plan` command
   → Template: workflow-templates/plan/

4. Parallel-implementation pattern?
   (PRs routinely split into ≥2 disjoint chunks worth parallel implementation: yes / no)
   → If yes: open `/<prefix>-team` command
   → Template: workflow-templates/team/
```

#### Domain-auditor-affecting integrations (separate concern)

These DO leave repo artefacts and can be inspected:

| Integration | Inspectable signal | Affects |
|-------------|-------------------|---------|
| RevenueCat / App Store Connect | `purchases_flutter` in pubspec / IAP service files | Domain auditor candidate (IAP / paywall) |
| Supabase (RLS) | `supabase/migrations/` / Supabase client | Domain auditor candidate (security) |
| Firebase (Firestore rules) | `firestore.rules` / `database.rules.json` | Domain auditor candidate (rules) |
| Sentry / Crashlytics | `sentry_flutter` / `firebase_crashlytics` in pubspec | Auditor concern; no separate command |

These domain-auditor candidates still require Phase 0.8 "recent incidents" before opening a fifth agent — see [agent-roster.md](agent-roster.md) §"When to add a domain auditor".

#### Output of 0.4

A small table per affirmative user-prompt answer mapping to a template bundle to copy in Phase 3. Per negative answer → §"Rejected alternative" entry to populate in Phase 2 with reversal criterion ("reopen when team adopts <tool>").

### 0.5 MCP servers

List MCPs **actually installed** for this repo or user-globally:

- Dart MCP (`dart-mcp`, project-named like `jolly-dart`, `bp-dart`)
- Chrome DevTools / browser-testing MCP
- paper.design MCP
- ClickUp / Linear MCP
- Sentry MCP
- Custom project MCPs

> "Don't reference an MCP server that isn't installed. Listing permissions for a server that isn't installed pollutes the allowlist; agent prompts referencing absent tools confuse the model." — utopia-ai-arch SKILL.md non-negotiables

### 0.6 Codegen surface

Determines:

- The hook's **hard-block extensions list** in `<prefix>_quality_check.sh`
- The build_runner / codegen command surfaced in the hook's remediation hint
- Generated-file paths the precommit-auditor must verify are in sync with their sources

| Codegen tool | Extensions to hard-block | Regen command |
|--------------|--------------------------|---------------|
| `build_runner` (freezed, json_serializable, retrofit, route) | `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart` | `dart run build_runner build --delete-conflicting-outputs` |
| `protoc` / `protoc_plugin` | `*.pb.dart`, `*.pbenum.dart`, `*.pbjson.dart` | `./scripts/gen-proto.sh` (project-specific) |
| `easy_localization` / `slang` | `*.g.dart` (localization) | project-specific |
| Server-side TS codegen (Prisma, drizzle-kit) | Varies (`*.generated.ts`) | project-specific |

### 0.7 Toolchain canon (FVM yes/no — binary)

> "Pick one form and apply it everywhere — no `cmd / fvm cmd` slashes, no per-file if/else. Either the repo uses FVM or it doesn't; the answer is binary. Bare-toolchain ambiguity (bash resolving against whatever `$PATH` exposes) has bitten teams before — this section exists to short-circuit that." — blueprint `README.md:283-289`

**Detection checklist (do all four — single-check inference is the wave-2 smoke regression):**

```bash
# 1. .fvmrc at repo root (the canonical marker)
ls -la .fvmrc 2>/dev/null

# 2. .fvm/ directory (older FVM layout)
ls -la .fvm/ 2>/dev/null

# 3. fvm references in repo-level docs (README, CONTRIBUTING)
grep -l "fvm " README.md CONTRIBUTING.md docs/*.md 2>/dev/null

# 4. fvm references in CI / build scripts
grep -rl "fvm " .github/ scripts/ Makefile 2>/dev/null
```

**Any one of these positive → FVM=yes.** If `.fvmrc` exists but checks 3/4 are empty, FVM is still the canon (the file pins the version). If `.fvmrc` absent BUT docs reference `fvm`, the repo intends FVM but isn't bootstrapped — still treat as FVM=yes and surface the missing `.fvmrc` as a follow-up.

If all four are empty → bare `dart` / `flutter`.

**Once decided, propagate binary choice everywhere:** agents (`bp-maintainer.md` tool references), slash commands (`/<prefix>-implement` baseline step), `<prefix>_quality_check.sh` remediation hint, `permissions.allow` Bash patterns, `CLAUDE.md` Common Commands table, `tlumu/SKILL.md` Non-negotiables. **No alternation.** This was a wave-2 smoke regression — the agent inferred FVM=no from glancing at one indicator; FVM was actually present.

### 0.8 Recent incidents (if any)

Any production incidents (crypto bug, data leak, paywall regression, accidental commit of secrets) in the last N months are **direct evidence** for adding a domain auditor and / or a path nudge in the hook. Document them; they justify decisions the standard four-agent roster otherwise can't.

## Phase 1 — Design the skill split

The irreducible architectural exercise. Sit with the topology from Phase 0 and decide what coherent bodies of knowledge live where.

For each candidate skill, write:

- **POSITIVE applicability** — explicit paths / file types / surfaces
- **NEGATIVE applicability** — explicit paths / surfaces this skill does NOT cover (point to sister skills or foundation)
- **Granularity rationale** — one sentence: why this is one skill, not two; why this is two skills, not one

If you can't write the negative scope, the skill is trying to be a router — split or merge until each has a real boundary.

> "If you can't write the negative scope, the skill is trying to be a router — split or merge until each skill has a real boundary." — blueprint `README.md:388-390`

### Decide primitive sister skills

A "primitive" skill = SKILL.md with no `references/` content yet. Open one ONLY when:

- A distinct techstack lives in the repo (e.g. Cloud Functions in TypeScript alongside Dart)
- AND there's a `.claude/refs/<contract>.md` that needs a logical owner OR the techstack will accumulate Claude work soon

Otherwise **defer** — document the decision in `claude-architecture.md` §"Rejected alternatives" with a reversal criterion. See [skill-design.md](skill-design.md) "Don't preempt with primitive skills".

Precedent (tlumu): `tlumu-functions` opened as primitive because Cloud Functions is a distinct runtime; `tlumu-landing` deferred because no active Claude-driven landing work and no concrete content.

### Identify cross-cutting Dart content destined for `.claude/refs/`

Content that applies across ≥2 sister skills (proto naming, env-config tables, design-token contracts) does NOT belong inside one skill's `references/`. Lift it to `.claude/refs/<shared>.md`, linked from each consuming `SKILL.md`'s "See also". See [layer-model.md](layer-model.md) and [skill-design.md](skill-design.md).

## Phase 2 — Draft `claude-architecture.md` FIRST

**Before any other files.** Drafting the decision log *after* the files exist makes it narrate decisions you already made — it doesn't decide them. Drafting it first forces you to write down the rationale before you commit to the substitution.

Required sections (see [architecture-doc.md](architecture-doc.md) for the full 9-section spine):

1. **Two layers** — foundation (utopia-hooks) vs project; cross-link contract
2. **Skill split** — table of skills with POSITIVE / NEGATIVE applicability and granularity rationale
3. **Reference styles in use** — which skills have module / pattern / cheatsheet refs (or none yet)
4. **Agent roster** — the four; any domain auditor with documented incident / threat justification
5. **Enforcement mode** — hard-block list (generated files); default warn vs block
6. **Slash commands** — three base; any project-specific (`/<prefix>-plan`, `/<prefix>-team`, `/<prefix>-design`, `/<prefix>-ship`) with rationale
7. **Hook scope** — path patterns, basename guard, foundation-hook coexistence
8. **Rejected alternatives** — pre-populate with the perennials:
   - Monolithic single skill covering all techstacks
   - Per-area maintainers
   - `<prefix>-shared/` skill
   - `git push` guard hook
   - Hygiene / doc-drift / eng-manager agents
   - Domain auditor (only as rejection if you didn't add one)
   - Open primitive sister skills preemptively (for ones you deferred)
   - Move authoring conventions into `.claude/` (vs link to blueprint)
   - Assume an MCP server that isn't installed
9. **Rollout status** — the 7-step checklist below, all empty initially

Plus two paragraphs threaded into the spine (not separate numbered sections — they anchor inside §4 / §5 / §7 / §8 depending on how the repo couples them; see [architecture-doc.md](architecture-doc.md) §"Toolchain canon" and §"MCP assumption"):

- **Toolchain canon** — one paragraph: FVM yes/no decision, applied everywhere. Record as fact, not a chosen design.
- **MCP assumption** — for Dart projects: which MCP server (if any) is assumed installed; fallback command; `analyze` authoritative source called out (MCP `analyze_files` may miss errors). For repos with no MCP, this is a one-sentence explicit non-assumption.

> "The Rejected alternatives section pays for itself." — blueprint `README.md:299-301`

The 4-field entry shape (`Alternative` / `Case for` / `Case against here` / `Reversal criterion`) with worked examples lives in [architecture-doc.md](architecture-doc.md) §"Rejected alternatives — 4-field shape". Pre-populate at least the perennials listed above; you can sharpen later.

## Phase 3 — Copy and substitute

Working from the inline templates at [`../templates/`](../templates/), copy file **shapes** — never the files verbatim. The full template-to-target map with substitution columns is in [`../templates/TEMPLATES.md`](../templates/TEMPLATES.md); read it before the first `cp`.

### Files that come over (with substitution)

```
<repo-root>/CLAUDE.md                                ← templates/CLAUDE.md
<repo-root>/AGENTS.md                                ← symlink to CLAUDE.md (created in Phase 6)
<repo-root>/.claude/docs/claude-architecture.md      ← (drafted in Phase 2; written now using templates/claude-layer/docs/claude-architecture.md as the section spine)
<repo-root>/.claude/settings.json                    ← templates/claude-layer/settings.json
<repo-root>/.claude/agents/<prefix>-architect.md
<repo-root>/.claude/agents/<prefix>-maintainer.md
<repo-root>/.claude/agents/<prefix>-reviewer.md
<repo-root>/.claude/agents/<prefix>-precommit-auditor.md
<repo-root>/.claude/agents/<prefix>-<domain>-auditor.md  ← only if Phase 0.1 said yes
<repo-root>/.claude/commands/<prefix>-implement.md
<repo-root>/.claude/commands/<prefix>-audit.md
<repo-root>/.claude/commands/<prefix>-audit-skills.md
<repo-root>/.claude/commands/<prefix>-<extra>.md      ← only project-specific extras (Phase 0.4)
<repo-root>/.claude/scripts/<prefix>_quality_check.sh
<repo-root>/.claude/scripts/<prefix>_skills_drift.sh
<repo-root>/.claude/skills/<prefix>-<area>/SKILL.md   ← one per skill from Phase 1
<repo-root>/.claude/refs/                             ← empty directory, populated as needs emerge
```

### Substitutions to run

Mechanical sed replacements (be selective — do **not** run inside `.git/`):

| Find | Replace | Notes |
|------|---------|-------|
| `<repo>` | project prefix lowercase (`bp`, `jolly`, `tlumu`) | in body text and file paths |
| `<REPO>` | project prefix uppercase | env var: `<REPO>_QUALITY_MODE` → `JOLLY_QUALITY_MODE` |
| `<project name>` | human-readable name ("Black Phone", "Jolly Phonics Apps", "Madrosc Tlumu") | in `CLAUDE.md` title |
| `REPO-AREA` in skill path | first concrete area name (e.g. `bp-flutter`, `jolly-flutter`, `tlumu`) | skill directory rename |
| `<repo-folder-name>` in hook | actual repo directory basename | basename guard — load-bearing, see Phase 7 |

> **Prefix ≠ repo-folder-name.** They are independent and frequently differ. `qbt-black-phone` (repo folder) uses `bp` (prefix, for "Black Phone"). The **`<prefix>`** is the slug that appears in every artifact name (`<prefix>-architect`, `<prefix>_quality_check.sh`, `<prefix>-flutter`, `/<prefix>-implement`). The **`<repo-folder-name>`** is the on-disk basename ONLY used by the hook's `basename "$repo_root"` scope guard — it determines whether the hook fires in *this* workspace vs. an unrelated one with the same script path. If you substitute `<repo>` into the basename guard by mistake, the hook will silently never fire in the actual project. Verify post-substitution: open `<prefix>_quality_check.sh`, grep for the basename match, confirm it's the repo's directory name not the prefix.

### Strip blueprint banners

Every blueprint file carries a banner at the top:

```html
<!-- BLUEPRINT — adapt per-repo. Strip this banner after substitution. -->
```

or

```bash
# BLUEPRINT — adapt per-repo. Strip this banner after substitution.
```

> "Each blueprint file carries a banner at the top reminding the reader that it's a blueprint, not production. Once copied and adapted, the banner is stripped." — blueprint `README.md:669-672`

Strip them. They're a tell that the file is mid-bootstrap and confuse the agent if left in.

### Files NOT to copy (referenced from templates, never duplicated)

| Template file | Why not copied |
|---------------|----------------|
| `templates/README.md` | The blueprint model itself — read once, refer to it later; never duplicated |
| `templates/conventions/module-style.md` | Foundation-level authoring guide; linked from each repo's `claude-architecture.md` §3 |
| `templates/conventions/pattern-style.md` | Same |
| `templates/conventions/cheatsheet-style.md` | Same |
| `templates/claude-layer/refs/README.md` | Discipline doc for what goes in `.claude/refs/`; lives in the template |

> "Stays in the blueprint, never copied: `README.md` — read once, refer to it later; `conventions/{module,pattern,cheatsheet}-style.md` — referenced from `.claude/docs/claude-architecture.md` §3, not duplicated; `.claude/refs/README.md` — discipline doc; your repo's `.claude/refs/` is just the directory with content files as they're added." — blueprint `README.md:423-430`

If you need a `.claude/refs/` directory because the skill split already identified cross-skill content, create the directory and add the content files — but reference the blueprint's `README.md` from your `claude-architecture.md` §3, don't copy it.

## Phase 4 — Wire `.claude/settings.json`

Canonical shape (blueprint `.claude/settings.json`):

```json
{
  "extraKnownMarketplaces": {
    "utopia-claude-skills": {
      "source": {
        "source": "github",
        "repo": "Utopia-USS/utopia-flutter-skills"
      }
    }
  },
  "enabledPlugins": {
    "utopia-hooks@utopia-claude-skills": true
  },
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git fetch:*)",
      "Bash(git branch:*)",
      "Bash(git checkout:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git stash:*)",
      "Bash(gh pr view:*)",
      "Bash(gh pr list:*)",
      "Bash(gh pr diff:*)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_quality_check.sh\""
          }
        ]
      }
    ]
  }
}
```

**Three critical points:**

1. **`git push` is deliberately omitted** from `permissions.allow`. Every push prompts the user. Branch protection on `main` / `staging` covers the remote. No `PreToolUse` push-guard hook — two layers already cover it. See [enforcement-hooks.md](enforcement-hooks.md) and the rejected-alternative in [architecture-doc.md](architecture-doc.md).
2. **`enabledPlugins` declares the foundation at project scope** — the repo travels with the requirement. Contributors get prompted to install on first open.
3. **The `PostToolUse` hook references the project script.** Foundation hook fires alongside (project scope), guarded by their own scope checks.

For projects with MCP servers from Phase 0.5, add `enabledMcpjsonServers` and any tool-specific `permissions.allow` lines. **Do NOT add MCP permissions for servers not installed.** See [settings-json.md](settings-json.md) for the full shape.

## Phase 5 — Trim `CLAUDE.md`

Open the copied `CLAUDE.md` (blueprint shape) and fill in the per-repo content. Keep tight — this is the always-loaded inventory, not deep content.

The canonical full skeleton (sections, agent table, slash-command table, hooks block) lives in [claude-md.md](claude-md.md) §"Full CLAUDE.md skeleton" — read it once and fill per Phase 0.1–0.8 results. Substitutions from Phase 3 still apply (`<repo>`, `<REPO>`, `<project name>`, `<repo-folder-name>`).

## Phase 6 — Symlink `AGENTS.md → CLAUDE.md` and commit

```bash
cd <repo-root>
ln -s CLAUDE.md AGENTS.md
git add CLAUDE.md AGENTS.md .claude/
git commit -m "Set up .claude/ layer (project AI architecture)"
```

**Verify it's a symlink, not a copy:**

```bash
ls -la AGENTS.md
# Expected: lrwxr-xr-x ... AGENTS.md -> CLAUDE.md
```

If `AGENTS.md` shows as a regular file `(-rw-r--r--)`, re-create: `rm AGENTS.md && ln -s CLAUDE.md AGENTS.md`.

Why symlink (not copy, not hard link), Windows-contributor gotcha, and the verified-in-production `ls -la` output across `jolly-phonics-apps`, `madrosc-tlumu`, and `qbt-black-phone` (where the symlink rotted into a copy): see [claude-md.md](claude-md.md) §"The AGENTS.md symlink".

## Phase 7 — Validate

Trigger each rule the layer encodes with a throwaway edit, then revert. Catches the silent bootstrap omissions (missing basename guard, foundation hook not enabled, MCP perms for absent servers).

### 7.1 Trigger each hook rule

- **Generated-file edit:** open `<some>.g.dart`, try to add a blank line, save. Hook must exit 2 ("BLOCK — attempted edit to generated file"). Revert.
- **Relative import:** in a `lib/` Dart file, change `package:foo/bar.dart` → `../bar.dart`, save. Hook nudge fires (mode-dependent: warn or block).
- **Path nudge:** edit a file in a directory the hook nudges for (e.g. `<area-1>/lib/foo.dart`). The nudge ("consult `<prefix>-<area-1>`") must appear in stderr.

### 7.2 Verify the foundation hook fires alongside

`pubspec.yaml` must declare `utopia_hooks` or `utopia_arch` for the foundation hook to consider the workspace in scope. Add a hook idiom violation (relative widget reference, `TextEditingController` not from hook) and confirm both hooks fire.

### 7.3 Run the drift checker

```bash
bash .claude/scripts/<prefix>_skills_drift.sh --all
```

Or `/<prefix>-audit-skills`. Should report clean — every link in newly-written `CLAUDE.md`, agents, commands, and skills resolves. Broken links here are almost always typos in cross-references between agent files and command files.

### 7.4 Verify the symlink in the editor

Open `CLAUDE.md` in IntelliJ (or `code AGENTS.md` in VS Code). Make a no-op edit and save. Opening `AGENTS.md` separately should show the same content. If they diverge, the symlink isn't working — back to Phase 6.

### 7.5 Trigger description matching

Ask Claude in a fresh session: "review this code change in `<area-1>`". The correct sister skill (`<prefix>-<area-1>`) should auto-load via description matching. If a sister skill loads for a path it shouldn't apply to, the POSITIVE / NEGATIVE applicability is mis-stated — tighten the description.

### 7.6 Update §"Rollout status"

In `.claude/docs/claude-architecture.md` §"Rollout status", check each step done. Example (tlumu):

> "1. Foundation wiring — done. 2. Skeleton — done. 3. Enforcement — done. 4. Agents — done. 5. Skills — `tlumu` has `game-flow-module.md` … 6. CLAUDE.md trim — done. 7. Validation — `bash .claude/scripts/tlumu_skills_drift.sh --all` passes." — `madrosc-tlumu/.claude/docs/claude-architecture.md:156-163`

## Validation checklist

Run through every bullet. Each maps to a bootstrap mistake observed in practice or a drift mode catalogued in [evolution-and-drift.md](evolution-and-drift.md).

- [ ] `pubspec.yaml` declares `utopia_hooks` or `utopia_arch` — foundation hook fires for this project
- [ ] `.claude/settings.json` `permissions.allow` **omits `git push`** — push prompts the user every time
- [ ] `.claude/settings.json` `enabledPlugins` includes `utopia-hooks@utopia-claude-skills`
- [ ] `.claude/settings.json` does NOT declare MCP servers that aren't installed (no `mcp__<phantom>__*` permissions)
- [ ] All four agent files have `model: inherit` in frontmatter (cost-portable across Opus / Sonnet)
- [ ] All four agent files preload `[<prefix>-<master-skill>, utopia-hooks]` in `skills:` frontmatter
- [ ] Maintainer's frontmatter **omits `tools:`** → defaults to write-enabled. All other agents have `tools: Read, Grep, Glob, Bash` (read-only)
- [ ] `<prefix>_quality_check.sh` exits 2 on generated-file edits regardless of `<REPO>_QUALITY_MODE` value
- [ ] `<prefix>_quality_check.sh` has the **basename guard** — `[[ "$(basename "$repo_root")" == "<repo-folder-name>" ]] || exit 0` — preventing it from firing in unrelated workspaces (see blueprint `REPO_quality_check.sh:79`)
- [ ] `<prefix>_quality_check.sh` path nudges mirror each skill's POSITIVE applicability from `claude-architecture.md` §2 exactly
- [ ] `AGENTS.md` is `ls -la`-confirmed as a symlink (`lrwxr-xr-x ... -> CLAUDE.md`), not a regular file
- [ ] `.claude/docs/` and `.claude/refs/` are **different directories with different purposes** — content for the agent vs meta about the layer
- [ ] `.claude/docs/` contains `claude-architecture.md` (decision log) and optionally `_module-template.md` (authoring helper) — nothing else loaded as guidance
- [ ] `.claude/refs/` contains only cross-skill markdown linked from ≥2 `SKILL.md` "See also" sections
- [ ] `CLAUDE.md` "Skills inventory" table matches the directories under `.claude/skills/` — no skills described that don't exist, no skills present that aren't described
- [ ] `CLAUDE.md` "Agents" table matches the files in `.claude/agents/` — no agents described that don't exist, no agents present that aren't described
- [ ] `CLAUDE.md` "Slash commands" table matches the files in `.claude/commands/`
- [ ] `claude-architecture.md` §"Rollout status" has all 7 steps checked
- [ ] `claude-architecture.md` §"Rejected alternatives" has entries for at least: monolithic skill, per-area maintainers, `<prefix>-shared/`, `git push` guard hook (plus whatever else Phase 0 raised and rejected)
- [ ] `claude-architecture.md` §"Toolchain canon" records the FVM yes/no decision in one short paragraph
- [ ] All command files have an `allowed-tools:` line scoped to the **minimum** needed (`/<prefix>-audit` should be `Task` only — see [slash-commands.md](slash-commands.md))
- [ ] All blueprint banners (`<!-- BLUEPRINT … -->`, `# BLUEPRINT …`) stripped from copied files
- [ ] No file references an MCP server that isn't in `enabledMcpjsonServers` or installed user-globally

## Common pitfalls during bootstrap

### Copying blueprint files verbatim

❌ `cp -r utopia-ai-arch:templates/claude-layer <repo>/.claude` and committing without substitution.

The blueprint is the model. You must:
- Strip banners
- Substitute `<repo>` / `<REPO>` / `<project name>` / `<repo-folder-name>`
- Adapt skill applicabilities and path nudges to **your** topology
- Skip files explicitly marked "stays in blueprint" (`README.md`, `conventions/*`, `.claude/refs/README.md`)

### Mass-applying `sed` substitutions in places they shouldn't run

❌ `find . -type f -exec sed -i 's/<repo>/foo/g' {} +` — runs inside `.git/`, mangles object files, breaks the repo.

Use a scoped invocation:
```bash
find .claude/ CLAUDE.md AGENTS.md -type f \( -name '*.md' -o -name '*.sh' -o -name '*.json' \) \
  -exec sed -i '' 's/<repo>/foo/g' {} +
```

Or run each substitution per-file deliberately.

### Opening primitive sister skills preemptively

❌ Creating `<prefix>-functions/`, `<prefix>-landing/`, `<prefix>-admin/` all on day 1 because the topology has those workspaces.

Defer until each has either (a) real Claude work happening or (b) a `.claude/refs/<contract>.md` that needs a logical owner. Document the deferral in `claude-architecture.md` §"Rejected alternatives" with a reversal criterion. See [skill-design.md](skill-design.md) "Don't preempt with primitive skills".

### Forgetting the basename guard in the hook

❌ Removing or omitting the line:
```bash
[[ "$(basename "$repo_root")" == "<repo-folder-name>" ]] || exit 0
```

Without this guard, `<prefix>_quality_check.sh` fires whenever the user edits a Dart file in **any** repo that happens to be in the directory tree above — sister workspaces, vendored dependencies, anything that walks up to a `.git`. The basename guard proves "we're in THIS repo" before doing anything. Load-bearing.

### Hard-coding `fvm` vs bare-dart inconsistently across files

❌ Agents say `fvm dart analyze`, commands say `dart analyze`, scripts say `fvm flutter test`. Bash resolves against `$PATH`; one form works on the dev's machine, the other fails on CI.

Toolchain canon is a binary choice (Phase 0.7). Pick once, apply everywhere — agents, commands, scripts, `permissions.allow`. No alternation slashes.

### Declaring MCP servers in permissions that aren't installed

❌ Copying the blueprint's MCP permissions across without checking which MCP servers this repo actually uses.

> "Don't reference an MCP server that isn't installed. Listing permissions for a server that isn't installed pollutes the allowlist; agent prompts referencing absent tools confuse the model." — utopia-ai-arch SKILL.md

Phase 0.5 inventoried the MCPs. The settings.json reflects exactly that, no more.

### Skipping the symlink verification

❌ Trusting that `ln -s` worked without `ls -la`.

If `AGENTS.md` ends up as a regular file (because the Phase 6 command ran in the wrong directory, or because of a Windows checkout), the two files drift silently. Verify with `ls -la AGENTS.md`.

## Anti-patterns

### Bootstrapping without Phase 0

Flying blind. The skill split, agent roster, command set, and hook scope are all functions of facts gathered in Phase 0 (topology, stacks, integrations, codegen, toolchain, incidents). Skipping it means retrofitting the architecture doc to whatever you typed first — exactly the failure mode `claude-architecture.md` exists to prevent.

### Drafting `claude-architecture.md` AFTER the files exist

❌ Writing the agents and skills first, then "writing up" what you did.

The decision log narrates, doesn't decide. The rejected alternatives section in particular goes missing — you can't enumerate alternatives you didn't consider because you didn't pause to consider. Phase 2 forces the decision before the substitution.

### Skipping validation

❌ "It compiles, the files are there, ship it."

Every drift mode in [evolution-and-drift.md](evolution-and-drift.md) has a validation step that would have caught it at bootstrap time. The hook firing in unrelated workspaces, the symlink-that's-a-copy, MCP perms for absent servers, the primitive skill that fires wrongly because the description over-broadens — all silent until production, all catchable in Phase 7.

### "We'll add the §Rejected alternatives later"

The dominant `claude-architecture.md` failure mode. Future-you re-proposes per-area maintainers, the `<prefix>-shared/` skill, the push-guard hook because the deliberate omission isn't documented. Write them at Phase 2 or you'll re-litigate the same dead-ends.

> "The Rejected alternatives section pays for itself. It's why future-you doesn't re-litigate decisions, and why someone new can tell a deliberate omission from an oversight." — blueprint `README.md:299-301`

### Copying authoring conventions into `.claude/`

❌ Copying `conventions/{module,pattern,cheatsheet}-style.md` from the blueprint into `<repo>/.claude/docs/`.

The conventions are foundation-level — how *any* project's reference docs are authored, not per-repo. Duplicating them invites drift. Cross-link from `claude-architecture.md` §3 to the blueprint path.

> "The conventions are foundation-level (how *any* project's reference docs are authored), not Tlumu-specific. Duplicating them invites drift. Skills that need them link to the blueprint path explicitly." — `madrosc-tlumu/.claude/docs/claude-architecture.md:136-137`

### Treating the blueprint as a template

The blueprint is a model. Templates produce a finished thing from a substitution map; models require you to make decisions the substitution can't make for you. Skill split is the most obvious case — no `sed` can decide whether your Cloud Functions workspace warrants a primitive skill now or deferral.

## See also

- [layer-model.md](layer-model.md) — foundation vs project; what `.claude/` even contains
- [agent-roster.md](agent-roster.md) — the four blueprint agents; when to add a fifth (Phase 0.1 driver)
- [skill-design.md](skill-design.md) — applicability scope discipline; primitive sister skill criteria (Phase 1)
- [enforcement-hooks.md](enforcement-hooks.md) — `<prefix>_quality_check.sh` shape, guards, generated-file block; `<prefix>_skills_drift.sh` (Phase 7.3)
- [settings-json.md](settings-json.md) — canonical settings shape (Phase 4)
- [claude-md.md](claude-md.md) — `CLAUDE.md` inventory shape (Phase 5); AGENTS.md symlink (Phase 6)
- [architecture-doc.md](architecture-doc.md) — 9-section spine for `claude-architecture.md` (Phase 2)
- [slash-commands.md](slash-commands.md) — three base commands + criteria for project-specific extras (Phase 0.4)
- [evolution-and-drift.md](evolution-and-drift.md) — once bootstrapped, the playbook for evolving the layer; catalogue of bootstrap-time omissions that surface later (validation greps target these)
- Inline templates: [`../templates/`](../templates/) + [`../templates/TEMPLATES.md`](../templates/TEMPLATES.md) (target-path + substitution map)
- Production precedents:
  - qbt: `qbt-black-phone/.claude/` (with `bp-security-auditor`, `/bp-plan`, `/bp-team`)
  - jolly: `jolly-phonics-apps/.claude/` (with `/jolly-design`, `/jolly-ship`)
  - tlumu: `madrosc-tlumu/.claude/` (smallest, baseline four agents, three base commands)
