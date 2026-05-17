---
title: Maintaining and Evolving the `.claude/` Layer
impact: CRITICAL
tags: evolution, graduation, splits, drift, decision-log, maintenance, lifecycle
---

# Maintaining and Evolving the `.claude/` Layer

## What this is

The playbook for **evolving an existing `.claude/` layer**. Creation of the
layer is covered by [bootstrap-procedure.md](bootstrap-procedure.md); the
blueprint provides shapes. This reference is about **operations on those
shapes after bootstrap** — graduating a memory entry into a skill, splitting
a skill, collapsing one back, deleting a stale skill, adding (or removing) a
path nudge, adding a domain auditor mid-project, recording a rejected
alternative once a proposal has been considered and dropped.

A healthy `.claude/` layer is **not** stable in shape — it should accumulate
rejected-alternative entries faster than it accumulates new skills, and its
graduation moves should be tracked in
`.claude/docs/claude-architecture.md` so future-you (or a teammate) can tell a
deliberate choice from an oversight, and knows what would flip the call.

## When this applies

Triggers that should make the agent **re-read
`.claude/docs/claude-architecture.md` before acting**:

- A **new techstack** joining the repo (e.g. Kotlin backend appearing in a
  Dart-only repo; Cloud Functions appearing alongside Flutter; a Next.js
  landing site getting active development).
- A **new MCP server** being considered or installed (changes the
  permission allowlist, the agent-prompt tool tables, and the rejected-
  alternative entry for "assumed MCP" if one exists).
- A **new external integration** (Linear, ClickUp, paper.design, Figma
  export, RevenueCat dashboard, GitHub Issues) that an agent or slash
  command will need to talk to.
- A **recent incident** (test slipped past review, crypto invariant broken,
  RLS hole shipped, paywall bug refunded, push payload leaked PII) — this
  is the strongest trigger for adding a domain auditor.
- A **proposal to add or remove an agent** — even before drafting the
  agent file, check the §"Agent roster" entry and the §"Rejected
  alternatives" entries (per-area maintainers, eng-manager, posture-only
  roster) to see if the proposal matches an existing reversal criterion.
- A **proposal to add a slash command** — see [slash-commands.md](slash-commands.md)
  for the "is this orchestration or a wrapper" test.
- **Repeated agent drift** — the agent keeps losing convention X across
  unrelated sessions, suggesting X belongs in a hook, a skill, or a
  CLAUDE.md row, not just project memory.
