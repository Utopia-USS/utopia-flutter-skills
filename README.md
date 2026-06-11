# 👾 utopia-flutter-skills

**Production-grade Flutter skills for Claude Code and Codex** — by [UtopiaSoftware](https://utopiasoft.io).

Hooks-based state management, project scaffolding, and architecture conventions for Flutter teams that want AI to write code the way they would.

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-hooks@utopia-flutter-skills

# Codex, from the repo root
codex plugin marketplace add .
codex plugin install utopia-hooks@utopia-flutter-skills
```

> Drop-in for Claude Code and Codex. Works alongside (or replaces) BLoC, Riverpod, and Provider patterns.

---

## Why

Most Flutter AI tooling is either Bloc-locked, paid, or unopinionated boilerplate. `utopia-flutter-skills` is:

- **Hooks-first** — Screen/State/View pattern, composable hooks, no `StatefulWidget` ceremony.
- **BSD-2-Clause, hackable** — fork it, edit a skill, push back. No license lock-in.
- **Battle-tested** — distilled from production Flutter apps shipped by UtopiaSoftware.
- **Convention-enforcing** — `utopia_cli` analysis catches drift through Claude hooks, Codex/MCP tools, or manual CLI checks.

This is the AI tooling we use ourselves. We open-sourced it so the rest of the Flutter community can use it too.

## What's inside

| Plugin | What it does |
|---|---|
| [`utopia-hooks`](plugins/utopia-hooks/) | Holistic Flutter-with-hooks guide. Screen/State/View, hook catalog, global state, async patterns, paginated lists, DI, testing. |
| [`utopia-ai-arch`](plugins/utopia-ai-arch/) | Scaffold and maintain the Claude Code `.claude/` layer (agents, skills, slash commands, hooks, refs, architecture log) for Flutter projects. |
| [`utopia-hooks-migrate-bloc`](plugins/utopia-hooks-migrate-bloc/) | Orchestrated BLoC/Cubit → `utopia_hooks` migration. Two-phase (global states first, then screens), per-commit granularity, sub-agent review. |
| [`utopia-cms`](plugins/utopia-cms/) | Flutter CMS / admin panels with `utopia_cms`. `CmsWidget` shell, `CmsTablePage`, delegates for Firebase/Supabase/Hasura/GraphQL, entry catalog, filters, custom actions, management sections, and review guidance for avoiding hand-rolled DataTable + service anti-patterns. |

Canonical hook reference list lives in [`plugins/utopia-hooks/skills/utopia-hooks/SKILL.md`](plugins/utopia-hooks/skills/utopia-hooks/SKILL.md).

## How it compares

| | utopia-flutter-skills | Typical state-management packages | Generic AI coding setup |
|---|---|---|---|
| State pattern | Hooks (Screen/State/View) | Library-specific patterns | Unspecified |
| Agent skills | 4 plugins for Claude Code and Codex | - | Manual prompts |
| CLI scaffolder | [`utopia_cli`](https://github.com/Utopia-USS/utopia_cli) | - | Usually separate |
| BLoC migration tool | Included | - | Manual migration |
| License | BSD-2-Clause | Varies | Varies |
| Lock-in | None | Package-specific | Tooling-specific |

## Installation

### Claude Code

The `utopia-hooks` quality analysis is powered by `utopia_cli`, so make sure
`utopia` is available on `PATH`:

```bash
dart pub global activate utopia_cli
```

```bash
# Register the marketplace
/plugin marketplace add Utopia-USS/utopia-flutter-skills

# Install plugins individually
/plugin install utopia-hooks@utopia-flutter-skills
/plugin install utopia-ai-arch@utopia-flutter-skills
/plugin install utopia-hooks-migrate-bloc@utopia-flutter-skills
/plugin install utopia-cms@utopia-flutter-skills
```

### Codex

The `utopia-hooks` and `utopia-cms` plugins are also available through this
repo's local Codex marketplace. Keep `utopia` on `PATH` for quality analysis:

```bash
dart pub global activate utopia_cli
```

```bash
# Register the marketplace from the repo root
codex plugin marketplace add .

# Install the Codex plugins
codex plugin install utopia-hooks@utopia-flutter-skills
codex plugin install utopia-cms@utopia-flutter-skills
```

### One-command project setup with `utopia-cli`

```bash
dart pub global activate utopia_cli
utopia create flutter_app my_app --org io.example
cd my_app
# Open the project in Claude Code or register this repo marketplace in Codex.
claude
# or:
codex plugin marketplace add .
```

You get a Flutter app with `utopia_hooks` + `utopia_arch` scaffolding **and** an AI-agent layer that already knows your project's conventions.

## Companion packages

Published on [pub.dev](https://pub.dev/publishers/utopiasoft.io):

- [`utopia_hooks`](https://pub.dev/packages/utopia_hooks) — hooks framework
- [`utopia_arch`](https://pub.dev/packages/utopia_arch) — architecture layer (DI, preferences, error handling)
- [`utopia_hooks_riverpod`](https://pub.dev/packages/utopia_hooks_riverpod) — Riverpod bridge
- [`utopia_lints`](https://pub.dev/packages/utopia_lints) — shared lint pack

Compatible with [`fast_immutable_collections`](https://pub.dev/packages/fast_immutable_collections) (`IList`, `IMap`, `ISet`).

## Documentation

- [Screen/State/View pattern](plugins/utopia-hooks/skills/utopia-hooks/SKILL.md)
- [Hook catalog](plugins/utopia-hooks/skills/utopia-hooks/references/)
- [BLoC migration playbook](plugins/utopia-hooks-migrate-bloc/skills/migrate-bloc-to-utopia-hooks/SKILL.md)
- [CMS / admin-panel guide](plugins/utopia-cms/skills/utopia-cms/SKILL.md)

## Contributing

Issues and PRs welcome. Skills are designed to be forked — copy a skill into your own Claude Code or Codex setup, tweak the rules, and ship it.

## License

BSD 2-Clause — see [LICENSE](LICENSE).

---

Built with care by [UtopiaSoftware](https://utopiasoft.io) · Flutter consultancy & product studio.
