---
title: Architecture Doc — The Per-Repo Decision Log
impact: HIGH
tags: architecture-doc, decision-log, rejected-alternatives, toolchain-canon, mcp, rollout-status
---

# Architecture Doc — The Per-Repo Decision Log

## What this is

`.claude/docs/claude-architecture.md` is the **brain of the project layer** — a per-repo decision log that records WHY each `.claude/` choice was made, what was rejected and on what criterion, what's been rolled out, and what tooling canon binds the repo. It is the only file in the project layer whose audience is **future-you and the next contributor**, not the agent.

> "Decisions live here; rationale is documented so that future-you (or a teammate) can tell a deliberate choice from an oversight, and knows what would flip the decision." — blueprint `.claude/docs/claude-architecture.md:6-8`

Without this doc, future-you re-litigates every decision the previous you settled. The agent roster grows by accretion. Rejected alternatives are proposed again. Per-area maintainers come back six months after being deleted. The Toolchain canon paragraph alone — one binary "FVM yes/no" choice, propagated everywhere — has paid for the doc twice over in repos that adopted it.

The doc is **a log, not a design document**. It does not narrate how the architecture works (the blueprint does that); it records the choices THIS repo made on top of that architecture. Deep design narrative belongs in `docs/architecture.md` at the repo root (repo-A's precedent — system topology, sequence diagrams, formal specs live there).

## When this applies

- **Bootstrapping a new repo.** Write this doc **first**, before any `.claude/skills/` or `.claude/agents/` files. The doc decides; the files narrate. Order reversed, the doc becomes a retroactive justification — by which point the choices are no longer choices.
- **Adding a skill** — append a row to §"Skill split" and §"Reference styles in use".
- **Adding an agent** — extend §"Agent roster"; if it's a domain auditor, the entry must carry incident or threat-surface rationale.
- **Adding a slash command** — note only the addition or omission relative to the 3-base in §"Slash commands".
- **Adding a path nudge in the hook** — extend §"Hook scope".
- **Recording a rejected alternative** — new entry in §"Rejected alternatives" using the 4-field shape.
- **Reversing a previously-rejected decision** — update the entry in place; **never delete it**. The history is the prevention.
- **Auditing the layer for drift** — re-read the doc; compare reality against §"Rollout status".

## The 9-section spine

Every architecture doc has these sections in this exact order. Reordering them silently teaches the agent (and future-you) that the structure is decorative; it isn't.

### §1 Two layers

Brief restatement of the foundation-vs-project model. Use an ASCII box diagram identical in shape to the blueprint's. Cross-link to [layer-model.md](layer-model.md) for the full model — do not restate.

Production shape (repoC):

```
+---------------------------------------------------------------+
|  Foundation — utopia-hooks plugin (marketplace, ambient)      |
|    Screen/State/View, hook catalog, async patterns, DI,       |
|    IList/IMap/ISet, strict analyzer, lambda style.            |
|    Repo-agnostic — knows nothing about RepoC.                 |
+---------------------------------------------------------------+
                         ▲ referenced, never duplicated
+---------------------------------------------------------------+
|  Project — this repo's .claude/                               |
|    Game flow (room/lobby/game/summary), decks, daily packs,   |
|    ...                                                        |
+---------------------------------------------------------------+
```

— `production-repo-C/.claude/docs/claude-architecture.md:11-25`. One closing sentence: "Project skills cross-link to foundation references; they never restate foundation content."

### §2 Skill split

The most-edited section. Table with these columns — **all four mandatory**:

| Skill | Positive applicability | Negative applicability | Granularity rationale |
|---|---|---|---|

**Both positive AND negative scopes required.** If you can't write the negative, the skill is a router-in-disguise — split or merge until each row has a real boundary. See [skill-design.md](skill-design.md) for the rule and the no-router prohibition.

Two compulsory closing paragraphs after the table:

```
**No router skill.** Routing is solved by:
- `CLAUDE.md` (always-on inventory + foundation pointer);
- `<prefix>_quality_check.sh` (deterministic path → skill nudge);
- per-skill `applicability` frontmatter (autonomous load).

**No cross-cutting "shared" skill.** Cross-skill snippets live in
`.claude/refs/`, linked from each consuming `SKILL.md`'s "See also".
```

Cross-link to [skill-design.md](skill-design.md).

### §3 Reference styles in use

Table — **which reference styles each skill employs**:

| Skill | Modules (`*-module.md`) | Patterns (`*-pattern.md` / `*-system.md` / `*-services.md` / `*-models.md`) | Cheat-sheets (`*-cheatsheet.md`) |
|---|---|---|---|

The columns mirror the three reference styles taxonomy. A skill with no entries in a column declares it doesn't use that style yet. Primitive skills show `(none yet — primitive)` — visible, deliberate (repoB precedent, `production-repo-B/.claude/docs/claude-architecture.md:53`).

Authoring conventions for each style are bundled inline with this skill at [`../templates/conventions/{module,pattern,cheatsheet}-style.md`](../templates/conventions/). **Link them from §3, never copy into the repo.** See §8 rejected-alternative "Move authoring conventions into `.claude/`" (repoB, repoC both rejected this for the same reason).

### §4 Agent roster

The standard four (`<prefix>-architect`, `<prefix>-maintainer`, `<prefix>-reviewer`, `<prefix>-precommit-auditor`) are always present. The section's job is to document **only what differs**.

**If the roster is exactly the standard four**, the section collapses to a single paragraph plus a 4-row table — like repoC:

```
Standard four, no domain auditor:

| Agent                     | Role                                              |
|---------------------------|---------------------------------------------------|
| `repoC-architect`         | Plans, splits work, identifies affected skills    |
| `repoC-maintainer`        | Implements plans across skills (write)            |
| `repoC-reviewer`          | Post-implementation classified review             |
| `repoC-precommit-auditor` | Staged-diff commit-readiness audit                |

Domain auditor candidates (deferred): Firestore/RTDB rules auditor (rules
edits are silent and can leak data), IAP/paywall auditor. Open until a
real incident motivates dedicated review.
```

— `production-repo-C/.claude/docs/claude-architecture.md:62-75`. The "candidates (deferred)" paragraph is load-bearing — it names the surfaces that *would* justify an auditor if an incident landed. Without it, the next person to propose `repoC-rules-auditor` has to rediscover the threat model.

**For each added auditor**, document: role, tools, when invoked, hand-offs, AND the incident or threat-surface rationale. Quote from repo-A (the precedent for adding one):

> "Plus one BP-specific domain auditor: `bp-security-auditor` (read-only) for the crypto / FFI / RLS surface — this is a per-repo addition the blueprint anticipates." — `production-repo-A/.claude/docs/claude-architecture.md:121`

Cross-link to [agent-roster.md](agent-roster.md) for the standard four's invariants and the criteria for adding a fifth.

### §5 Enforcement mode

Three bullets, no prose:

```
- **Hard block** (always exit 2): edits to <generated extensions for THIS repo>.
- **Default**: `warn` (exit 1) on path-match nudges and convention violations.
- `block` (exit 2) is switchable via `<PREFIX>_QUALITY_MODE=block`.
```

The generated-extensions list is **per-repo**. RepoC has `.freezed.dart`, `.g.dart`, `.config.dart`. RepoB adds `.pb.dart`, `.pbenum.dart`, `.pbjson.dart`, `.pbserver.dart`, `.gr.dart` (protobuf, auto_route — `production-repo-B/.claude/docs/claude-architecture.md:83-85`). Repo-A blocks `.g.dart`, `.freezed.dart`. List **exactly what the repo generates** — listing extensions the repo doesn't produce is dead text, listing missing ones leaks edits past the hook.

Cross-link to [enforcement-hooks.md](enforcement-hooks.md) for the contract / guards / mode env-var pattern.

### §6 Slash commands

Note ONLY additions or omissions relative to the standard 3-base (`/<prefix>-implement`, `/<prefix>-audit`, `/<prefix>-audit-skills`).

**If exactly the 3-base**, one paragraph — like repoC:

> "The standard three (`/repoC-implement`, `/repoC-audit`, `/repoC-audit-skills`) — no project-specific additions or omissions." — `production-repo-C/.claude/docs/claude-architecture.md:91-92`

**If additions**, document each with its rationale. RepoB added `/repoB-design`:

> "Four commands: `/repoB-implement`, `/repoB-design`, `/repoB-audit`, `/repoB-audit-skills`. `/repoB-design` extends the `/repoB-implement` pipeline with a design acquisition step (paper.design MCP or claude.design handoff bundle) — same agents, same review loop, richer input." — `production-repo-B/.claude/docs/claude-architecture.md:90-94`

Cross-link to [slash-commands.md](slash-commands.md).

### §7 Hook scope

Two paragraphs:

1. **What files `<prefix>_quality_check.sh` fires on** — `.dart` files under a workspace `pubspec.yaml` inside THIS repo. Out-of-scope edits exit silently. Path nudges mirror each skill's `applicability` from §2.
2. **What `<prefix>_skills_drift.sh` does** — scans `.claude/**/*.md` + `CLAUDE.md` for dead links. Report-only on hooks; full scan via `/<prefix>-audit-skills`.

Plus one closing paragraph that records the deliberate omission: **no push-guard hook**. Why: `permissions.allow` excludes `git push` (every push prompts the user), GitHub branch protection covers the remote. Reintroduce only in a repo that has neither.

> "Push protection is delegated to `permissions.allow` (which deliberately excludes `git push` — every push prompts the user) and GitHub branch protection on `main`. No `PreToolUse` push-guard is needed." — `production-repo-C/.claude/docs/claude-architecture.md:106-108`

Cross-link to [enforcement-hooks.md](enforcement-hooks.md).

### §8 Rejected alternatives

**THE most valuable section.** Every entry uses the 4-field shape (next subsection). This is what stops the layer drifting in a loop — every six months someone proposes per-area maintainers; every six months the entry shows it was tried and reverted and what the reversal criterion is.

> "The Rejected alternatives section pays for itself. It's why future-you doesn't re-litigate decisions, and why someone new can tell a deliberate omission from an oversight." — blueprint `README.md:299-301`

### §9 Rollout status

A 7-step checkbox list mirroring the apply-the-blueprint procedure (see [bootstrap-procedure.md](bootstrap-procedure.md)):

```
1. Foundation wiring — <status>
2. Skeleton — <status>
3. Enforcement — <status>
4. Agents — <status>
5. Skills — <status>
6. CLAUDE.md trim — <status>
7. Validation — <status>
```

Each line one checkbox or short phrase. RepoC's is exemplary:

```
1. Foundation wiring — done (`utopia-hooks@utopia-claude-skills` enabled in `.claude/settings.json`).
2. Skeleton — done (CLAUDE.md, `.claude/skills/repoC/`, `.claude/skills/repoC-functions/`, `refs/`, `docs/`).
3. Enforcement — done (quality-check hook with hard block on generated + warn nudges).
4. Agents — done (architect, maintainer, reviewer, precommit-auditor).
5. Skills — `repoC` has `game-flow-module.md` (CRITICAL) + ...
6. CLAUDE.md trim — done.
7. Validation — `bash .claude/scripts/repoC_skills_drift.sh --all` passes after each material edit.
```

— `production-repo-C/.claude/docs/claude-architecture.md:156-162`

**Update §9 after each validation step**, not at the end. A stale §9 ("✅ Skills" when only one skill exists) is worse than blank — it implies done where it isn't.

## The §"Rejected alternatives" entry shape

Four fields, mandatory in this order:

```markdown
### <Short name of the alternative>

- **Alternative.** <One paragraph describing what was considered.>
- **Case for.** <Why it was tempting — what problem it would solve, what symmetry it would offer.>
- **Case against here.** <Why it doesn't apply to THIS repo right now — concrete reasoning grounded in this project's facts.>
- **Reversal criterion.** <One precise condition that, if met, would flip the decision.>
```

The four fields are non-negotiable. Skipping `Case for` produces straw-man reasoning ("we considered X but it's obviously wrong"). Skipping `Reversal criterion` makes the decision irreversible-by-default — the criterion is what lets a future person honestly say "the world changed, this entry now flips."

### Example: per-area maintainers (repo-A — tried and reverted)

> "### Per-area write-capable maintainer agents
>
> - **Alternative.** Persistent agents (e.g. `bp-phone-maintainer`, `bp-backend-maintainer`, `bp-messaging-maintainer`) with `Write`/`Edit` tools, scoped to disjoint directories, preloading the relevant skills. Used in `feature/claude-code-config` with four such agents …
> - **Case for.** Architect's task split can fan out concurrent `Agent` calls → wall-clock parallelism. Each maintainer keeps its file reads out of the main context. …
> - **Case against here.** Typical work is ticket-scoped and single-area; three-area cross-cutting features are infrequent. Parallelism payoff triggers on a small fraction of tasks, while the cost — noisier description-matching across a larger roster, heavier `/bp-team` protocol, higher onboarding surface, more to audit for drift — is paid on every turn. …
> - **Reversal criteria.** Sustained pattern of branches spanning ≥3 disjoint areas in a single PR, or a team size where agent-per-engineer-area ownership would aid coordination."

— `production-repo-A/.claude/docs/claude-architecture.md:219-224`. This is the canonical entry: it was **actually tried**, reverted, and the reversal criterion is a quantitative signal (≥3 disjoint areas, routine, not occasional).

### Example: monolithic skill (repoB — never tried, but considered)

> "### One monolithic `repoB` skill covering Flutter + Kotlin + Next.js
>
> - **Alternative.** Keep a single skill with 'everything RepoB', let it cover classroom-api and distributors via bullet points in references.
> - **Case for.** Fewer files; one description match catches all repo work.
> - **Case against here.** Three different techstacks (Dart/Flutter, Kotlin/Ktor, TS/Next.js) have no real shared conventions to enforce. The applicability scope becomes 'everywhere relevant' — template §3 calls this a router-in-disguise. Description matching loads a skill the agent then can't act on for the specific techstack.
> - **Reversal criterion.** If `repoB-api` and any future `repoB-distributors` skill never accumulate references beyond pointers to `.claude/refs/`, the separation pays no rent. Re-consolidate by collapsing them back into `repoB` references and deleting the standalone `SKILL.md`s."

— `production-repo-B/.claude/docs/claude-architecture.md:117-130`. Note the reversal criterion is the opposite direction — it flips back to the alternative if the chosen design fails to earn rent.

### Example: domain auditor deferral (repoC — considered, not added)

> "### Domain auditor (Firestore rules, IAP)
>
> - **Alternative.** Add `repoC-rules-auditor` or `repoC-paywall-auditor` to the roster.
> - **Case for.** Both surfaces are silent in regular review and can leak data / revenue.
> - **Case against here.** No recent incident has cost enough to warrant a dedicated read-only pass. The standard reviewer + precommit auditor cover these surfaces today.
> - **Reversal criterion.** A regression in either surface that the standard reviewer didn't catch."

— `production-repo-C/.claude/docs/claude-architecture.md:126-131`. The reversal criterion is an event ("a regression … the standard reviewer didn't catch") — the auditor exists in the threat model, just not in the roster yet.

### Example: path-nudge deferral (repoC — primitive skill)

> "### Path-nudge the hook for TypeScript / functions
>
> - **Alternative.** Extend `repoC_quality_check.sh` to fire on `.ts` files under `functions/` with skill-specific nudges.
> - **Case for.** Deterministic surfacing instead of relying on description matching.
> - **Case against here.** `repoC-functions` is primitive — no reference worth nudging the agent to read. Adding a nudge that points at 'no content yet' wastes a hook firing.
> - **Reversal criterion.** `repoC-functions` accumulates 2+ references — wire path nudges then."

— `production-repo-C/.claude/docs/claude-architecture.md:140-145`. Quantitative criterion (≥2 references) — see [enforcement-hooks.md](enforcement-hooks.md) for why the threshold is 2.

### Example: MCP assumption (repoC — explicit non-assumption)

> "### Assume an MCP Dart server
>
> - **Alternative.** Mirror repoB's `mcp__repoB-dart__*` permissions and agent fallback tables.
> - **Case for.** Faster iteration, structured diagnostics.
> - **Case against here.** No MCP Dart server is configured for this repo. Listing permissions for a server that isn't installed pollutes the allowlist; agent prompts referencing absent tools confuse the model.
> - **Reversal criterion.** A `mcp.json` with a Dart MCP entry lands → wire MCP-preferred / bash-fallback throughout."

— `production-repo-C/.claude/docs/claude-architecture.md:147-152`. Note this is **the rejected alternative AND the MCP-assumption record** — they are the same paragraph in this repo. See "MCP assumption note" below.

## Toolchain canon — recorded fact, not a chosen design

The Toolchain canon is a paragraph in §4 (or wherever the doc anchors it). It is **a record, not a design choice**. There is one binary call per toolchain (FVM yes/no for Dart, nvm yes/no for Node, etc.) and the answer propagates **everywhere** — agents, slash commands, scripts, `permissions.allow`.

> "Pick one form and apply it everywhere — no `cmd / fvm cmd` slashes, no per-file if/else. Either the repo uses FVM or it doesn't; the answer is binary. Bare-toolchain ambiguity (bash resolving against whatever `$PATH` exposes) has bitten teams before — this section exists to short-circuit that. No 'case for / against': it's a recorded fact, one short paragraph." — blueprint `README.md:281-290`

Production shapes — both use FVM:

> "**Toolchain canon (fact, not decision).** Repo uses FVM (`.fvmrc` pins 3.41.7), so bash is `fvm dart` / `fvm flutter` everywhere — no bare aliases. Routine ops go through the `repoB-dart` MCP (already on the FVM-pinned SDK); `mcp__repoB-dart__analyze_files` is authoritative for analysis — bash `fvm dart analyze` is the deprecated fallback." — `production-repo-B/.claude/docs/claude-architecture.md:75-79`

> "**Toolchain canon (fact, not decision).** Repo uses FVM (`.fvmrc` pins 3.41.4), so bash is `fvm dart` / `fvm flutter` everywhere — no bare aliases. `fvm dart analyze` is authoritative. No Dart MCP is configured here, so permissions and agent prompts go bare-fvm with no MCP fallback table." — `production-repo-C/.claude/docs/claude-architecture.md:77-80`

Notice the second sentence in each: it explicitly couples the toolchain canon to the MCP assumption — they aren't independent.

## MCP assumption — what's installed and what's authoritative

For Dart projects, the architecture doc documents which MCP server is **assumed installed** in this repo. The blueprint defaults to "an MCP Dart server is preferred for routine ops; bash via toolchain canon is the fallback, and is authoritative for `analyze`."

> "For Dart projects, an MCP dart server (e.g. `dart-mcp`, `repoB-dart`) is **assumed present** and is the preferred surface for routine ops (`dart_format`, `pub`, `run_tests`). Bash via the toolchain canon (item 5 above) is the fallback, and is authoritative for `analyze` (MCP `analyze_files` is known to miss errors)." — blueprint `README.md:291-297`

**Rule: don't reference an MCP server that isn't installed.** Listing it in `enabledMcpjsonServers` or `permissions.allow` (without the server being there) pollutes the allowlist; quoting `mcp__<name>__<tool>` in agent prompts confuses the model.

- **RepoB assumes** `repoB-dart` MCP (authoritative for `analyze_files`, see repoB architecture-doc).
- **RepoC explicitly does not** — see the §8 rejected-alternative "Assume an MCP Dart server" above. The exact reason is to keep the allowlist and agent prompts honest.

If the MCP assumption changes (a server lands or is removed), update §"Toolchain canon" AND the relevant §"Rejected alternatives" entry — don't delete it.

Cross-link to [settings-json.md](settings-json.md) (the `enabledMcpjsonServers` / `permissions.allow` shape) and [drift-symptoms.md](drift-symptoms.md) (MCP-listed-but-not-installed as a known failure mode).

## Operational rules

### 1. Write this doc FIRST, before any files.

During bootstrap, the architecture doc is Phase 1.5 — between the blueprint copy and the first skill / agent file. Order reversed, the doc narrates instead of decides; choices stop being choices.

> "Draft `.claude/docs/claude-architecture.md`. Fill in §2 (skill split table), §3 (which reference styles each skill will use), §8 (rejected alternatives — what you considered but didn't pick), plus the §9 toolchain-canon and MCP-assumption notes — record the FVM-or-not call (or the equivalent for non-Dart toolchains) once here, then propagate the chosen form into every agent, command, script, and `permissions.allow` entry. No alternation slashes." — blueprint `README.md:392-398`

### 2. Never delete a §"Rejected alternatives" entry.

Even if the alternative was tried and reversed. **Update it; keep the history.** Otherwise future-you re-proposes the same idea cold, without knowing it was tried.

The repo-A §"Rejected alternatives" entry for per-area maintainers explicitly records they were "Used in `feature/claude-code-config` with four such agents." (`production-repo-A/.claude/docs/claude-architecture.md:221`). That sentence is the prevention — without it, the next reorg proposes per-area maintainers blind.

### 3. Update §"Rollout status" after each validation step.

Not at the end. A doc whose §9 says "✅ Validation" but whose validation hasn't run is worse than blank.

### 4. Append entries to §"Skill split" / §"Slash commands" / §"Hook scope" tables as the layer evolves.

These are **living tables**, not bootstrap-only. Every new skill / command / nudge gets a row at landing time. If you find yourself updating an agent prompt or a hook script without touching the architecture doc, the doc is going stale.

### 5. Cross-link out, never inline.

The architecture doc refers to **blueprint conventions** and **sibling references** — it doesn't restate them. Authoring conventions for module / pattern / cheatsheet style live in the blueprint, linked. The full no-router-skill rule lives in [skill-design.md](skill-design.md), linked. The hook contract lives in [enforcement-hooks.md](enforcement-hooks.md), linked.

The architecture doc's job is to be **short** and **decision-dense**. RepoC's is 163 lines; repoB's is 194. If yours is growing past ~300 lines, narrative is leaking in — move it to `docs/architecture.md` at the repo root (repo-A's precedent: system topology, sequence diagrams, formal spec are repo-root docs, not Claude-layer docs).

