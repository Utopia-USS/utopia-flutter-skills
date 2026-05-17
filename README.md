# utopia-flutter-skills

**Production-grade Flutter skills for Claude Code** — by [UtopiaSoftware](https://utopiasoft.io).

Hooks-based state management, project scaffolding, and architecture conventions for Flutter teams that want AI to write code the way they would.

```bash
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-hooks@utopia-flutter-skills
```

> Drop-in for Claude Code. Works alongside (or replaces) BLoC, Riverpod, and Provider patterns.

---

## Why

Most Flutter AI tooling is either Bloc-locked, paid, or unopinionated boilerplate. `utopia-flutter-skills` is:

- **Hooks-first** — Screen/State/View pattern, composable hooks, no `StatefulWidget` ceremony.
- **MIT, hackable** — fork it, edit a skill, push back. No license lock-in.
- **Battle-tested** — distilled from production Flutter apps shipped by UtopiaSoftware.
- **Convention-enforcing** — PostToolUse hooks catch drift the moment Claude writes off-pattern code.

This is the AI tooling we use ourselves. We open-sourced it so the rest of the Flutter community can use it too.

## What's inside

| Plugin | What it does |
|---|---|
| [`utopia-hooks`](plugins/utopia-hooks/) | Holistic Flutter-with-hooks guide. Screen/State/View, hook catalog, global state, async patterns, paginated lists, DI, testing. |
| [`utopia-ai-arch`](plugins/utopia-ai-arch/) | Scaffold and maintain the Claude Code `.claude/` layer (agents, skills, slash commands, hooks, refs, architecture log) for Flutter projects. |
| [`utopia-hooks-migrate-bloc`](plugins/utopia-hooks-migrate-bloc/) | Orchestrated BLoC/Cubit → `utopia_hooks` migration. Two-phase (global states first, then screens), per-commit granularity, sub-agent review. |

Canonical hook reference list lives in [`plugins/utopia-hooks/skills/utopia-hooks/SKILL.md`](plugins/utopia-hooks/skills/utopia-hooks/SKILL.md).

## How it compares

| | utopia-flutter-skills | flutter_bloc | Riverpod | VGV Wingspan |
|---|---|---|---|---|
| State pattern | Hooks (Screen/State/View) | Bloc/Cubit | Providers + codegen | Bloc/Cubit |
| Claude Code skills | ✅ 3 plugins | — | — | ✅ |
| CLI scaffolder | [`utopia_cli`](https://github.com/Utopia-USS/utopia_cli) | — | — | `very_good_cli` |
| BLoC migration tool | ✅ | — | — | — |
| License | MIT | MIT | MIT | MIT (alpha) |
| Lock-in | None | Bloc-only | Riverpod-only | VGV opinions |

## Installation

### Claude Code

```bash
# Register the marketplace
/plugin marketplace add Utopia-USS/utopia-flutter-skills

# Install plugins individually
/plugin install utopia-hooks@utopia-flutter-skills
/plugin install utopia-ai-arch@utopia-flutter-skills
/plugin install utopia-hooks-migrate-bloc@utopia-flutter-skills
```

### One-command project setup with `utopia-cli`

```bash
dart pub global activate utopia_cli
utopia create flutter_app my_app --org io.example
cd my_app
claude  # .claude/ already wired to this marketplace
```

You get a Flutter app with `utopia_hooks` + `utopia_arch` scaffolding **and** Claude Code that already knows your project's conventions.

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

## Contributing

Issues and PRs welcome. Skills are designed to be forked — copy a skill into your own `.claude/`, tweak the rules, and ship it.

## License

MIT — see [LICENSE](LICENSE).

---

Built with care by [UtopiaSoftware](https://utopiasoft.io) · Flutter consultancy & product studio.
