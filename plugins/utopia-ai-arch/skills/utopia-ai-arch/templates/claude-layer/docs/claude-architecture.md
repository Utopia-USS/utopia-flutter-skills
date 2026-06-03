<!-- BLUEPRINT — adapt per-repo. Strip this banner after substitution. -->

# Claude Architecture — <project name>

How this repo's `.claude/` layer is shaped, on top of the `utopia-hooks`
foundation plugin. Decisions live here; rationale is documented so that
future-you (or a teammate) can tell a deliberate choice from an
oversight, and knows what would flip the decision.

Blueprint: the `utopia-ai-arch` Claude Code skill (its
`templates/README.md` is the model). This file is the per-repo
**decision log**; conventions and authoring guides stay in the skill
(not copied here).

## 1. Two layers

(Foundation + project, as in the blueprint README §1. Restate briefly
here so this doc stands alone.)

## 2. Skill split

| Skill | Positive applicability | Negative applicability | Granularity rationale |
|---|---|---|---|
| `<repo>-<area>` | <paths / surface> | <where it does NOT apply> | <why this boundary> |

**No router skill.** Routing is solved by `CLAUDE.md` (always-on
inventory), the path-matching hook (deterministic surfacing), and
per-skill `applicability` (autonomous load). See blueprint §2.

**No cross-cutting "shared" skill.** Cross-skill snippets live in
`.claude/refs/`, linked from each consuming `SKILL.md` "See also".
See blueprint §4.

## 3. Reference styles in use

For each skill, record which reference styles it employs and why.
Authoring guides live in the `utopia-ai-arch` skill (not copied per-repo):
`utopia-ai-arch:templates/conventions/{module-style,pattern-style,cheatsheet-style}.md`.

| Skill | Modules (`*-module.md`) | Patterns (`*-pattern.md`) | Cheat-sheets (`*-cheatsheet.md`) |
|---|---|---|---|
| `<repo>-<area>` | <list> | <list> | <list> |

## 4. Agent roster additions

The standard four (`<repo>-architect`, `<repo>-maintainer`,
`<repo>-reviewer`, `<repo>-precommit-auditor`) are always present.
Document only domain auditors added beyond the standard set:

| Agent | Why this repo needs it |
|---|---|
| `<repo>-<domain>-auditor` | <critical surface that warrants a dedicated review pass> |

## 5. Enforcement mode

- Hard block: edits to generated files (`*.g.dart`, `*.freezed.dart`,
  `<other>`).
- Default mode: `warn` (exit 1) on path-match nudges and convention
  violations.
- `block` (exit 2) switchable via `<REPO>_QUALITY_MODE=block`.

## 6. Slash commands

The standard three (`/<repo>-implement`, `/<repo>-audit`,
`/<repo>-audit-skills`) are always present. Document only additions
or omissions and why.

## 7. Hook scope

Hook fires for `Edit | Write | MultiEdit` on Dart files under a
workspace pubspec. Out-of-scope edits exit silently. Path → skill
nudges mirror each skill's `applicability` from §2.

## 8. Rejected alternatives

Each entry: **alternative · case for · case against here · reversal criterion.**

### <Example: per-domain skills instead of <chosen split>>

- **Alternative.** <description>
- **Case for.** <when this would be right>
- **Case against here.** <why it isn't right for this repo>
- **Reversal criterion.** <observable signal that would flip>

(Add an entry for every non-trivial design choice that was considered
and not taken. The point of this section is to prevent re-litigation
and to make deliberate omissions visible.)

## 9. Rollout status

1. Foundation wiring — <status>
2. Skeleton — <status>
3. Enforcement — <status>
4. Agents — <status>
5. Skills — <status>
6. CLAUDE.md trim — <status>
7. Validation — <status>
