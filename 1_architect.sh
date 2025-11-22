#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -r "$SCRIPT_DIR/setup.sh" ] || { echo "missing or unreadable: $SCRIPT_DIR/setup.sh" >&2; exit 1; }
[ -r "$SCRIPT_DIR/adapters/log.sh" ] || { echo "missing or unreadable: $SCRIPT_DIR/adapters/log.sh" >&2; exit 1; }
[ -r "$SCRIPT_DIR/adapters/llm_planner.sh" ] || { echo "missing or unreadable: $SCRIPT_DIR/adapters/llm_planner.sh" >&2; exit 1; }
[ -r "$SCRIPT_DIR/lib/tasks/architect.sh" ] || { echo "missing or unreadable: $SCRIPT_DIR/lib/tasks/architect.sh" >&2; exit 1; }

source "$SCRIPT_DIR/setup.sh"
source "$SCRIPT_DIR/adapters/log.sh"
source "$SCRIPT_DIR/adapters/llm_planner.sh"
source "$SCRIPT_DIR/lib/tasks/architect.sh"

tasks_architect "$@"
