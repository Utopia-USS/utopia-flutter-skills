#!/usr/bin/env bash
# dart_lsp.sh - launch the Dart analysis server in LSP mode for Claude Code.
#
# Picks the right Dart SDK per project, in priority order:
#   1. Project-pinned fvm SDK at <project>/.fvm/flutter_sdk/bin/dart   (fvm `use`d project)
#   2. `fvm dart`, when fvm is installed and the project is pinned but the
#      SDK symlink is not materialized yet (needs `fvm install`)
#   3. `dart` on PATH                                                  (no fvm)
#
# Claude Code spawns this with cwd = the project root and exports
# CLAUDE_PROJECT_DIR; we resolve against that so detection is location-proof.
# bash 3.2 compatible (macOS system bash).

set -u

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# 1. Project-pinned fvm SDK. fvm symlinks the chosen Flutter SDK at
#    <project>/.fvm/flutter_sdk; its bundled dart lives under bin/.
fvm_dart="$ROOT/.fvm/flutter_sdk/bin/dart"
if [ -x "$fvm_dart" ]; then
  exec "$fvm_dart" language-server --protocol=lsp "$@"
fi

# 2. Project declares an fvm pin (.fvmrc new-style or .fvm/fvm_config.json
#    legacy) but the SDK isn't linked yet - let fvm resolve and proxy.
if command -v fvm >/dev/null 2>&1 \
  && { [ -f "$ROOT/.fvmrc" ] || [ -f "$ROOT/.fvm/fvm_config.json" ]; }; then
  cd "$ROOT" || exit 1
  exec fvm dart language-server --protocol=lsp "$@"
fi

# 3. No fvm: system dart on PATH.
if command -v dart >/dev/null 2>&1; then
  exec dart language-server --protocol=lsp "$@"
fi

echo "utopia-dart-lsp: no Dart SDK found - looked for \"$fvm_dart\", \`fvm\`, and \`dart\` on PATH." >&2
exit 1