## Anti-patterns

### Writing the doc after the files

The doc narrates instead of decides. By the time it's drafted, the skills exist; the §"Rejected alternatives" entries are written to defend choices already shipped, not to actually weigh alternatives. The decision-log discipline collapses.

**Fix:** Phase the bootstrap (see [bootstrap-procedure.md](bootstrap-procedure.md)) so the doc is written and validated **before** the first SKILL.md.

### Deleting a rejected-alternative entry because "we now know it's wrong"

The entry IS the prevention. If you delete the per-area-maintainers entry the day after the fan-out experiment is reverted, the next architect who learns about parallel `Agent` calls proposes per-area maintainers in a clean window.

**Fix:** update the entry — add a "Tried, reverted on <date>" note inside `Case against here`. Keep the entry.

### Skipping a §"Rejected alternatives" entry for a deliberate omission

"Standard four, no domain auditor" with no entry explaining WHY leaves future-you in the dark. A new auditor proposal can't be evaluated against precedent that doesn't exist.

> "Domain auditor candidates (deferred): Firestore/RTDB rules auditor … IAP/paywall auditor. Open until a real incident motivates dedicated review." — `production-repo-C/.claude/docs/claude-architecture.md:73-75`

This sentence is the missing prevention if it isn't there. The full entry in §8 reinforces it.

