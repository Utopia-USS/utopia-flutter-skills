---
title: Drift Symptoms — Empirical Failure-Mode Catalogue
impact: HIGH
tags: drift, anti-patterns, audit, failure-modes, real-precedent, grep-targets
---

# Drift Symptoms — Empirical Failure-Mode Catalogue

## What this is

**A catalogue of failure modes that have actually happened** in qbt-black-phone,
jolly-phonics-apps, and madrosc-tlumu. Each entry has a verbatim quote with
file:line citation — these are not hypotheticals, they're documented production
drift that was caught, named, and (in most cases) recorded in a §"Rejected
alternatives" entry.

The goal: when an agent is auditing a `.claude/` layer, this is the grep target
for what to look for. When designing a new layer, this is the list of mistakes
not to make. Each symptom has a fix, and a short rationale for the underlying
pressure that produces this drift.

## When this applies

- Auditing an existing `.claude/` layer (`/<prefix>-audit-skills`, or a manual
  scan during architecture review)
- Debugging "why is the agent doing X" — drift is the usual answer
- Reviewing a proposed `.claude/` change against known anti-patterns
- Writing a new §"Rejected alternatives" entry — this catalogue gives you the
  shape and the precedent format

---

## Catalogue

### A. Master skill `references/` accumulating cross-cutting Dart content

**Symptom (what you'd observe):**
The master skill's `references/` directory contains files like `freezed.md`,
`code-generation.md`, `components.md`, `strict-analysis.md`,
`imports-and-formatting.md` — concerns that apply to any Dart authoring in
the repo, not just the master skill's surface. Sister skills deep-link into
the master skill's references.

**Evidence (real precedent):**
> "`bp` was originally documented as the master skill that 'owns' Freezed /
> codegen / strict-analyzer / imports / design-system / dependencies / release
> coordination — but those concerns are not BP-specific, they apply to anyone
> authoring Dart in this repo. Keeping them inside `bp/references/` made `bp`
> look like an uber-skill that has to fire on every techstack (phone / admin /
> tower / core / core_ui / FFI / message_service…), and forced sister skills
> to deep-link into `bp/references/` to share content." —
> `qbt-black-phone/.claude/docs/claude-architecture.md:126`

**Why it happens:**
When you bootstrap, the master skill is the natural home for "everything
Flutter-y". As sister skills appear (server, deployment, security), the
shared Dart conventions stay where they were because moving them would
require updating cross-links. The master becomes an uber-skill firing on
every Dart edit anywhere.

**Fix:**
Lift cross-cutting Dart refs to `.claude/refs/<topic>.md`. Each consuming
SKILL.md links to them from `See also`. The master skill's `references/`
keeps only what's truly master-specific (qbt kept `ffi-conventions.md`,
`isar.md` — content that wouldn't apply outside the master's Flutter
surface).

---

### B. References documenting what deterministic tools already enforce

