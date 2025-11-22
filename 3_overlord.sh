#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -r "$SCRIPT_DIR/setup.sh" ] || { echo "missing or unreadable: $SCRIPT_DIR/setup.sh" >&2; exit 1; }
[ -r "$SCRIPT_DIR/lib/tasks/overlord.sh" ] || { echo "missing or unreadable: $SCRIPT_DIR/lib/tasks/overlord.sh" >&2; exit 1; }

source "$SCRIPT_DIR/setup.sh"
source "$SCRIPT_DIR/lib/tasks/overlord.sh"

tasks_overlord "$SCRIPT_DIR" "$@"