### Rejected-alternative entry missing the `reversal criterion`

Without it, the decision can never be flipped honestly — every reversal becomes "we just changed our mind." The reversal criterion is what lets a future person say "the world changed in the specific way the entry anticipated; here's the flip."

**Fix:** for every existing entry without a reversal criterion, write one. If you can't write one, the entry is unfalsifiable and probably wrong.

### Toolchain canon left ambiguous

Some files use `fvm dart`, others use `dart`, some agents use `mcp__<repo>-dart__*` with bash fallbacks. Bash resolves against whatever `$PATH` exposes — including a system Dart that doesn't match the FVM pin. CI ships green; production ships broken.

> "Bare-toolchain ambiguity (bash resolving against whatever `$PATH` exposes) has bitten teams before — this section exists to short-circuit that." — blueprint `README.md:286-288`

**Fix:** record the binary FVM-yes / FVM-no call in §"Toolchain canon", propagate to every agent prompt, slash command, hook script, and `permissions.allow` entry. No alternation slashes.

### MCP listed in `enabledMcpjsonServers` but architecture doc doesn't justify it

Allowlist pollution. Agent prompts reference `mcp__<name>__<tool>` calls the model can't actually make. The doc should explicitly say which MCPs are assumed present; agent prompts should match.

**Fix:** add an MCP assumption paragraph to §4 or §7. If the server isn't actually installed, either install it (and document the assumption) or remove the references and add a §"Rejected alternatives" entry explaining the explicit non-assumption (repoC precedent).

