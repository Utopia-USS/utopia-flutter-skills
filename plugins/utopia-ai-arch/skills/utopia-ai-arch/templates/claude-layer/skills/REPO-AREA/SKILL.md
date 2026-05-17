---
name: <repo>-<area>
description: |
  <Short one-line summary of what this skill knows.>

  Applicability — POSITIVE: <paths / surface where this applies>.
  Applicability — NEGATIVE: NOT <paths / surface where this explicitly does NOT apply>.

  Layered on top of the upstream `utopia-hooks` plugin — this skill stays
  silent on hook idioms / Screen-State-View / async patterns / DI / IList
  / strict analyzer (those are foundation concerns).
---

<!-- BLUEPRINT — adapt per-repo. Strip this banner after substitution. -->

# <repo>-<area>

<One-paragraph framing: what this skill owns and why it has its own
applicability scope. Refer back to the `applicability` in the
frontmatter — do not repeat it here, reference it.>

## Relationship to the foundation

Foundation (`utopia-hooks`) owns:

| Concern | Owner |
|---|---|
| Screen / State / View pattern | `utopia-hooks` |
| Hook catalog | `utopia-hooks` |
| Async patterns (download / upload / streams) | `utopia-hooks` |
| Global state, DI bridge | `utopia-hooks` |
| IList/IMap/ISet, strict analyzer, lambda style | `utopia-hooks` |

This skill adds:

| Concern | Reference |
|---|---|
| <project-specific concern A> | [<area>-<topic>.md](references/<area>-<topic>.md) |
| <project-specific concern B> | [<other-topic>.md](references/<other-topic>.md) |

## Problem → reference mapping

| Problem | Start with |
|---|---|
| <typical question / task> | [<reference>.md](references/<reference>.md) |
| ... | ... |

## See also

Cross-skill links live here, not deep in references. Keep them in
this section so they're visible whenever this skill loads.

- Shared snippet: [`.claude/refs/<shared-doc>.md`](../../refs/<shared-doc>.md)
  — <one-line why this is consulted>
- Related skill: [`<repo>-<other-area>`](../<repo>-<other-area>/SKILL.md)
  — <one-line when to switch>

## Non-negotiable

- <Rule that the hook can't enforce but agents must follow.>
- <Another such rule.>

## References

| File | Style | Impact | Description |
|---|---|---|---|
| [<feature>-module.md](references/<feature>-module.md) | module | <CRITICAL/HIGH/MEDIUM> | <business feature with user flow> |
| [<area>-<topic>.md](references/<area>-<topic>.md) | pattern | <impact> | <cross-cutting convention> |
| [<area>-cheatsheet.md](references/<area>-cheatsheet.md) | cheat-sheet | <impact> | <inventory / lookup map> |

Reference styles:

- **`*-module.md`** — business module (lead with user flow). Authoring
  guide: `utopia-ai-arch:templates/conventions/module-style.md`.
- **`*-pattern.md` / `*-system.md` / `*-services.md` / `*-models.md`** —
  cross-cutting convention (lead with rules + why). Authoring guide:
  `utopia-ai-arch:templates/conventions/pattern-style.md`.
- **`*-cheatsheet.md` / `*-catalogue.md`** — flat lookup / inventory.
  Authoring guide:
  `utopia-ai-arch:templates/conventions/cheatsheet-style.md`.

## Self-audit checklist

After editing within this skill's applicability, verify:

1. <repo-specific check, e.g. naming, registration, code-gen freshness>
2. ...
3. Static analysis clean.
