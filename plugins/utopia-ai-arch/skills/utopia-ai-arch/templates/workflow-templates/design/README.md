# design bundle

Skill + command pair. Installs a design-source-reading skill at
`.claude/skills/<prefix>-design/SKILL.md` and a design-to-code orchestrator
command at `.claude/commands/<prefix>-design.md`. They are co-installed —
the command references the skill, and the skill references the command.

## When to open

Open this bundle only when the team has a real design-tool integration in
their workflow:

- **paper.design MCP** is configured and used by designers, or
- **claude.design** handoff bundles (`.claude-handoff/` directory,
  `PROMPT.md`) are part of the design-to-code handoff, or
- **Figma** export → markdown / tokens bundle is part of the workflow.

**Not auto-inspectable.** Phase 0.5 must surface this with a user prompt:

> *"Do you use a design tool with an agent integration — paper.design,
> claude.design handoff bundles, or a Figma export bundle?"*

If the answer is no (designs arrive as PNGs / Slack screenshots / Figma
links the human translates by eye), reject this bundle. The workflow value
is in reading structured design data; without that, the orchestrator has
nothing to load.

## Reversal — when **not** to open

- No design-tool integration. Designs arrive as flat images.
- Designs are translated by the human and handed to the agent as a
  prose-only spec.
- The team builds non-UI software (CLI, backend services) — no visual
  design surface to translate.

## What this bundle ships

Two co-installed files:

- `skill/<prefix>-design/SKILL.md` — **how to consume designs**. Acquisition
  workflows for paper.design (`get_jsx`, `get_tree_summary`,
  `get_screenshot`) and claude.design (handoff bundle structure). Defers
  component selection to the master skill and state patterns to
  `utopia-hooks`.
- `command/<prefix>-design.md` — **design → code orchestrator**. Acquires
  the design, runs architect → maintainer ↔ reviewer with reviewer-fresh-
  context discipline and a retry cap of 2. Does not commit.

The two are co-installed — neither makes sense alone.

## Substitution checklist

- `<prefix>` — repo command/agent prefix (`acme`, `acme`, `acme`, …).
  Appears in:
  - skill name (`<prefix>-design`)
  - command name (`/<prefix>-design`)
  - agent references (`<prefix>-architect`, `<prefix>-maintainer`,
    `<prefix>-reviewer`)
  - any cross-skill references in the body
- Master skill name — wherever the skill body refers to the master skill
  by name (e.g. `acme` → `<master-skill-name>`).
- Design-system references — `the project component catalogue` is repo-specific (example); replace with
  the team's design-system name (`AppKit`, `<repo>-ui`, etc.).

## Production precedent

`acme` is the only repo currently shipping this bundle. The command and
skill are tightly coupled: the command's Step 0 acquisition mirrors the
skill's Design Sources section verbatim, and the skill's Translation
Workflow is what the maintainer executes inside the command's loop.

## Load-bearing pieces — keep when adapting

- **Reviewer-fresh-context discipline.** The command passes only
  `files_touched`, `proposed_commit_message`, and `baseline_analyze` to the
  reviewer — *never* the maintainer's reasoning or self-report.
- **Retry cap = 2.** Maintainer → reviewer fail → maintainer retries once
  → reviewer again. If still failing, stop and hand both reports to the
  user.
- **Step 0 acquisition logic.** Two-source detection (paper vs handoff vs
  auto-detect) lives here; do not collapse to one source.
- **Skill ↔ command pairing.** The skill mentions the command in its
  "See also"; the command mentions the skill as the body of knowledge the
  maintainer relies on. Keep both pointers when renaming.
- **Design-brief format.** The compiled brief is what gets passed from
  Step 0 into the architect prompt and the maintainer prompt — keep its
  structure intact.

## Strip-the-banner reminder

Both files ship with `<!-- TEMPLATE -->` banners. Remove them once
substitution is complete.
