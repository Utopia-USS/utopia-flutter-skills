---
title: Initial Setup — Walkthroughs for Bootstrap Decisions
impact: HIGH
tags: bootstrap, walkthrough, skill-split, workflow-skills, refs-placement, path-nudges, sister-skill
---

# Initial Setup — Walkthroughs for Bootstrap Decisions

## What this is

Scenario walkthroughs for the **decisions** you make while applying [bootstrap-procedure.md](bootstrap-procedure.md). The procedure tells you the 7 phases; this file tells you **HOW to make the calls** at the points inside Phase 0–3 that tend to go wrong.

Each walkthrough has the same 5 elements: **concrete trigger**, **ordered reference sequence**, **per-step extraction** (which §section to consult, not just the file), **at least one decision point**, **concrete deliverable + validation**.

Use this file if [bootstrap-procedure.md](bootstrap-procedure.md) feels abstract — the walkthroughs below put concrete shape on the decisions it expects.

## When this applies

- Bootstrapping a new repo's `.claude/`
- Auditing an existing layer for missing or wrong skill / agent / command decisions
- A new techstack joins an established repo
- A new MCP / external integration arrives
- Reviewing a proposed split / collapse / addition mid-project

## Walkthrough catalogue

| # | Scenario | Triggered by | Failure mode it prevents |
|---|---|---|---|
| [A](#walkthrough-a--add-a-sister-skill) | Add a sister skill | "Add a skill for techstack X" | Skill without positive+negative scope, missing architecture-doc entry, missing CLAUDE.md row |
| [B](#walkthrough-b--decide-the-skill-split) | Decide the skill split | Bootstrap, new techstack, "is our split right?" | Wrong granularity — smoke-test tlumu over-deferred everything |
| [C.1 + C.2](#walkthrough-c--workflow-style-skills) | Workflow-style skills (browser-testing class + design/ship/plan/team) | Bootstrap, new MCP integration, Phase 0.5 user-prompt | Missing repo-agnostic tooling skills — smoke-test tlumu skipped `browser-testing` (C.1 closes); information-leak false-positive opens (C.2 separates user-driven from auto-inspectable) |
| [D](#walkthrough-d--what-goes-in-claude-refs-vs-in-a-skill) | `.claude/refs/` vs skill placement | Writing cross-cutting content; auditing accumulated master refs | Cross-cutting content stuck in master skill (qbt's pre-cleanup `bp/references/`) |
| [E](#walkthrough-e--wire-path-nudges) | Wire path nudges as references accumulate | Bootstrap (initial wiring), new references landing | Single-nudge hook vs production 4–8 — smoke-test tlumu had 1 nudge vs actual 6 |

## Walkthrough A — Add a sister skill

**Trigger:** *"Add a sister skill for techstack X in `<workspace>/`."*

**Sequence:**

1. **Decide whether to open it now** → [skill-design.md](skill-design.md) §"Primitive sister skill". Criterion: distinct techstack AND (≥2 references' worth of content OR a logical owner for a `.claude/refs/<shared-doc>.md`). If **no**, **defer** and add a §"Rejected alternative" entry with reversal criterion. If **yes**, continue.
2. **Write `<prefix>-<area>/SKILL.md`** → copy [`../templates/claude-layer/skills/REPO-AREA/SKILL.md`](../templates/claude-layer/skills/REPO-AREA/SKILL.md); `sed "REPO-AREA" -> "<prefix>-<area>"`; fill `description:` with POSITIVE + NEGATIVE applicability per [skill-design.md](skill-design.md) §"Applicability"; write "Relationship to the foundation" table acknowledging if the techstack is foundation-silent (Kotlin doesn't touch `utopia-hooks` at all; TS Cloud Functions don't either).
3. **Append to `claude-architecture.md` §"Skill split"** → one row per [architecture-doc.md](architecture-doc.md): `<prefix>-<area> | <positive> | NOT <negative> | <granularity rationale>`.
4. **Update `CLAUDE.md`** → row in §"Skills" inventory + row in §"When to Invoke" routing per [claude-md.md](claude-md.md).
5. **Defer the hook path nudge** → don't extend `<prefix>_quality_check.sh` until the new skill accumulates ≥2 references. See [enforcement-hooks.md](enforcement-hooks.md) §"The rule for adding a nudge". When references land later, run [Walkthrough E](#walkthrough-e--wire-path-nudges).
6. **Validate** → `bash .claude/scripts/<prefix>_skills_drift.sh --all` returns clean; [drift-symptoms.md](drift-symptoms.md) grep one-liners catch nothing new.

**Deliverable:** one new `SKILL.md` + two inventory updates (`CLAUDE.md`, `claude-architecture.md`) + one decision-log row. **~30 min first-time, ~10 min familiar.**

---

## Walkthrough B — Decide the skill split

**Trigger:** bootstrap, audit "is our split right?", or new techstack joining the repo.

**Sequence:**

1. **Inventory techstacks** → per workspace, list language × framework. Example raw inventories:
   - jolly: `classroom/` Flutter, `lessons/` Flutter, `core/` Dart lib, `classroom-api/` Kotlin Ktor, `classroom-distributors/` Next.js TS
   - tlumu: `packages/{app,admin,core,tools}/` Flutter, `functions/` TS Firebase, `packages/landing/` Next.js
2. **Per stack apply the applicability litmus** → [skill-design.md](skill-design.md) §"Positive AND Negative applicability". The test: can you write a one-line **NEGATIVE** scope? If not, the stack merges with its neighbour.
3. **Classify each stack into one of four buckets:**
   | Bucket | Criteria | Action |
   |---|---|---|
   | **Master** (Dart Flutter usually) | The dominant techstack; majority of code | Open as `<prefix>` or `<prefix>-<dominant>` |
   | **Primitive sister** | Distinct techstack + ≥2 reference candidates OR logical owner for shared `.claude/refs/<contract>.md` | Open with full SKILL.md, minimal references |
   | **Deferred** | Distinct techstack but no content yet, no shared-contract owner | Document in §"Rejected alternatives" with reversal criterion |
   | **`.claude/refs/`-only** | Cross-cutting content with no own applicability surface | Place in `.claude/refs/`, link from each consumer's See also |
4. **Decision point — primitive vs deferred** → does the stack have a logical owner for a shared contract doc (jolly-api → `proto-contract.md` is the canonical precedent)? **Yes** → open primitive. **No** → defer with reversal criterion ("first non-trivial Claude work in this stack" or "first shared-contract doc").
5. **Decision point — Next.js / static landing surfaces** → never code-side skill. Precedent in **both** tlumu §8 and jolly §8: rejected alternative. Browser flows go to a workflow-style skill ([Walkthrough C](#walkthrough-c--workflow-style-skills)); code work happens out-of-band.
6. **Record the split** → `claude-architecture.md` §"Skill split" table (one row per skill with positive + negative + granularity rationale) + minimum 2 §"Rejected alternatives" entries for the deferrals.

**Deliverable:** populated §"Skill split" table + named deferrals with reversal criteria.

**Common mistakes this walkthrough prevents:**

- Over-deferring (smoke-test tlumu deferred `tlumu-functions` AND skipped opening `browser-testing` — actual tlumu has both).
- Under-splitting (qbt pre-cleanup had a monolithic `bp` swallowing Dart-cross-cutting content; now split into `bp` + `bp-security` + `.claude/refs/{freezed,components,tokens,code-generation}.md`).
- Opening a primitive without a contract owner — fires wrongly, agent loads it for files it can't act on.

---

## Walkthrough C — Workflow-style skills

Workflow-style candidates split into **two epistemic categories** with different decision procedures. **C.1 — auto-inspectable** (agent decides from observable repo facts). **C.2 — user-driven** (agent CANNOT decide from repo state; needs explicit signal from Phase 0.5 user-prompt or README mention). Confusing these two categories is the source of false-positive opens and false-negative rejects.

### C.1 — Auto-inspectable workflow skills

**Trigger:** bootstrap; the agent can determine the answer from repo files.

**Candidates and inspectable signals:**

| Skill | Inspectable signal | Production status |
|---|---|---|
| `browser-testing` | Any web build present — Flutter web target, admin web workspace, marketing landing, web-serving CLI | **All 3 repos** — qbt, jolly, tlumu |
| `<repo>-deployment` | Multi-component infra in repo — Docker compose + Caddy / sidecars / Vector / etc. Not single docker-compose. | Qbt only |
| `<repo>-cms` | Vendored CMS submodule (`packages/<cms-name>/` with its own `.git`) | Qbt only |

**Sequence:**

1. **Inspect repo** — grep for the signal (`find -name "docker-compose*"`, `git submodule status`, `grep -l "web:" pubspec.yaml`).
2. **Per signal-yes** → consult [skill-design.md](skill-design.md) §"Workflow-style skills" for SKILL.md shape, then copy from [`../templates/workflow-templates/<bundle>/`](../templates/workflow-templates/) (each bundle has its own README + skill/command files).
3. **Per signal-no** → §"Rejected alternative" entry with reversal criterion ("reopen when web target appears" / "reopen when docker-compose enters repo").

**Deliverable:** for each candidate either open (with copied template) OR rejected-alternative entry.

### C.2 — User-driven workflow templates (NOT auto-inspectable)

**Trigger:** bootstrap; Phase 0.5 user-prompt result indicates the team uses a tool whose presence does NOT show in repo state.

**These workflows depend on team practice, not code.** The agent CANNOT determine them from repo files. The fact that no `paper.design` MCP is currently installed does NOT mean the team isn't planning to use it; the fact that there's no `.linear-config` doesn't mean the team isn't on Linear.

**Candidates and user-prompt signals:**

| Workflow | Phase 0.5 prompt | Bundle shape | Production precedent |
|---|---|---|---|
| `<repo>-design` | "Do you use a design tool MCP or handoff bundle (paper.design / Figma / claude.design)?" | **Skill + command pair** — skill teaches consuming designs, command orchestrates design → code loop | Jolly only |
| `<repo>-ship` | "Do you use a ticketing tool (Linear / ClickUp / Jira) with commit-message conventions?" | Command-only — pure orchestration | Jolly only |
| `<repo>-plan` | "Do PRs frequently span 3+ packages (cross-package planning worth a discrete invocation)?" | Command-only — architect-only flow | Qbt only |
| `<repo>-team` | "Do PRs routinely split into 2+ disjoint chunks worth parallel implementation?" | Command-only — multi-maintainer orchestration | Qbt only |

**Sequence:**

1. **Phase 0.5 user-prompt** (from [bootstrap-procedure.md](bootstrap-procedure.md) §"Phase 0.5") returned answers — one yes/no per candidate.
2. **Per affirmative answer** → copy the bundle from [`../templates/workflow-templates/<bundle>/`](../templates/workflow-templates/). Skill+command pairs (`design`) install both files together; command-only bundles install one. Substitute `<prefix>` per [bootstrap-procedure.md](bootstrap-procedure.md) Phase 3 sed-table.
3. **Per negative answer** → §"Rejected alternative" entry with reversal criterion ("reopen when team adopts <tool>"). The template stays available in the upstream skill — no need to delete the rejection record when team later adopts; update it.
4. **Document workflow-style exception** in `claude-architecture.md` §3 "Reference styles in use" — call out which skills are workflow-style (not trichotomy).

**Deliverable:** for each candidate either open (with copied + substituted bundle) OR rejected-alternative entry with reversal criterion.

**Why the split matters:** in wave-2 smoke testing, the agent **correctly opened `browser-testing`** from inspecting Flutter web presence (C.1) but only **opened `<repo>-design` because the production CLAUDE.md mentioned paper.design** — information leak, not a real test. C.2 makes the user-prompt the gate, removes the leakage temptation, and provides the template as a copy-ready bundle when the user signal arrives.

**The smoke-test failures this prevents:** wave-1 tlumu init skipped `browser-testing` entirely (now caught by C.1 inspect step), AND skipped considering `<repo>-design` / `<repo>-ship` because the agent had no procedure for *asking* about them (now caught by C.2 prompt-driven gate).

---

## Walkthrough D — What goes in `.claude/refs/` vs in a skill

**Trigger:** writing content that "kinda applies everywhere"; or seeing one skill's `references/` accumulating cross-cutting content; or smoke-test catching the master-swallow drift symptom.

**Sequence:**

1. **Routing test** — is this content going to be consumed by **≥2 skills** (NOT ≥2 packages / workspaces)? Multiple packages inside the SAME skill's positive applicability are still "1 skill" — content stays in `<skill>/references/`. Cross-cutting trigger is "≥2 distinct skills with disjoint applicability scopes consume this". If **1 skill only** → it lives in that skill's `references/`. If **2+ distinct skills** → candidate for `.claude/refs/`.
2. **Foundation test** — is this content about Screen/State/View, hook idioms, IList/IMap/ISet, strict analyzer style, `useInjected`, `_providers`? If **yes** → foundation territory (`utopia-hooks`), don't write it at all. Per [layer-model.md](layer-model.md) §"Foundation concerns stay in foundation".
3. **Tool-output test** — does `dart format` / `dart fix` / the analyzer / `utopia_lints` enforce this deterministically? If **yes** → **delete**, rely on the tool. Per [drift-symptoms.md](drift-symptoms.md) symptom B (qbt deleted `imports-and-formatting.md` and `strict-analysis.md` for this reason).
4. **Decision point — cross-skill content placement** → if the content survives all three tests and applies to ≥2 skills, place it at `.claude/refs/<shared>.md`. **Cross-link from each consuming SKILL.md's `## See also` section, NOT buried in references.** Per [skill-design.md](skill-design.md) §"Cross-link discipline".
5. **Audit existing master skills** — if `<master>/references/` already has cross-cutting content (qbt's pre-cleanup `bp/references/freezed.md`, `codegen.md`, `strict-analyzer.md`, `imports-and-formatting.md`), **lift to `.claude/refs/`** OR delete (tool-output test). Update all consuming SKILL.md See also blocks. Record the operation in `claude-architecture.md` §"Rejected alternatives" — what was tried (uber-skill `references/`) and why it was reversed. Per [maintain-evolve.md](maintain-evolve.md) §"Splitting / collapsing content".

**Common `.claude/refs/` candidates:**

| Content | Lives in | Why |
|---|---|---|
| `freezed.md` / `code-generation.md` | `.claude/refs/` | Consumed by every Dart workspace |
| `proto-contract.md` | `.claude/refs/` | Consumed by Flutter + backend |
| `environments.md` (Firebase env table) | `.claude/refs/` | UI + backend + scripts all consume |
| `components.md` / `tokens.md` (design system) | `<prefix>/references/` | Consumed only by Flutter |
| `e2e-encryption.md` | sister `<prefix>-security/references/` | Consumed only by crypto paths |
| `imports-and-formatting.md` / `strict-analyzer.md` | NOWHERE | Tool enforces — delete |
| `IList/IMap/ISet` rules | NOWHERE | Foundation — don't write |

**Deliverable:** either a placed `.claude/refs/<shared>.md` (with See also links from each consumer) OR a justified deletion OR a foundation cross-link. Every choice recorded in `claude-architecture.md`.

---

## Walkthrough E — Wire path nudges

**Trigger:** bootstrap (initial wiring of `<prefix>_quality_check.sh`); or after new references land in a skill and the hook hasn't been extended yet.

**Sequence:**

1. **List all `.md` files** under `.claude/skills/*/references/` and `.claude/refs/`, grouping by **what paths they describe** (Flutter screen → `phone/lib/`, security pipeline → `core_messaging/lib/`, RTDB game state → `lib/service/room/`).
2. **Per cluster of ≥2 references** → identify the path glob that captures all consuming code. Multi-pattern globs are fine (`packages/dske/lib/src/ffi/*|core_messaging/lib/service/crypto*|core/lib/service/crypto/*`).
3. **Exact-match check** — the glob in the hook MUST match the owning skill's POSITIVE applicability from its `description:` frontmatter. If there's a mismatch, the wrong skill surfaces and the agent reads rules that don't apply. Per [skill-design.md](skill-design.md) §"Skill description that fires on the wrong files".
4. **Decision point — granularity** → one large case branch with many globs vs many small branches?
   - **Larger** is more readable in stderr (the agent reads one consolidated line, not five).
   - **Smaller** is correct if the references it surfaces are *genuinely different sets* per glob — e.g. UI paths surface `bp` design refs; crypto paths surface `bp-security` audit refs. Don't merge across skills.
   - Target maturity: **4–8 nudges in a mature hook**. A bootstrap hook with 0–1 nudges is fine; a 2-year-old hook with 1 nudge means references didn't accumulate (suggesting the skill is thin) or the hook hasn't been maintained.
5. **Substitute into `<prefix>_quality_check.sh` case/esac**. Verify the basename guard at the top of the script is still your **repo folder name**, not your **prefix** — the two CAN differ (qbt-black-phone → `bp`).
6. **Validate** with a throwaway edit in each target path — confirm stderr surfaces the correct skill + references. Run [drift-symptoms.md](drift-symptoms.md) grep one-liners to confirm no hook nudges point at primitive sister skills with no content (anti-pattern).

**Production examples for reference (typical mature granularity):**

| Repo | Nudges | Surfaces covered |
|---|---|---|
| qbt | 5+ | UI paths, state files, security-sensitive crypto/FFI paths, message_service, supabase migrations |
| jolly | 5 | Activity proto+UI, Crazy UI / classroom non-lesson, services, models, proto edits |
| tlumu | 6 | Game-flow RTDB paths, design-system, decks/trivia, services, models, IAP |

**Deliverable:** populated case/esac blocks in `<prefix>_quality_check.sh` + validation logs from throwaway edits.

---

## When to re-run a walkthrough

These are not bootstrap-only. Mid-project triggers to re-run:

| Walkthrough | Re-run when |
|---|---|
| A | Any new sister-skill proposal |
| B | New techstack joining; or smoke audit suggests collapse / split |
| C | New tool MCP installed; new external integration (Linear / Figma / etc.) |
| D | Master skill's `references/` count grows past ~8; or smoke audit finds cross-cutting accumulation |
| E | New references land in any skill (≥2 threshold crossed) |

Routing into these is one of the responsibilities of [maintain-evolve.md](maintain-evolve.md) — that file covers what triggers a re-read of `claude-architecture.md`; this file covers what to *do* with the result.

## See also

- [bootstrap-procedure.md](bootstrap-procedure.md) — the procedural backbone (Phase 0–7); these walkthroughs decorate decisions inside Phase 0–3
- [skill-design.md](skill-design.md) — the taxonomy (master / sister / primitive / workflow / `.claude/refs/`) these walkthroughs route to
- [drift-symptoms.md](drift-symptoms.md) — failure modes each walkthrough prevents (cross-referenced in the catalogue table at top)
- [enforcement-hooks.md](enforcement-hooks.md) — wiring details for Walkthrough E
- [maintain-evolve.md](maintain-evolve.md) — when to re-run each walkthrough mid-project
- [architecture-doc.md](architecture-doc.md) — `claude-architecture.md` is the artefact every walkthrough updates
- Inline templates: [`../templates/`](../templates/) + [`../templates/TEMPLATES.md`](../templates/TEMPLATES.md)
