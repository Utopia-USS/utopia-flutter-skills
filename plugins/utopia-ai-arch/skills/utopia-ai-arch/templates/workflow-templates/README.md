# workflow-templates/

Workflow-style add-ons. **Opt-in only.** Each bundle here is copied + adapted
into a repo's `.claude/` *only* when `bootstrap-procedure.md` §"0.4 External
integrations" confirms the team actually uses the underlying tool or routine.

The auto-inspectable subset of templates (the core skill, the master command,
the always-fires agents) lives one level up under `templates/` and is covered
by `skill-design.md`, `agent-design.md`, and `slash-commands.md`. This
directory is the **user-driven** add-on layer — nothing in it should be
installed without an explicit signal from the team prompt.

## Decision matrix

| Bundle              | Skill? | Command? | Open-when signal                                              | Production precedent | Reversal criterion (when to reject) |
|---------------------|:------:|:--------:|---------------------------------------------------------------|----------------------|--------------------------------------|
| `browser-testing/`  | yes    | no       | Repo has a buildable web target (Flutter web, admin web, Next.js landing) — auto-inspectable | across multiple production repos    | No web target compiles; team verifies via emulator / device only |
| `design/`           | yes    | yes      | Team uses paper.design MCP, claude.design handoff bundles, or Figma export — **ask in Phase 0.5** | acme                | No design-tool integration; designs arrive as PNGs / Slack screenshots |
| `ship/`             | no     | yes      | Team uses external ticketing (Linear / ClickUp / Jira) with required commit-message format — **ask in Phase 0.5** | acme                | No ticketing tool, or commits don't reference tickets |
| `plan/`             | no     | yes      | PRs frequently span 3+ packages / workspaces and benefit from a plan-only invocation — **ask in Phase 0.5** | production-repo                  | Most PRs touch a single package; planning is inline in `/implement` |
| `team/`             | no     | yes      | PRs routinely split into 2+ genuinely disjoint chunks worth implementing in parallel — **ask in Phase 0.5** | production-repo                  | Work is mostly sequential; parallel maintainer fan-out adds coordination overhead with no wall-clock win |

Only `browser-testing/` is auto-inspectable. The remaining four require an
explicit Phase 0.5 user prompt — listing them on a probe and asking the team
to confirm is the canonical path.

## Per-bundle navigation

- `browser-testing/README.md` — skill-only; web-target verification flow with
  Chrome DevTools MCP / Claude_Preview MCP.
- `design/README.md` — skill + command **pair**; design → code orchestration
  with paper.design or claude.design as the source.
- `ship/README.md` — command-only; commit-breakdown + ticketing-sync + branch
  + push.
- `plan/README.md` — command-only; architect-driven plan-only invocation for
  multi-package work.
- `team/README.md` — command-only; architect → parallel maintainers → reviewer
  → precommit-auditor orchestration.

## Substitution conventions

Across all bundles, the following placeholders appear and must be replaced
before checking the result into a repo:

- `<prefix>` — repo command/agent prefix (`acme`, `acme`, `acme`, …).
- `<repo-web-target>` — directory name of the Flutter-web or web app
  (`classroom`, `admin`, `packages/app`, …).
- `<ticketing-tool>` — ticketing system name (Linear / ClickUp / Jira).
- `<feature>`, `<TICKET>` — call-time placeholders, leave for the agent.

Each file carries a banner at the top describing what to substitute. **Strip
the banner once substitution is complete** — it's a template marker, not
load-bearing content.

## Workflow-style format exception

Two of these bundles ship workflow-style **skills** (`browser-testing/`,
`design/`) that intentionally do not follow the module / pattern / cheatsheet
trichotomy documented in `skill-design.md`. The trichotomy is for *foundation*
skills that auto-fire on path globs; workflow skills are loaded ad-hoc by an
agent or command and are organised around steps, tools, and recovery patterns.
The banner in each skill calls this out explicitly. See `skill-design.md`
§"Workflow-style exception" if you need the long-form rationale.

## See also

- `../skill-design.md` — foundation-skill format; explains why workflow skills
  are an exception.
- `../slash-commands.md` — command anatomy that the command-bearing bundles
  follow.
- `../bootstrap-procedure.md` §"0.4 External integrations" — the user-prompts
  that gate each bundle.
