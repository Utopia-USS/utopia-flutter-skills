#!/usr/bin/env bash
# quality_check.sh - compatibility wrapper for utopia_hooks convention checks.
#
# The canonical rule engine lives in `utopia_cli` and is exposed both as:
#   - CLI: `utopia hooks analyze`
#   - MCP: `utopia mcp` tools `analyze_hooks_files` / `analyze_hooks_changed`
#
# The plugin's PostToolUse hook calls this wrapper so a missing CLI produces
# one clear install hint instead of a raw "command not found" on every edit.

set -u

if ! command -v utopia >/dev/null 2>&1; then
  echo "utopia-hooks quality_check: utopia CLI not found on PATH; install utopia_cli to enable checks." >&2
  exit 1
fi

exec utopia hooks analyze --hook-json