### Doc growing into deep design documentation

Architecture sequence diagrams, formal proofs, full data-exchange specs, key-exchange ceremonies — these are NOT decision-log content. They are **design documentation** and belong in `docs/architecture.md` at the repo root.

Repo-A's split is exemplary: `.claude/docs/claude-architecture.md` is the Claude-layer decision log; `docs/architecture.md`, `docs/data_exchange.md`, `docs/key_exchange_formal.tex` carry the system-level design (see `production-repo-A/CLAUDE.md:234-236`).

**Fix:** if your doc is over ~300 lines and growing, scan it for narrative paragraphs that aren't decisions — those move to repo-root docs.

### Reordering or renaming the 9-section spine

The order is structural. §"Rejected alternatives" comes after §"Hook scope" because by the time you're reading rejected alternatives, you've already seen the decisions that were taken — the entries make sense as counter-positives to the table rows.

**Fix:** keep the order. If you have nothing for a section, write the section with a single sentence: "Standard three — no additions" / "Standard four — no domain auditor" / etc.

## See also

- [layer-model.md](layer-model.md) — the two-layer model the doc opens by restating
- [agent-roster.md](agent-roster.md) — the standard four and the criteria for adding a fifth (§4)
- [skill-design.md](skill-design.md) — applicability scopes and no-router rule referenced from §2
- [slash-commands.md](slash-commands.md) — 3-base and when to add a fourth, referenced from §6
- [enforcement-hooks.md](enforcement-hooks.md) — hook contract and mode env var referenced from §5 and §7
- [claude-md.md](claude-md.md) — the CLAUDE.md inventory that mirrors §2 / §4 / §6
- [settings-json.md](settings-json.md) — `enabledMcpjsonServers` and `permissions.allow` referenced from the MCP-assumption note
- [bootstrap-procedure.md](bootstrap-procedure.md) — Phase 1.5: write the architecture doc first
- [maintain-evolve.md](maintain-evolve.md) — appending entries mid-project, recording reversals
- [drift-symptoms.md](drift-symptoms.md) — MCP-listed-but-not-installed, ambiguous toolchain canon
- Inline template: [`../templates/claude-layer/docs/claude-architecture.md`](../templates/claude-layer/docs/claude-architecture.md) — canonical 9-section spine with placeholders
- Inline templates for the 3 reference-style authoring guides linked from §3: [`../templates/conventions/module-style.md`](../templates/conventions/module-style.md), [`../templates/conventions/pattern-style.md`](../templates/conventions/pattern-style.md), [`../templates/conventions/cheatsheet-style.md`](../templates/conventions/cheatsheet-style.md) — link from your repo's `claude-architecture.md` §3, never copy
