#!/usr/bin/env bash
set -euo pipefail

# tasks.sh: one-shot orchestrator
# Usage: ./tasks.sh "Refactor the Foobar module"

GOAL=${1:-}
if [ -z "$GOAL" ]; then
  echo "Usage: $0 'Your goal here'" >&2
  exit 1
fi

# Allow callers to override ticks/sleep; set sensible defaults for an end-to-end run.
: "${TASKS_OVERLORD_TICKS:=500}"
: "${TASKS_SLEEP_SECONDS:=0.5}"
export TASKS_OVERLORD_TICKS TASKS_SLEEP_SECONDS

# 1) Bootstrap
./setup.sh

# 2) Plan
./1_architect.sh "$GOAL"

# 3) Seed
./2_seeder.sh

# 4) Execute (rolling frontier until tick limit)
./3_overlord.sh

echo "Run complete. Inspect .tasks/closed for finished tasks and .tasks/logs for details." >&2
