#!/usr/bin/env bash
# Run one Claude prompt inside a Docker Sandbox, in this project's folder,
# so the project's pinned plugins are loaded.
#
#   scripts/sbx-claude.sh [--json] <sandbox-name> "<prompt>"
#
# Run from the project folder on the laptop. The folder is mounted at the same
# path inside the sandbox.
set -euo pipefail

format=text
if [[ "${1:-}" == "--json" ]]; then
  format=json
  shift
fi

if [[ $# -ne 2 ]]; then
  echo "usage: $0 [--json] <sandbox-name> \"<prompt>\"" >&2
  exit 2
fi

sandbox=$1
prompt=$2

exec sbx exec -e PROJ="$PWD" -e PROMPT="$prompt" -e FORMAT="$format" "$sandbox" \
  bash -lc 'cd "$PROJ" && claude -p --dangerously-skip-permissions --output-format "$FORMAT" "$PROMPT"'
