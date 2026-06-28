# utopia-dart-lsp

👾 Dart/Flutter language server (LSP) for Claude Code.

Gives Claude live code intelligence on Dart projects:

- **Diagnostics** — analyzer errors/warnings are injected into context automatically after every `.dart` edit (no `dart analyze` run needed).
- **Navigation** — hover, go-to-definition, find-references, go-to-implementation.
- **Symbols** — document symbols and workspace symbol search.
- **Call hierarchy** — incoming/outgoing calls.

These are exposed to Claude through the built-in `LSP` tool and the auto-diagnostics channel.

## SDK selection (fvm-aware)

`scripts/dart_lsp.sh` picks the Dart SDK per project, in order:

1. **Project-pinned fvm SDK** — `<project>/.fvm/flutter_sdk/bin/dart` (a project where `fvm use <version>` has run).
2. **`fvm dart`** — when `fvm` is installed and the project is pinned (`.fvmrc` or legacy `.fvm/fvm_config.json`) but the SDK symlink isn't materialized yet.
3. **`dart` on PATH** — a plain, non-fvm project.

So the same plugin works whether or not a project uses fvm. No per-project configuration.

## Installation

```
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-dart-lsp@utopia-flutter-skills
```

Then reload (`/reload-plugins`) or restart. The server spawns lazily on the first `.dart` file Claude touches; `/reload-plugins` then reports `1 plugin LSP server`.

## Requirements

A Dart SDK reachable by one of the three strategies above. Nothing else to configure.

## Companion

Complements the official `dart mcp-server` (run tests, hot reload, pub) — LSP provides passive code intelligence, the MCP server provides invokable tools.

---

BSD-2-Clause · [UtopiaSoftware](https://utopiasoft.io)