**Symptom (what you'd observe):**
Reference files titled `imports-and-formatting.md`, `strict-analysis.md`,
`naming-conventions.md` — describing rules the analyzer / `dart fix` /
`dart format` / `utopia_lints` already produce errors for. The agent reads
them, makes a mental note, then the tool blocks the violation anyway.

**Evidence (real precedent):**
> "`imports-and-formatting.md` and `strict-analysis.md` were originally in
> this set, then deleted — `dart format` + `dart fix` + `utopia_lints` + the
> analyzer enforce the mechanics directly, so the refs were repeating tool
> output. The only judgment calls (suppression policy, FFI-bindings exception)
> were inlined into `bp/SKILL.md` §'Non-Negotiable Rules'." —
> `qbt-black-phone/.claude/docs/claude-architecture.md:126`

**Why it happens:**
When authoring the skill the first time, you write down everything you can
think of. The mechanical rules feel important enough to include. Months
later, the analyzer is catching every violation; the ref is just
maintenance overhead.

**Fix:**
Delete the reference. Move the *judgment calls* (suppression policy,
exceptions) inline into `SKILL.md` §"Non-Negotiable Rules" — those are
not mechanical and the analyzer can't make them. Mirror this trim before
adding any new ref: **if the analyzer / formatter would catch the
violation, it does not need a markdown ref.**

---

### C. Eng-manager / hygiene agent where a script suffices

**Symptom (what you'd observe):**
An agent file like `<prefix>-eng-manager.md` or `<prefix>-doc-auditor.md`
that "audits the `.claude/` layer after feature work" using probabilistic
heuristics — dead links, stale SKILL.md content, frontmatter consistency.

**Evidence (real precedent):**
> "The primary failure mode — dead markdown links and stale `SKILL.md`
> content — is caught deterministically by `bp_skills_drift.sh` +
> `/bp-audit-skills`. A probabilistic agent is strictly weaker than a
> script that always runs." —
> `qbt-black-phone/.claude/docs/claude-architecture.md:244`

**Why it happens:**
Hygiene work feels naturally like an agent's job. The temptation is to
make the agent the home for "everything that doesn't fit in the four
standard roles". Each agent looks low-cost in isolation.

**Fix:**
Replace the agent with `<prefix>_skills_drift.sh` (dead-link scanner
that always runs) plus `/<prefix>-audit-skills` (explicit invocation
for a full scan + guided repair). The precommit-auditor catches
internal CLAUDE.md / `.claude/docs/` consistency at commit time.

---

### D. Per-area maintainers (`<prefix>-<area>-maintainer`)

**Symptom (what you'd observe):**
Multiple write-capable agents scoped to disjoint directories
(`<prefix>-phone-maintainer`, `<prefix>-backend-maintainer`,
`<prefix>-messaging-maintainer`, etc.), each preloading the relevant skill.

**Evidence (real precedent):**
> "Typical work is ticket-scoped and single-area; three-area cross-cutting
> features are infrequent relative to overall throughput. Parallelism
> payoff triggers on a small fraction of tasks, while the cost — noisier
> description-matching across a larger roster, heavier `/bp-team` protocol,
> higher onboarding surface, more to audit for drift — is paid on every
> turn." — `qbt-black-phone/.claude/docs/claude-architecture.md:222-223`

**Why it happens:**
Architect plans look like they want fan-out. Code review feels safer with
ownership boundaries. Each per-area maintainer reads cleanly in isolation
("focused agent that knows backend cold").

**Fix:**
Use a single cross-area `<prefix>-maintainer` with `skills:` preloading
the master skill. For genuine parallelism, batch multiple `Agent` calls
to that maintainer in a single assistant message, one per disjoint
chunk. **Reversal criterion** (record as §"Rejected alternatives"):
sustained pattern of branches spanning ≥3 disjoint areas in a single PR,
or a team size where agent-per-engineer-area ownership would aid
coordination.

---

### E. Skill with no applicability content (primitive skill firing wrongly)

**Symptom (what you'd observe):**
A `SKILL.md` with frontmatter that matches a techstack, but
`references/` is empty or contains a single pointer to `.claude/refs/`.
The skill loads on description match and the agent reads nothing
actionable.

**Evidence (real precedent):**
> "No active Next.js work in flight, no pending distributors-side tickets
> in memory, no concrete content to put in the skill. Template §3 warns
> against skills with no applicability content — they fire wrongly and
> confuse the agent." —
> `jolly-phonics-apps/.claude/docs/claude-architecture.md:138-141`

> "No active Claude-driven landing work, no concrete content to put in
> the skill. Blueprint §3 warns against skills with no applicability
> content — they fire wrongly and confuse the agent." —
> `madrosc-tlumu/.claude/docs/claude-architecture.md:122-124`

**Why it happens:**
Symmetry pressure. If one tech stack has a skill (`<prefix>-api`), it
feels incomplete to not have a parallel skill for the next stack
(`<prefix>-distributors`, `<prefix>-landing`). You open the skill
"for when work ramps up". It fires on description match before any
content lands.

**Fix:**
**Don't preempt.** Defer the skill until there's real content. The
single legitimate exception is a primitive sister skill that exists
**only to legitimise a `.claude/refs/<contract>.md`** — jolly's
`jolly-api` exists primarily to give `proto-contract.md` a logical
owner. Record this as a deliberate decision in §"Skill split", with
the reversal criterion ("first real Claude-driven task → graduate").

---

### F. Domain auditor without incident justification

**Symptom (what you'd observe):**
A `<prefix>-<domain>-auditor` agent added to the roster because "this
surface looks risky", with no recorded incident or threat-surface
change that the standard reviewer can't carry.

**Evidence (real precedent):**
> "No recent incident has cost enough to warrant a dedicated read-only
> pass. The standard reviewer + precommit auditor cover these surfaces
> today." — `jolly-phonics-apps/.claude/docs/claude-architecture.md:148-152`

> "No recent incident has cost enough to warrant a dedicated read-only
> pass. The standard reviewer + precommit auditor cover these surfaces
> today." — `madrosc-tlumu/.claude/docs/claude-architecture.md:75`

**Why it happens:**
Auditor agents feel like a free safety net. The cost (description-
matching noise, prompt to maintain, hand-off complexity) is hidden;
the upside (catching a hypothetical incident) is vivid.

**Fix:**
**Defer until an incident or documented threat-surface change.**
Record the candidate in §"Rejected alternatives" with the reversal
criterion ("a regression in <surface> that the standard reviewer
didn't catch"). qbt's `bp-security-auditor` is the precedent for when
this **is** justified — DSKE FFI, ML-KEM, Supabase RLS, push-payload
confidentiality. A real adversarial surface, not a hypothetical one.

---

### G. `dart_fix` running project-wide and bulldozing user WIP

**Symptom (what you'd observe):**
Agent diffs show changes far outside the stated scope — trailing
commas flipped on hundreds of files, `prefer_const_*` cascades,
`unnecessary_this` removals across packages the change didn't touch.
Conflicts with the user's long-running uncommitted work; entire WIP
branches lost or muddled.

**Evidence (real precedent):**
> "**Do NOT run `mcp__jolly-dart__dart_fix`** as a mandatory step. It
> touches the whole project (or any file it deems 'fixable'), which
> produces enormous cross-file diffs that conflict with the user's
> long-running uncommitted WIP. Write code correctly the first time —
> unused imports, `prefer_const_*`, `unnecessary_this`, trailing commas
> are all things you can get right manually on the files you touched." —
> `jolly-phonics-apps/.claude/agents/jolly-maintainer.md:38-46`

> "Project-wide `dart_fix` ran (changes far outside the stated scope,
> e.g. trailing commas / `prefer_const_*` flipped across unrelated
> files) → **BLOCKER** — strip those edits, they conflict with the
> user's WIP." — `jolly-phonics-apps/.claude/agents/jolly-reviewer.md:42-44`

**Why it happens:**
`dart_fix` looks like a free win to the agent — automated cleanup
before hand-off. The agent doesn't know which files have uncommitted
WIP in the user's editor. "Apply fixes" is one tool call; the
collision damage is invisible until the user runs `git status`.

**Fix:**
Maintainer rule: `dart_format` on `files_touched` ONLY; **never
project-wide `dart_fix`**. If the agent genuinely needs an auto-fix,
invoke `dart_fix` on a **single specific file** from `files_touched`
and review the diff before keeping it. Reviewer rule: project-wide
`dart_fix` is a **BLOCKER**, not a warning — the diff has to be
stripped before merge.

---

### H. Worktree edits silently no-op

**Symptom (what you'd observe):**
Agent edits Dart files in a worktree. Analyzer says "no issues". Hot
reload doesn't show the changes. Build keeps using the main repo's
content. The user's report: *"The UI still looks like the old version
even though I clearly saved the file."*

**Evidence (real precedent):**
> "A worktree shares `.git/` with the main repo but has its **own
> working tree**. What it does NOT have, by default: its own
> `.dart_tool/` … When a worktree has no `.dart_tool/`, `dart analyze`
> walks **up** the directory tree looking for one — and finds the
> main repo's `.dart_tool/`. That `package_config.json` resolves
> `package:classroom/…` to `<MAIN_REPO>/classroom/lib/`, **not** the
> worktree's classroom/lib." —
> `jolly-phonics-apps/.claude/skills/jolly/references/worktree-gotchas.md:9-20`

**Why it happens:**
Dart's tooling walks up looking for `package_config.json`. Worktrees
inherit `.git/` but not `.dart_tool/`. The walk-up resolves
`package:<x>/…` to the **main repo's** copy, not the worktree's —
silently and successfully (no error, no warning).

**Fix:**
Pre-flight check before any non-trivial Dart edit in a worktree:

```bash
ls .dart_tool/package_config.json 2>/dev/null \
  && echo "OK — worktree has its own resolution" \
  || echo "BROKEN — worktree will read package:* from the main repo"
```

If BROKEN: bootstrap the worktree (`melos bootstrap` from its root)
or do the work in the main repo. Skill: bake the check into the
master skill's `references/worktree-gotchas.md` so the agent
encounters it before the failure mode bites.

---

### I. Stale `dart mcp-server` + `dart language-server` processes accumulating memory

**Symptom (what you'd observe):**
~40GB+ resident memory by end of day on a development machine. `ps
aux | grep dart` shows multiple `dart mcp-server` and
`dart language-server` processes with PPID 1 (orphaned).

**Evidence (real precedent):**
> "Each Claude Code session spawns its own `dart mcp-server`, which in
> turn spawns a `dart language-server` (~2.5GB resident). On clean
> `/exit` they cascade away. On a Claude crash the children orphan to
> init and accumulate. Forgotten Claude windows also hold their full
> analyzer — the team was reporting ~40GB after a day of work." —
> `jolly-phonics-apps/.claude/scripts/dart_mcp_setup.sh:4-10`

**Why it happens:**
Process lifecycle expects clean shutdown. Crashes and forgotten
windows produce orphans. The agent has no awareness of cross-session
resource accounting.

**Fix:**
A `SessionStart` hook that (a) kills Claude top-level processes older
than a threshold (the dart mcp-server + language-server cascade with
them), (b) reaps orphaned `dart mcp-server` / `dart language-server`
with `PPID == 1`, (c) warns to stderr when too many live sessions are
running. Always exits 0 so transient failures don't block a session.
See jolly's `dart_mcp_setup.sh` for the template; replicate per-repo
where a Dart MCP is the canonical surface.

---

### J. AI-comment cruft (prompt-referencing, task-referencing, review-thread-referencing comments)

**Symptom (what you'd observe):**
Source files containing comments like:

```dart
// Added per user request for BP-2025-180                      ❌
// FIXME from the review feedback                              ❌
// This handles the case where Ben mentioned in Slack          ❌
// Removed the bool flag — see commit                          ❌
// AI-generated layout for the new flow                        ❌
```

**Evidence (real precedent):**
> "Comments that respond to the prompt, reference the current task, or
> narrate what you just did. These rot the second the prompt is
> forgotten." — `qbt-black-phone/.claude/agents/bp-maintainer.md:170-179`

> "If the comment wouldn't make sense to a reader who has never seen
> this conversation, PR, or review thread — delete it." —
> `qbt-black-phone/.claude/agents/bp-maintainer.md:188-189`

The same rule is repeated verbatim in
`jolly-phonics-apps/.claude/agents/jolly-maintainer.md:144-164` and
mirrored in `jolly-reviewer.md:45-48` as WARN-grade enforcement.

**Why it happens:**
The agent narrates its own work back to itself. Comments responding
to the prompt feel like they're documenting WHY the code looks the
way it does. They are — but for an audience of zero (the prompt
won't exist in three months).

**Fix:**
Maintainer rule (verbatim from the agents): "If the comment wouldn't
make sense to a reader who has never seen this conversation, PR, or
review thread — delete it." Inline `//` for genuine WHY (subtle
invariants, workarounds for specific bugs); `///` for public API doc
comments; never for narrating WHAT or referencing the prompt.
Reviewer rule: prompt-/task-/review-referencing comments are WARN-
grade — strip before merge. Precommit-auditor surfaces these as
COMMIT-FIX-FIRST when staged.

---

### K. Reviewer leakage from maintainer self-report

**Symptom (what you'd observe):**
The reviewer's report quotes the maintainer's reasoning ("the
maintainer mentioned this was intentional because…") instead of
verifying from the diff. BLOCKER findings get downgraded because
"the maintainer explained why". Independence collapses.

**Evidence (real precedent):**
> "When `/jolly-implement` invokes the reviewer, it withholds this
> self-report on purpose — the reviewer must verify the diff from
> scratch, not from your reasoning. If you find yourself writing 'the
> reviewer should be OK with this because X', that X belongs in the
> code or in a warning, not as a hint to the reviewer." —
> `jolly-phonics-apps/.claude/agents/jolly-maintainer.md:222-227`

**Why it happens:**
The orchestrator (`/<prefix>-implement`) is responsible for splitting
the maintainer's self-report so the reviewer doesn't see it. If the
orchestrator passes everything along (or the user invokes the
reviewer directly with the maintainer's narrative in context), the
reviewer is now reading approval-by-narration instead of doing the
review.

**Fix:**
`/<prefix>-implement` orchestrator: pass the reviewer only
`files_touched`, `proposed_commit_message`, `baseline_analyze` — NOT
the maintainer's `warnings`, `out_of_scope_observations`, or any
reasoning. Maintainer rule: anything the reviewer needs to know
about the code goes into the code (or a code comment), not into a
hint to the reviewer. If you're tempted to write "the reviewer
should be OK with this because…" — that's the smell. Stop, put it
in the code.

---

### L. Skill description firing on files the skill can't act on (router-in-disguise)

**Symptom (what you'd observe):**
A single skill description matches an entire repo's source files,
across three or four techstacks. The agent loads the skill on a
Kotlin file edit; the skill is mostly Dart conventions; the agent
gets misleading context.

**Evidence (real precedent):**
> "Three different techstacks (Dart/Flutter, Kotlin/Ktor, TS/Next.js)
> have no real shared conventions to enforce. The applicability scope
> becomes 'everywhere relevant' — template §3 calls this a router-in-
> disguise. Description matching loads a skill the agent then can't
> act on for the specific techstack." —
> `jolly-phonics-apps/.claude/docs/claude-architecture.md:122-126`

> "Three techstacks (Dart/Flutter, TS/Node functions, TS/Next.js)
> share no real conventions. The applicability scope becomes
> 'everywhere relevant' — blueprint §3 calls this a router-in-
> disguise. Description matching loads a skill the agent can't act
> on for the specific techstack." —
> `madrosc-tlumu/.claude/docs/claude-architecture.md:114-117`

**Why it happens:**
Single-skill simplicity feels right at bootstrap. The repo prefix
is one name; one skill named after the prefix is the smallest
shape. Three techstacks share no real conventions, but a single
skill description doesn't make that visible.

**Fix:**
Split by techstack when conventions are disjoint. Each skill gets
explicit positive + negative applicability. The negative scope
must name what the skill does NOT cover (`NOT classroom-api/
(Kotlin)`; `NOT functions/ (TS)`). Description matching now picks
the right skill per file type.

---

### M. `CLAUDE.md` skill-table drifting from `.claude/`

**Symptom (what you'd observe):**
`CLAUDE.md` describes a skill / agent / command that doesn't exist
under `.claude/`, or vice versa. The agent reads the inventory and
references a skill that was renamed or deleted.

**Evidence (real precedent):**
> "**CLAUDE.md / `.claude/docs/` edits** — must keep CLAUDE.md
> internally consistent (skill table, agent table, hook list, 'When
> to invoke' table). Flag mismatches. **COMMIT-FIX-FIRST**." —
> `qbt-black-phone/.claude/agents/bp-precommit-auditor.md:120-122`

**Why it happens:**
`CLAUDE.md` is edited far less often than `.claude/` artefacts.
Renaming a skill in `.claude/skills/` is one operation; updating the
three or four tables in `CLAUDE.md` that reference it is four
separate edits. The mismatch lands silently.

**Fix:**
The precommit-auditor explicitly checks CLAUDE.md internal
consistency on staged diffs that touch `.claude/**/*.md` or
`CLAUDE.md` itself. `<prefix>_skills_drift.sh` catches dead
markdown links across `.claude/**/*.md` + repo-root `CLAUDE.md`.
Run `/<prefix>-audit-skills` periodically — it's the full-scan
version. Editorial: every `.claude/` artefact change ends with
"and update `CLAUDE.md` inventory" — non-optional.

---

### N. Re-implementing primitives already provided by Claude / `CLAUDE.md`

**Symptom (what you'd observe):**
Thin SKILL.md files named after meta-concerns —
`<prefix>-repo-map.md` (workspace structure), `<prefix>-build-verify.md`
(build commands), `<prefix>-conventions-overview.md`. The content is
mostly inventory tables.

**Evidence (real precedent):**
> "Content is thin and overlaps with `CLAUDE.md`. `CLAUDE.md` loads
> on every turn; the skill would only load on description match.
> Inlining the content into `CLAUDE.md` makes it unconditionally
> available at lower context cost." —
> `qbt-black-phone/.claude/docs/claude-architecture.md:256-258`

**Why it happens:**
"Skill as FAQ" is a familiar pattern — collect the static project
info in a skill. But `CLAUDE.md` is *always* loaded; the skill is
only loaded on description match. The skill costs context budget
twice (when matched + duplicated under the skill match) and is
sometimes unavailable when needed.

**Fix:**
Inline into `CLAUDE.md` (Topology, Skills inventory, Common
commands). `CLAUDE.md` stays tight by linking deep content to
skills, not by hosting deep content itself. Reversal criterion if
`CLAUDE.md` grows past a comfortable top-of-context size:
infrequent content can be split back out — but FAQ-style static
content stays put.

---

### O. `PreToolUse` push-guard duplicating branch protection + permissions allowlist

**Symptom (what you'd observe):**
A `.claude/scripts/<prefix>_git_push_guard.sh` registered as a
`PreToolUse` hook on `Bash` matchers. It fires on every Bash
invocation, parses the command, and blocks `git push` based on
branch / pattern.

**Evidence (real precedent):**
> "Push protection is delegated to (a) the `permissions.allow`
> whitelist (which deliberately excludes `git push` — every push
> prompts the user) and (b) GitHub's branch protection on `master` /
> `staging`. A `PreToolUse` push-guard hook was removed as
> redundant; reintroduce only if a future repo lacks both layers." —
> `jolly-phonics-apps/.claude/docs/claude-architecture.md:108-113`

**Why it happens:**
Push protection is a vivid, tangible safety concern. The hook is
easy to write. The duplication with `permissions.allow` and GitHub
branch protection isn't visible until you sit down to maintain
three independent guards.

**Fix:**
Two layers already cover it: (a) `permissions.allow` deliberately
omits `git push` — every push prompts the user; (b) GitHub branch
protection on `master` / `main` / `staging` covers the remote.
Delete the `PreToolUse` push-guard. **Reintroduce only in a repo
that has neither layer.**

---

### P. Assuming an MCP server that isn't installed

**Symptom (what you'd observe):**
Agent prompts referencing `mcp__<server>__<tool>` calls; permissions
allowlist with `mcp__<server>__*` entries; agent fallback tables
listing "MCP preferred / bash fallback" for a server the repo never
declared in `mcp.json`.

**Evidence (real precedent):**
> "No MCP Dart server is configured for this repo. Listing permissions
> for a server that isn't installed pollutes the allowlist; agent
> prompts referencing absent tools confuse the model." —
> `madrosc-tlumu/.claude/docs/claude-architecture.md:147-152`

**Why it happens:**
Cargo-culting from another repo. jolly has `mcp__jolly-dart__*`
everywhere; tlumu copies the agent prompts and inherits the MCP
calls — but never sets up the MCP server.

**Fix:**
Pre-flight: before listing an MCP permission or referencing an MCP
tool in an agent prompt, verify the server is declared in
`.mcp.json` or the user's MCP config. If absent, **don't reference
it**. Reversal criterion: a `mcp.json` with the MCP entry lands →
then wire MCP-preferred / bash-fallback throughout. Until then,
bash-via-toolchain-canon is the only surface.

---

### Q. Release-playbook AGENT instead of release-playbook SKILL

**Symptom (what you'd observe):**
A write-capable `<prefix>-release-manager` agent with submodule
tables, remote URLs, tag procedure, version-bump commands. Loads
on every description match for "release", but invocations are once
a month at best.

**Evidence (real precedent):**
> "Release cadence is low. Agent cost is amortized over too few
> invocations to justify roster weight. A playbook skill loads on
> demand, has the same information, and doesn't compete with domain
> skills for description matching." —
> `qbt-black-phone/.claude/docs/claude-architecture.md:235-237`

**Why it happens:**
Release work is procedural and action-oriented; an agent feels like
the right shape. But low cadence means the agent's fixed cost
(description-matching noise, prompt maintenance) is paid against
very few invocations.

**Fix:**
Write a release-playbook **skill** (a `<prefix>/references/release-playbook.md`
or a sister skill if the playbook is large). It loads on demand
via description match on the literal word "release" + path
context, costs nothing when idle, has the same information.
**Reversal criterion:** release cadence becomes weekly with a
repeated, mechanical workflow.

---

### R. Slash-command wrapper around a single agent

**Symptom (what you'd observe):**
A `.claude/commands/<prefix>-review.md` that does nothing except
invoke `<prefix>-reviewer`. Or `/<prefix>-plan` that invokes
`<prefix>-architect` directly.

**Evidence (real precedent):**
> "The reviewer agent is the entire value; the wrapper adds a layer
> and splits context across multiple agents. Direct invocation of
> `bp-reviewer` by name gives subagent isolation with a clean
> context and no wrapper overhead. Pre-commit hygiene (the
> wrapper's other plausible value) is already covered by `/bp-audit`
> → `bp-precommit-auditor`." —
> `qbt-black-phone/.claude/docs/claude-architecture.md:249-251`

**Why it happens:**
Symmetry with `/<prefix>-implement`. If `/implement` exists, why
not `/plan`, `/review`? Each looks like a small convenience.

**Fix:**
Slash commands are for **orchestration** — multi-step, fan-out,
conditional flow (`/implement` is the code↔review loop;
`/audit` runs the precommit gate; `/audit-skills` is a drift scan
+ guided repair). For single-agent invocations, rely on
description matching and `@<agent-name>`. **Reversal criterion:**
review routinely needs to fan out to multiple read-only
specialists in parallel.

---

### S. Hook nudging at a primitive skill with no references

**Symptom (what you'd observe):**
A `case` branch in `<prefix>_quality_check.sh` that surfaces a
skill name on a path match, but the surfaced skill has no
`references/` content — the agent reads `SKILL.md` (which says
"see references for…") and finds nothing.

**Evidence (real precedent):**
> "While `jolly-api` is primitive there's no reference worth nudging
> the agent to read. Adding a nudge that points at 'no content yet'
> wastes a hook firing. **Reversal criterion.** `jolly-api` (or
> distributors) accumulates 2+ references — wire path nudges then." —
> `jolly-phonics-apps/.claude/docs/claude-architecture.md:170-178`

> "`tlumu-functions` is primitive — no reference worth nudging the
> agent to read. Adding a nudge that points at 'no content yet'
> wastes a hook firing. **Reversal criterion.** `tlumu-functions`
> accumulates 2+ references — wire path nudges then." —
> `madrosc-tlumu/.claude/docs/claude-architecture.md:141-145`

**Why it happens:**
Symmetry pressure again — if the master skill has a path nudge,
the sister skill "should" have one too. But before there's content
in the sister, the nudge is just noise.

**Fix:**
**≥2-references rule** for adding a path nudge. Description
matching alone handles primitives — the agent loads the skill, sees
"no content yet", and operates from foundation + master skill
content as a fallback. Add the nudge when the sister accumulates
real content.

---

### T. Patterns describing what SHOULD-BE rather than what IS

**Symptom (what you'd observe):**
A pattern reference (`<topic>-pattern.md`) describing a
convention the codebase doesn't yet follow. The agent reads it,
writes code that fits the convention, the diff doesn't match the
surrounding code, reviewer flags inconsistency.

**Evidence (real precedent):**
> "**Patterns describe what IS, not what should be.** If the
> codebase doesn't yet follow the convention, this is a roadmap
> document, not a pattern. Move it to project memory until the
> migration lands." — blueprint
> `conventions/pattern-style.md:107-109`

**Why it happens:**
Pattern documents are sometimes written *during* a migration. The
author knows the target shape; the codebase is partway there. The
ref describes the target, but the agent doesn't know that — it
applies the target shape to surrounding code that hasn't migrated.

**Fix:**
A pattern ref describes the **current** shape. If you're mid-
migration, the new shape lives in project memory ("when touching
X, prefer the new pattern Y described in <PR-link>") until the
migration is complete enough that the new shape is what the agent
will encounter in surrounding files. Then the ref graduates.

---

### U. Cheatsheets going stale and being worse than missing

**Symptom (what you'd observe):**
A `<topic>-cheatsheet.md` listing components / tokens / utilities,
with entries that no longer exist (renamed, retired) or missing
entries for recent additions. The agent reads the cheatsheet,
reaches for a retired component, and re-introduces dead code.

**Evidence (real precedent):**
> "**Stale entries are worse than missing entries.** When the
> codebase changes, the cheat-sheet has to follow on the same PR.
> Treat it like any other code surface — the drift scan should
> catch dead links, but logical drift (component renamed, token
> retired) is on the author." — blueprint
> `conventions/cheatsheet-style.md:114-118`

**Why it happens:**
Cheatsheets feel like static reference docs. A component rename
PR updates the source and call sites; updating the cheatsheet is
a separate cognitive step that's easy to skip.

**Fix:**
**Same-PR discipline.** When a component / token / utility is
renamed or retired, the cheatsheet entry is updated in the same
PR — not in a follow-up. Mark retired entries with a `Deprecated`
section pointing at the replacement (prevents the agent from
"discovering" old code and re-introducing it). The precommit-
auditor and reviewer flag cheatsheet drift when the staged diff
includes a touched file and the cheatsheet wasn't updated.

---

## How to scan for these symptoms

Bash one-liners for an audit pass. Run from repo root.

```bash
# A. Master skill references that look cross-cutting
ls .claude/skills/*/references/ \
  | grep -E "^(freezed|code-generation|components|tokens|imports|formatting|strict-analysis|dependencies|release|design-system)\.md$"

# B. References documenting deterministic tool output
grep -rl "dart format\|dart fix\|analyzer\|utopia_lints" .claude/skills/*/references/

# C. Eng-manager / hygiene-style agent files
ls .claude/agents/ | grep -iE "(eng-manager|doc-auditor|hygiene|skills-auditor|layer-auditor)"

# D. Per-area maintainer files
ls .claude/agents/*-maintainer.md 2>/dev/null | wc -l   # expect 1; >1 is per-area

# E. Primitive skills (no references content)
for s in .claude/skills/*/; do
  refs=$(find "$s/references" -name '*.md' 2>/dev/null | wc -l)
  [ "$refs" -lt 1 ] && echo "PRIMITIVE: $s ($refs refs)"
done

# F. Domain auditors without §"Agent roster" justification
ls .claude/agents/*-auditor.md \
  | grep -v "precommit-auditor" \
  | while read a; do
      name=$(basename "$a" .md)
      grep -q "$name" .claude/docs/claude-architecture.md \
        || echo "UNDOCUMENTED auditor: $a"
    done

# G. dart_fix usage in agent prompts (warn / block grade)
grep -rn "dart_fix" .claude/agents/

# H. Worktree gotcha guidance present in master skill?
find .claude/skills/*/references -name "worktree*.md"

# J. AI-cruft comments in source (project-specific paths)
grep -rnE "(per user request|review feedback|AI-generated|FIXME from|TODO\(self\))" lib/ packages/ 2>/dev/null

# L. Skill description likely over-broad (heuristic)
grep -A8 "^description:" .claude/skills/*/SKILL.md \
  | grep -iE "everywhere|cross-cutting|all repo|shared|any file"

# M. CLAUDE.md ↔ .claude/ drift (skill names mismatch)
diff <(ls .claude/skills/) <(grep -oE '`[a-z]+-[a-z]+`' CLAUDE.md | sort -u)

# N. Thin overlapping-with-CLAUDE.md skills
for s in .claude/skills/*-repo-map .claude/skills/*-build-verify \
         .claude/skills/*-overview .claude/skills/*-faq; do
  [ -d "$s" ] && echo "Candidate for CLAUDE.md inlining: $s"
done

# O. PreToolUse push-guard hooks
grep -rnE "PreToolUse.*push|push.*PreToolUse|git_push_guard" .claude/

# P. MCP tools referenced but server not declared
grep -rohE "mcp__[a-z][a-z0-9_-]+" .claude/ \
  | sort -u \
  | while read server; do
      grep -q "$server" .mcp.json ~/.claude/.mcp.json 2>/dev/null \
        || echo "MCP referenced but not declared: $server"
    done

# Q. Release-playbook agent (vs skill)
ls .claude/agents/ | grep -iE "release-(manager|playbook|coordinator)"

# R. Slash-command files that look like single-agent wrappers
for c in .claude/commands/*.md; do
  body=$(grep -v '^---' "$c" | wc -l)
  agent_calls=$(grep -cE "^@|invoke|run agent" "$c" 2>/dev/null)
  [ "$body" -lt 30 ] && [ "$agent_calls" -ge 1 ] && echo "Thin command: $c"
done

# S. Hook nudges pointing at primitive skills
grep -nE 'echo.*<prefix>-[a-z-]+' .claude/scripts/*_quality_check.sh \
  | while read line; do echo "Verify the surfaced skill has content: $line"; done

# T. Patterns describing roadmap shapes (heuristic — look for future tense)
grep -rnE "we will|should|going to|migration|in progress" .claude/skills/*/references/*-pattern.md

# U. Cheatsheets with no recent edits but heavy churn in linked code
for cs in .claude/skills/*/references/*cheatsheet*.md; do
  age_days=$(( ($(date +%s) - $(stat -f%m "$cs" 2>/dev/null || stat -c%Y "$cs")) / 86400 ))
  [ "$age_days" -gt 60 ] && echo "$cs has been $age_days days untouched — verify against codebase"
done
```

These are heuristics, not verdicts. Each hit is a prompt to read the
linked precedent and decide whether the symptom applies — most have
explicit reversal criteria.

---

## Anti-patterns (meta — about applying this catalogue)

### Treating one of these symptoms as "always wrong"

Most symptoms are wrong-by-default with explicit reversal criteria.
qbt **did** add `bp-security-auditor` (symptom F's reversal met).
qbt **does** maintain a release playbook as a *skill* (symptom Q's
non-reversal). The catalogue describes the default; the precedent
quotes describe when the default flips. Read the linked entry.

### Removing a §"Rejected alternatives" entry because "we've confirmed it's wrong"

The entry IS the prevention. If you delete it, the next proposal
re-litigates from scratch — and you've thrown away the evidence
that flipped you to "no" the first time.

**Fix:** when an entry is still "no", **strengthen the case-
against** with new evidence. When it's flipped to "yes", **update
in place** (append a "Flipped (date)" note + cross-link to where
the new shape lives). Never delete.

### Adding a hypothetical to this catalogue

Every entry in this file quotes a real precedent — drift that
actually happened, with file:line evidence. Adding "I bet
this could go wrong if…" entries dilutes the signal.

**Fix:** only add a new entry when a real precedent exists — your
own repo's history counts. Quote it, cite the file:line, and the
new entry pays its keep.

### Treating the catalogue as exhaustive

Drift happens in new shapes. This catalogue lists what's been
observed; it's not the complete list. When you spot a new mode
(in your own repo or someone else's), record it as a §"Rejected
alternatives" entry in your `claude-architecture.md` — and
eventually it lands here.

---

## See also

- [maintain-evolve.md](maintain-evolve.md) — what to do once you've
  identified a drift symptom (graduation, splits, deletions, agent
  changes)
- [agent-roster.md](agent-roster.md) — symptoms C, D, F, K, Q
  detailed under role contracts and roster-extension criteria
- [skill-design.md](skill-design.md) — symptoms A, B, E, L, S, T, U
  detailed under applicability and reference-style rules
- [enforcement-hooks.md](enforcement-hooks.md) — symptoms G, I, O, S
  detailed under hook scope and SessionStart criteria
- [architecture-doc.md](architecture-doc.md) — rejected-alternative
  4-field shape, used for recording all of these symptoms when
  observed in your own repo
- Source documents (the precedent corpus):
  - `qbt-black-phone/.claude/docs/claude-architecture.md`
  - `jolly-phonics-apps/.claude/docs/claude-architecture.md`
  - `madrosc-tlumu/.claude/docs/claude-architecture.md`
  - `qbt-black-phone/.claude/agents/bp-maintainer.md` (comment-style)
  - `jolly-phonics-apps/.claude/agents/jolly-maintainer.md` (dart_fix, reviewer-leak)
  - `jolly-phonics-apps/.claude/agents/jolly-reviewer.md` (dart_fix BLOCKER)
  - `jolly-phonics-apps/.claude/scripts/dart_mcp_setup.sh` (memory leak)
  - `jolly-phonics-apps/.claude/skills/jolly/references/worktree-gotchas.md`
  - blueprint `conventions/pattern-style.md`, `conventions/cheatsheet-style.md`