- **A skill no longer firing** on files it should (or firing on files it
  shouldn't) — applicability has drifted out of sync with the codebase.
- **A reference no longer matches the codebase** (stale paths, deleted
  classes, renamed components) — stale refs are worse than missing refs
  (blueprint `cheatsheet-style.md:114-115`).
- **A `.claude/refs/` file is referenced from only one skill** — it's
  drifted out of "cross-skill" territory and should collapse back into
  that skill's `references/`.

---

## 1. Re-reading the architecture doc — make this an explicit operation

Before any of the below operations, the agent should:

1. **Read `.claude/docs/claude-architecture.md` §"Decisions" and
   §"Rejected alternatives" in full.** Not skim — read.
2. **Check whether the proposed change matches an existing entry's
   reversal criterion.** If the answer is "yes, this is exactly what
   we said would flip the call" — proceed, and **update the entry** in
   place (don't delete it; write what changed to flip the decision).
3. **If the proposed change matches nothing listed** — it's
   *unrecorded design space*. Add a new entry in the same 4-field
   shape as part of the proposal, *before* doing the work.

The reason this discipline pays off, verbatim from the blueprint:

> "The Rejected alternatives section pays for itself. It's why future-you
> doesn't re-litigate decisions, and why someone new can tell a deliberate
> omission from an oversight." — blueprint `README.md:299-301`

**Why this matters operationally.** The rejected-alternative entries are
the *only* mechanism preventing the same proposal from being re-litigated
every few months. If you delete an entry because "we've confirmed it's
wrong now", you've removed the prevention. Keep all entries; flip them
in-place when criteria are met.

---

## 2. The graduation gradient — reversible

Content matures (and de-matures) along this gradient:

```
project memory  ←→  references/<feature>-module.md  ←→  own skill
                              (in the closest applicable skill)
```

Reversibility is the load-bearing property here. A graduation that turns
out to be premature collapses back into a `*-module.md` without
ceremony — every step has both a forward and a reverse procedure.

### 2.1 Memory → `references/<feature>-module.md` (forward)

**Trigger.** The vertical has been touched in 2+ separate sessions, has
a stable shape (entities, file locations, user flow that survives a
session reset), and you find yourself re-explaining it in project
memory.

**Mechanical steps.**

1. Identify the **closest applicable skill** — the one whose
   `applicability` already covers the file paths in question.
   If two skills could plausibly own it, the one whose
   `description:` will auto-fire when those paths are edited is the
   right home.
2. Author `<skill>/references/<feature>-module.md` per
   [skill-design.md](skill-design.md) module-style rules — business
   intent first, user flow numbered, location paths only, technical
   surface as tables. **No code dumps.**
3. Add the file to `<skill>/SKILL.md` §"Problem → reference mapping"
   *and* §"References" tables. A reference not linked from `SKILL.md`
   is invisible — `SKILL.md` always loads when the skill matches;
   `references/*.md` are doc-on-demand.
4. Delete the project-memory entries the module now subsumes.
5. **No `claude-architecture.md` entry needed** unless this is a new
   reference *style* the repo hasn't used before — in that case
   update §"Reference styles in use".

**Validation.** Edit a file in the module's path; confirm the master
skill loads (description match), then read the SKILL.md's Problem →
reference mapping and confirm the agent would land on the new module
ref from at least one user-flow phrasing.

### 2.2 `<feature>-module.md` → own skill (forward)

**Trigger.** The module has grown beyond the consuming skill's
applicability — multiple sub-flows, its own patterns, its own
cheatsheet — *and* its applicability scope is genuinely disjoint
(its paths, its file types, or its surface that wouldn't match the
parent skill's description).

> "module grows beyond the skill's applicability → own skill" — blueprint
> `README.md:316-318`

**Mechanical steps.**

1. Write the new skill's `description:` with **explicit positive AND
   negative applicability** ([skill-design.md](skill-design.md) §1).
   If you can't write the negative scope, this is not a real split —
   the content stays in the parent skill.
2. Create `<prefix>-<area>/SKILL.md` per [skill-design.md](skill-design.md)
   canonical shape. Cross-link to the parent skill from §"See also"
   ("Sister skill `<prefix>-<other>` — covers <X>").
3. Move the module reference and its accumulated siblings to
   `<new-skill>/references/`. Update internal links inside those
   files if they pointed back to the parent skill's own references.
4. Update the parent skill's `SKILL.md` — remove the migrated
   references from its Problem → reference and References tables;
   add a `See also` line pointing at the new sister.
5. Update `CLAUDE.md` Skills inventory — add a row for the new skill
   with its positive/negative applicability.
6. Update `.claude/docs/claude-architecture.md` §"Skill split" — add
   the row with positive applicability, negative applicability,
   granularity rationale.
7. If the parent skill's path nudge in `<prefix>_quality_check.sh`
   was covering the migrated paths, **split the nudge** — leave the
   parent nudge in place for what stays, add a new branch pointing at
   the new skill for what moved. Verify the new branch matches the
   new skill's `applicability` exactly ([enforcement-hooks.md](enforcement-hooks.md)).
8. Update each agent's `skills:` frontmatter if the agent should
   preload the new skill (architect/maintainer/reviewer — usually
   yes; auditors — usually no).
9. Trigger a throwaway edit on a file in the new skill's positive
   applicability; confirm description match fires and the path nudge
   surfaces the right reference.

### 2.3 Own skill → `<feature>-module.md` (reverse — collapse)

**Trigger.** A previously-split skill turned out to apply only to one
area. Symptoms:

- Description never fires when expected
- The skill's `references/` content is consumed only by the parent
  skill's domain workflows
- The split was justified by "we expect this to grow" and it hasn't,
  for ≥3 months of active development on the parent area

> "Reverse is also valid: a skill that turned out to apply only to one
> area collapses back into a `*-module.md` reference there." — blueprint
> `README.md:320-322`

**Mechanical steps.**

1. Identify the **consuming master skill** — the one whose
   applicability the orphan skill's content actually serves.
2. Move all of `<orphan>/references/*.md` into
   `<master>/references/`. Resolve filename collisions by renaming
   with a domain prefix (`<area>-<topic>-pattern.md`).
3. Update internal cross-links inside the migrated files (relative
   paths shift).
4. Delete `<orphan>/SKILL.md` and the now-empty
   `<orphan>/references/` directory.
5. Update `<master>/SKILL.md` — add the migrated references to its
   Problem → reference and References tables. Remove the See also
   line that pointed at the deleted sister.
6. Update `CLAUDE.md` Skills inventory — delete the row for the
   collapsed skill.
7. Update `claude-architecture.md` §"Skill split" — delete the row,
   then **add a §"Rejected alternatives" entry** capturing the
   experiment ("Separate `<prefix>-<area>` skill" — alternative,
   case for, case against here, reversal criterion). The
   experiment lived in your repo for months; that's worth recording.
8. Remove or fold the path nudge in `<prefix>_quality_check.sh` — if
   the collapsed skill had its own nudge, fold it back into the
   parent's nudge (same surface, same reference list).
9. Remove the orphan from each agent's `skills:` frontmatter.

---

## 3. Splitting a skill out of the master

When the master skill is firing on too broad a surface, or when an
audit / convention checklist has tightened enough that it deserves its
own description match.

**Trigger (use [skill-design.md](skill-design.md) §6 criteria):**

- The audit / convention checklist applies under a **tighter
  description** than the engineering surface.
- AND benefits from being preloaded alongside the master skill (not
  in competition).
- AND has ≥3 reference docs of audit-only material.

**Precedent.** repo-A's `bp` / `bp-security` split — engineering surface
vs adversarial audit, all agents preload both.

> "the audit checklist applies under a tighter description (confidentiality
> / integrity / RLS / push-payload contract) and benefits from being
> preloaded by all five agents alongside `bp` + `utopia-hooks`, separately
> from the engineering surface." — `production-repo-A/.claude/docs/claude-architecture.md:127`

**Mechanical steps.**

1. **Verify the rejected-alternative entry doesn't already say no.**
   Read §"Rejected alternatives" — is "keep as one master" the
   recorded choice? If yes, you need a new reversal-criterion-met
   entry update; if no, you need a new positive entry.
2. **Author the new `SKILL.md`** with positive+negative scope. The
   negative scope must explicitly disclaim the master skill's
   surface ("NOT engineering conventions — see `<prefix>`").
3. **Extract files** from `<master>/references/` to
   `<sister>/references/`. Don't copy — move. Two copies drift.
4. **Update cross-links** inside the moved files. Update the master
   skill's `SKILL.md` Problem → reference and References tables —
   the migrated rows go away, a See also line for the new sister
   appears.
5. **Update agent `skills:` frontmatter** for every agent that should
   preload the new skill. Typically all four standard agents preload
   it (the audit perspective is a posture, not a single role).
6. **Update `<prefix>_quality_check.sh`** — add a new path-nudge
   branch where the new skill applies, OR adjust the existing
   nudges to surface *both* skills on shared paths (repo-A's
   crypto-path nudge surfaces `bp` *and* `bp-security`).
7. **Update `CLAUDE.md`** — add the new skill to the Skills
   inventory; if you have an "agents preload" sentence anywhere
   ("All agents preload `<prefix>` + `utopia-hooks`"), update it.
8. **Update `claude-architecture.md`** §"Skill split" table with the
   new row. Add a §"Rejected alternatives" entry if "keep as one
   master skill" was a real candidate (it usually was) — alternative,
   case for, case against here, reversal criterion.
9. **Validate.** Trigger description match on a file in the new
   skill's positive applicability; confirm both master and sister
   load when both apply; confirm the negative scope keeps the
   wrong-stack files from loading.

---

## 4. Collapsing a skill back into a reference

The reverse of §3 — when a previously-split skill turns out not to
have earned its keep.

**Symptoms:**

- Description never fires usefully — the agent reads `description:`
  matches and the skill loads on files it can't act on under that
  posture.
- `references/` content only ever cross-loads with the parent skill
  — every workflow that touches the sister also touches the master.
- The reversal-criterion entry from §3 is met ("if `<sister>` never
  accumulates references beyond pointers to `.claude/refs/`, the
  separation pays no rent" — repoC's pre-recorded reversal).

> "If `repoC-functions` never accumulates references beyond pointers
> to `.claude/refs/`, the separation pays no rent. Re-consolidate by
> collapsing it back into `repoC` references and deleting the
> standalone `SKILL.md`." — `production-repo-C/.claude/docs/claude-architecture.md:117`

**Mechanical steps.** Same as §2.3 (own skill → module) — move
references into the consuming master, delete `SKILL.md`, update
inventory + architecture doc + path nudges + agent frontmatter.

**Hard rule:** when you collapse, you **update the §"Rejected
alternatives" entry that flipped** — record what flipped it (the
specific evidence) and re-frame the case-against as "case for the
collapse". Don't delete the original split rationale — future-you may
re-encounter the same pressure to split.

---

## 5. Deleting a stale skill (vs collapsing it)

Different from collapse. **Delete** when:

- Description hasn't fired in N PRs (N ≥ 10 is a reasonable threshold)
- ALL references have moved elsewhere (to other skills' `references/`
  or to `.claude/refs/`)
- The content overlaps with `CLAUDE.md`'s always-loaded inventory
- The skill was a "FAQ skill" that turned out to be better expressed
  as inline `CLAUDE.md` rows

**Precedent.** repo-A rejected `bp-repo-map` and `bp-build-verify` for
exactly this reason — content was thin and overlapped with
`CLAUDE.md`:

> "Content is thin and overlaps with `CLAUDE.md`. `CLAUDE.md` loads on
> every turn; the skill would only load on description match.
> Inlining the content into `CLAUDE.md` makes it unconditionally
> available at lower context cost." — `production-repo-A/.claude/docs/claude-architecture.md:256-258`

**Mechanical steps.**

1. **Migrate any content worth keeping** to `CLAUDE.md` (Skills /
   Agents / Slash-command tables; topology section; common
   commands) or to a sister skill's references.
2. **Remove the skill directory** (`rm -rf .claude/skills/<prefix>-<area>/`).
3. **Update `CLAUDE.md`** Skills inventory.
4. **Update `claude-architecture.md`** — delete the §"Skill split"
   row; **add a §"Rejected alternatives" entry** for the deletion
   (`<prefix>-<area>` skill: alternative kept as a standalone skill /
   case for / case against here / reversal criterion). The
   experiment is now a documented dead end.
5. **Remove path nudges** pointing at the deleted skill.
6. **Remove from agent `skills:` frontmatter.**
7. **Validate.** Run `<prefix>_skills_drift.sh` to confirm no
   dangling links to the deleted skill remain anywhere
   (`CLAUDE.md`, `.claude/refs/`, sibling SKILL.md files, agent
   prompts).

---

## 6. Adding a path nudge incrementally

When a surface has accumulated **≥2 references** that the agent
should consult, deterministic path nudging starts to pay rent.

**The ≥2-references rule.** Single-reference surfaces are better
served by description matching alone — adding a nudge for one
reference clutters the hook without giving the agent more than the
description already provides.

> "While `repoB-api` is primitive there's no reference worth nudging
> the agent to read. Adding a nudge that points at 'no content yet'
> wastes a hook firing." — `production-repo-B/.claude/docs/claude-architecture.md:175-178`

> "Reversal criterion. `repoC-functions` accumulates 2+ references —
> wire path nudges then." — `production-repo-C/.claude/docs/claude-architecture.md:145`

**Mechanical steps.**

1. **Verify the path pattern matches the skill's `applicability`
   EXACTLY.** A nudge that fires on a path the skill's description
   wouldn't auto-match surfaces the wrong skill — defeating the
   determinism the nudge is supposed to deliver.
2. **Add the `case/esac` branch** to `<prefix>_quality_check.sh`,
   inside the existing path-routing block. Mirror the indentation,
   exit code, and message format of the existing branches.
3. **Trigger a throwaway edit** on a real file in the surface to
   validate the firing (`touch <path>/probe.dart`, edit it, observe
   the hook output, revert).
4. **Document the addition** in `claude-architecture.md` §"Hook
   scope" (or §"Enforcement mode") — the path → skill mapping is
   now part of the deterministic surface.
5. **Don't** preemptively add nudges for "future" content. The
   blueprint warning is explicit: a nudge pointing at no-content-yet
   is wasted firing.

---

## 7. Removing a hook nudge

When a surface no longer has references worth surfacing — content
moved to a different skill, or the references were deleted because a
tool now enforces what they documented.

**Mechanical steps.**

1. **Remove the `case` branch** in `<prefix>_quality_check.sh`. Do
   not delete the script — just thin the surface.
2. **Update `claude-architecture.md`** §"Hook scope" — record that
   the nudge was removed and why (avoid the next contributor
   re-adding it).
3. **Leave generated-file blocks alone.** Removing a `*.g.dart`
   block needs explicit reasoning recorded in §"Enforcement mode";
   it's a different conversation from path nudges.

---

## 8. Adding a domain auditor mid-project

The standard roster is four. A fifth requires written justification
in `claude-architecture.md` §"Agent roster" — see
[agent-roster.md](agent-roster.md) for the decision criteria.

**Mechanical steps.**

1. **Document the trigger** — the incident, the threat-surface
   change, or the audit checklist that the standard reviewer can't
   carry without bloating its prompt. Without a documented trigger,
   the agent is roster-creep and `agent-roster.md` says don't.
2. **Write the agent file** with `tools: Read, Grep, Glob, Bash`
   (read-only — auditors don't write) and `skills:` preloading
   `<prefix>-<master-skill>`, `<prefix>-<domain-skill>` (if you also
   split out a domain skill — repo-A's `bp-security` for the
   `bp-security-auditor`), `utopia-hooks`.
3. **Update the architect / maintainer / reviewer prompts** —
   add a "When to route to `<prefix>-<domain>-auditor`" hand-off
   block. Don't bury this in the master skill — it's posture
   protocol, not engineering convention.
4. **Update CLAUDE.md** §"When to invoke" — add a row for the new
   agent with its trigger paths.
5. **Update slash commands** that gate on the domain
   (e.g. repo-A's `/bp-team` gates security-sensitive PRs on a
   `bp-security-auditor` pass).
6. **Update `claude-architecture.md`** §"Agent roster" with the new
   agent and the incident/threat-surface justification. Update §"Rejected
   alternatives" if "no domain auditor" had been the recorded choice
   ("…considered, deferred until an incident motivates it" is repoB
   and repoC's standing entry — flip in place when met).

---

## 9. Recording a rejected alternative mid-project

Even if you **didn't** do the thing, write it down. Future-you will
re-propose it without this entry.

**Use the 4-field shape** ([architecture-doc.md](architecture-doc.md)
has the canonical form):

```
### <Short alternative name>

- **Alternative.** <What was considered. What it would look like
  concretely if adopted.>
- **Case for.** <Why a reasonable person would propose this; the
  real upside.>
- **Case against here.** <Why this repo / this team / this
  cadence rejected it. Evidence, not opinion.>
- **Reversal criterion.** <The specific observable that would
  flip the call. "If X happens, re-open."> 
```

**Append to `claude-architecture.md` §"Rejected alternatives"** —
**never delete prior entries.** They remain valuable as the project
changes, even (especially) the ones that are still rejected. The
entry IS the prevention.

**When a previously-rejected alternative IS reversed** (criterion
met): **update the entry, don't delete it.** Re-frame:

- The original `case against here` becomes a history note.
- Append: "**Flipped (date / context).** <What changed.> **New
  status:** adopted / partial / pending."
- Cross-link the §"Decisions" or §"Skill split" row that now owns
  the adopted shape.

This way the §"Rejected alternatives" section serves double duty:
*current rejections* (for prevention) and *historical flips* (so
future-you sees what kind of evidence has tipped which decisions).

---

## 10. Updating an agent prompt

When adding a new hand-off, a new invariant, or a new comment-style
anti-pattern.

**Hard constraint: keep the role contract unchanged.** Architect
plans; maintainer writes; reviewer reads on fresh context; auditor
gates the staged diff. Do **not** edit the role line at the top of
the agent prompt as part of a "small update" — that's the
foundation of the orchestration loop. See [agent-roster.md](agent-roster.md).

**What to update freely:**

- The Invariants list (add a new one, never remove without
  architecture-doc justification).
- The Anti-patterns block (new symptoms observed in practice).
- The Tooling preferences table (when a new MCP joins).
- The Hand-off format (when a new field becomes useful).

**Lifting to a shared `.claude/refs/agent-conventions.md`.** If the
same change has appeared in two or more agents' prompts independently
(e.g. the same comment-style block, the same `dart_fix` warning, the
same hand-off field), consider lifting the shared text to
`.claude/refs/agent-conventions.md` and linking from each agent's
prompt. Drift across agent prompts is its own anti-pattern: the
reviewer's comment rules and the maintainer's comment rules **must**
match exactly.

---

## 11. Updating `CLAUDE.md`

Two-pronged drift target: it must (a) match every artefact in
`.claude/`, and (b) stay tight enough to not bloat top-of-context.

**Update CLAUDE.md whenever you:**

- Add / remove / rename a skill → Skills inventory table
- Add / remove / rename an agent → Agents table + When-to-invoke
- Add / remove a slash command → Slash commands table
- Add / change a top-level common command (build, test, format) →
  Common commands block
- Add or remove a foundation plugin from `enabledPlugins` →
  Foundation paragraph

**Update CLAUDE.md whenever the architecture doc changes** in a way
that contradicts what `CLAUDE.md` describes (e.g. you flipped a
rejected-alternative entry into a `Decisions` row).

**Run `/<prefix>-audit-skills`** after CLAUDE.md edits — the drift
scanner will flag dead links, but logical drift (described skill
that no longer exists; agent missing from the table) is on the
author. The precommit-auditor catches this too:

> "**CLAUDE.md / `.claude/docs/` edits** — must keep CLAUDE.md
> internally consistent (skill table, agent table, hook list, 'When
> to invoke' table). Flag mismatches. **COMMIT-FIX-FIRST**." —
> `production-repo-A/.claude/agents/bp-precommit-auditor.md:120-122`

---

## 12. When `.claude/refs/` content needs to move

A `.claude/refs/<doc>.md` is **only** justified when ≥2 skills link
to it from their `See also`. Drift happens both ways:

- **Single-consumer ref** (only one skill links to it) → collapse
  back into that skill's `references/`. The "shared" status was
  aspirational.
- **Skill-specific content drifted into refs/** → move back to the
  consuming skill's `references/`. Refs are passive markdown
  surfaced via See also; if the content is part of a workflow inside
  one skill, the skill's `references/` is the right home.

**Mechanical steps.**

1. Move the file.
2. Update the consuming skill's `SKILL.md` — both See also and
   References tables.
3. If the file was linked from `claude-architecture.md` (some
   refs/'s `freezed.md`, `code-generation.md` etc. are quoted in
   the decision log), update those cross-links.
4. Run `<prefix>_skills_drift.sh` to catch any dangling links you
   missed.

---

## Anti-patterns (evolution operations)

### Splitting a skill without a `claude-architecture.md` update

A new SKILL.md appears, references move, agent frontmatter updates —
but §"Skill split" still shows the old shape, and no §"Rejected
alternatives" entry says "keep as one master was considered".
Future-you re-proposes the merge and finds no recorded reasoning to
push back with. **Fix:** every split lands in the same PR that
updates the architecture doc.

### Deleting a stale skill without a §"Rejected alternatives" entry

The experiment is now an undocumented dead end — and the next time
someone proposes the same skill, the case-against has to be
rediscovered from scratch. **Fix:** the deletion PR includes the
new §"Rejected alternatives" entry with the experiment's evidence
(why it was tried, why it didn't work, what would flip the call).

### Adding a path nudge that doesn't match the skill's applicability

The hook fires on a path; the description on the surfaced skill
doesn't actually match those files; the agent reads conventions
that don't apply to the file it's editing. Silent mis-fire — worse
than no nudge, because the agent now has wrong-direction context.
**Fix:** before adding a nudge, verify the surfaced skill's
positive applicability includes the path pattern. If not, fix the
description or the path glob, not both.

### Adding an agent without an incident or threat-surface justification

The standard four-agent roster covers the engineering surface for
every repo we've shipped. Adding a fifth is reversible (you can
collapse it back), but every additional agent adds description-
matching noise on every turn. **Fix:** before drafting the agent
file, write the §"Agent roster" entry — the documented incident or
threat-surface change. If you can't write it, the agent shouldn't
exist.

### Deleting a §"Rejected alternatives" entry because "we don't need to remember that"

You DO. Future-you re-proposes it. The entry IS the prevention.
**Fix:** when an entry feels obsolete, flip it in place — append a
"Flipped (date / context)" line if criteria were met, or sharpen the
case-against if the rejection is still right.

### Updating an agent's role contract instead of its invariants

The four agent roles are the orchestration's foundation. An
architect that "now also implements small fixes" breaks the read-
only-planner posture; a maintainer that "reviews its own work before
hand-off" leaks reasoning into the reviewer's input. **Fix:** new
behaviour goes into the Invariants list, not the role line. If the
behaviour requires a different posture, you're adding a new agent —
go through §8 first.

### Adding a slash-command wrapper around a single agent

Direct agent invocation already gives subagent isolation; a wrapper
adds a layer and splits context. repo-A's `/bp-review` was rejected for
exactly this:

> "The reviewer agent is the entire value; the wrapper adds a layer
> and splits context across multiple agents. Direct invocation of
> `bp-reviewer` by name gives subagent isolation with a clean
> context and no wrapper overhead." — `production-repo-A/.claude/docs/claude-architecture.md:249-251`

**Fix:** slash commands are for **orchestration** (multi-step,
fan-out, conditional flow). For single-agent invocations, rely on
description matching and explicit `@<agent-name>` mentions.

### Treating the architecture doc as write-once

`claude-architecture.md` is a **living** document. If you've done
three operations on the layer this month and the doc hasn't been
touched, something is undocumented. **Fix:** the operations above
all end with "update `claude-architecture.md`" — make that step
non-optional.

### Letting `.claude/refs/` and `references/` content drift apart

If `.claude/refs/freezed.md` and `<prefix>/references/freezed.md`
both exist (or worse, contradict each other), the agent doesn't
know which one binds. **Fix:** one canonical location per topic.
The "is this cross-skill?" test is empirical — count the
consuming skills' See also links. ≥2 → refs/. 1 → that skill's
references/.

---

## Self-audit checklist (run after any evolution operation)

1. Did `.claude/docs/claude-architecture.md` get an update reflecting
   the change?
2. Did `CLAUDE.md` get updates to its inventory tables matching
   what's in `.claude/` now?
3. Did the relevant `SKILL.md`(s) update their Problem → reference
   and References tables?
4. Did agent `skills:` frontmatter get updated where preloading
   changed?
5. Did path nudges in `<prefix>_quality_check.sh` get updated /
   added / removed to match the new shape?
6. Did `<prefix>_skills_drift.sh` (or `/<prefix>-audit-skills`)
   come back clean — no dead links anywhere?
7. If a previously-rejected alternative was reversed, did the entry
   get flipped in place (not deleted)?
8. If a previously-applied decision was reversed, did a fresh
   §"Rejected alternatives" entry capture the experiment?
9. Did a throwaway edit confirm the firing surface (description
   match + path nudge) actually loads what you intended?

---

## See also

- [layer-model.md](layer-model.md) — foundation vs project boundary;
  `.claude/refs/` vs `.claude/docs/` discipline
- [agent-roster.md](agent-roster.md) — the four standard agents; when
  to extend; never remove the maintainer
- [skill-design.md](skill-design.md) — applicability scopes, no-router,
  the three reference styles, split criteria
- [enforcement-hooks.md](enforcement-hooks.md) — `<prefix>_quality_check.sh`
  shape and the path-nudge contract
- [slash-commands.md](slash-commands.md) — when a slash command is
  orchestration vs a wrapper
- [architecture-doc.md](architecture-doc.md) — `claude-architecture.md`
  9-section spine; rejected-alternative 4-field entry shape
- [claude-md.md](claude-md.md) — what stays in `CLAUDE.md` vs
  graduates into a skill
- [drift-symptoms.md](drift-symptoms.md) — the empirical failure-mode
  catalogue; what to grep for during an audit
- [bootstrap-procedure.md](bootstrap-procedure.md) — creating the
  layer from scratch
