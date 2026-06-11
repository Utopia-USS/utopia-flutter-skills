# utopia_cli - Deterministic Backend for Agents

The `utopia` CLI ([utopia_cli](https://pub.dev/packages/utopia_cli)) is the deterministic
backend for the conventions this skill teaches: project inspection, screen scaffolding,
and convention validation. The same rule engine serves Claude Code (PostToolUse hook),
Codex/shell agents (`AGENTS.md` from `utopia init agents`), MCP, and CI - so prefer the
CLI over hand-rolled greps or manual file creation whenever one of its surfaces fits.

All JSON outputs use project-root-relative paths with forward slashes (on Windows too)
and carry a `schema_version` field. Machine-readable JSON goes to stdout; human
summaries, when enabled, go to stderr.

## Install / Detect

```bash
command -v utopia || dart pub global activate utopia_cli
utopia --version
```

The plugin's SessionStart hook reports whether the CLI is available. Without it the
PostToolUse convention gate cannot run.

## Agent Workflow: Inspect -> Generate -> Validate

| Step | Command | When |
|------|---------|------|
| Inspect | `utopia describe -o -` | Before structural changes (new screen, global state, routing) |
| Inspect | `utopia describe --routes-only -o -` | Cheap route/path enumeration |
| Generate | `utopia add screen <name> --json` | Adding a new screen |
| Validate | `utopia hooks analyze` (variants below) | Per-file / per-edit convention checks |
| Validate | `utopia doctor --fail-on=warning --human -o -` | Repo-wide audit, CI gate |

## Inspect: `utopia describe`

Emits project structure as JSON (`schema_version: 1`): packages (Melos/workspace aware),
screens with kinds (routed / sheet / dialog / non_routed_page / subscreen_fragment /
bare_screen / auto_route_page), routing strategy, global states, services, and
foreign-framework artifacts. Unresolved references surface as discovery notes instead
of being silently skipped.

```bash
utopia describe -o -                  # full structure
utopia describe --routes-only -o -    # routes view only
utopia describe -C path/to/project    # explicit project root
```

Use it instead of grepping the project tree when you need the route table, the list of
existing screens/global states, or the package layout of a monorepo.

## Generate: `utopia add screen`

Scaffolds the Screen/State/View triad at `lib/screen/<name>/`:

```
lib/screen/<name>/
├── <name>_screen.dart           # HookWidget - wires state into view
├── state/<name>_state.dart      # State class + use<Name>State() hook
└── view/<name>_view.dart        # pure StatelessWidget
```

```bash
utopia add screen profile --json     # machine-readable summary
utopia add screen profile -r /me     # custom route path
```

The JSON summary lists created files and reports `route_registered: false` - the CLI
does NOT touch `app_routing.dart`. Register the route manually (the CLI prints a
pastable snippet in human mode). Scaffold first, then fill in logic following
[screen-state-view.md](screen-state-view.md); never hand-create the triad files.

## Validate Per-File: `utopia hooks analyze`

The canonical Screen/State/View rule engine. The PostToolUse hook in this plugin runs
it on every Dart edit; the variants below are for manual/agent/CI use:

| Context | Command |
|---------|---------|
| One edited file from an agent hook | `utopia hooks analyze --hook-json` (reads hook JSON from stdin) |
| One file manually | `utopia hooks analyze --file <path>` |
| Batch of files | `utopia hooks analyze <path> <path>` |
| Changed git files | `utopia hooks analyze` |
| Whole project / CI | `utopia hooks analyze --all --format=json` |

`--fail-on error|warning|info|never` controls the exit-code gate (default: `warning`).

## Validate Repo-Wide: `utopia doctor`

Full-project audit complementing the per-edit hook: catches drift the per-file gate
cannot see (setup problems, orphan state files, foreign-framework leftovers).

```bash
utopia doctor --fail-on=warning --human -o -    # CI gate + human summary on stderr
utopia doctor --check=artifacts:bloc            # only selected tags
utopia doctor --file lib/screen/x/state/x_state.dart -o -   # per-file rules under the doctor JSON contract
```

Tags for `--check` / `--skip`:

| Tag | Covers |
|-----|--------|
| `setup` | pubspec coherence, `utopia_lints`, `.claude/` settings, plugin enablement |
| `conventions` | per-file utopia_hooks rules scanned repo-wide |
| `artifacts` | foreign frameworks; sub-tags `artifacts:bloc`, `:riverpod`, `:provider`, `:mobx`, `:getx`, `:stateful` |
| `imports` | banned direct imports (`package:flutter_hooks/`) |
| `structure` | cross-file invariants (orphan state files, ...) |

Artifact sub-tags activate only when the matching dependency is in the pubspec;
`--strict` bypasses all gates. Findings carry `rule_id`, `severity`, `message`,
`file`/`line`, and `package` (monorepo package name, `null` for root-level findings).

## MCP Server: `utopia mcp`

For repeated structured calls in a session, register the MCP server:

```bash
claude mcp add -s user utopia -- utopia mcp
```

| Tool | Wraps |
|------|-------|
| `describe` | `utopia describe` |
| `describe_routes` | `utopia describe --routes-only` |
| `doctor` | `utopia doctor` |
| `analyze_hooks_files` | `utopia hooks analyze --file ...` |
| `analyze_hooks_changed` | `utopia hooks analyze` (changed files) |

Generators (`create`, `add screen`, `init *`) are deliberately NOT exposed via MCP -
invoke them via Bash.

## Setup Commands (One-Shot)

| Command | What it does |
|---------|--------------|
| `utopia create flutter_app <name>` | Scaffold a full Utopia Flutter app (sample counter feature, `.claude/` pre-registered) |
| `utopia create flutter_package <name>` | Scaffold a Utopia Flutter package |
| `utopia init skills` | Write `.claude/settings.json` registering the `utopia-flutter-skills` marketplace |
| `utopia init agents` | Write provider-neutral `AGENTS.md` for Codex/shell/CI agents |
| `utopia bump` | Bump all `utopia_*` deps in pubspec.yaml to latest pub.dev versions |
