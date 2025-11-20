#!/bin/bash
worker_id="$1"
task_id="$2"

source setup.sh
source adapters/log.sh
source adapters/llm_worker.sh

TASK_FILE="$TASKS_DIR/claimed/$worker_id/$task_id.json"
LOG_FILE="$TASKS_DIR/logs/$task_id.log"

if [ ! -f "$TASK_FILE" ]; then
  port_log_error "Task file not found for $task_id"
  exit 1
fi

description=$(jq -r '.description // ""' "$TASK_FILE")
prompt="Execute task $task_id: $description"

port_call_worker "$prompt" >"$LOG_FILE" 2>&1
status=$?

if [ $status -eq 0 ]; then
  mv "$TASK_FILE" "$TASKS_DIR/closed/$task_id.json"
  port_log_info "✅ $task_id closed"
else
  mv "$TASK_FILE" "$TASKS_DIR/dead/$task_id.json"
  port_log_error "💀 $task_id failed"
fi

# Clean up claimed worker directory to avoid stale slots
rm -rf "$TASKS_DIR/claimed/$worker_id"
rm -f "$TASKS_DIR/pids/$worker_id.pid"

exit $status
