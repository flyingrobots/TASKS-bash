#!/usr/bin/env bash
worker_id="$1"
task_id="$2"

# Validate inputs immediately to prevent path traversal and destructive operations
if [ -z "$worker_id" ] || [ -z "$task_id" ]; then
  echo "Error: worker_id and task_id are required" >&2
  exit 1
fi

# Sanitize inputs: reject path traversal, shell metacharacters, and unsafe patterns
# Allow only [A-Za-z0-9._-]
if [[ "$worker_id" =~ [^A-Za-z0-9._-] ]] || [[ "$worker_id" == "." ]] || [[ "$worker_id" == ".." ]]; then
  echo "Error: worker_id contains invalid characters or is unsafe: $worker_id" >&2
  exit 1
fi

if [[ "$task_id" =~ [^A-Za-z0-9._-] ]] || [[ "$task_id" == "." ]] || [[ "$task_id" == ".." ]]; then
  echo "Error: task_id contains invalid characters or is unsafe: $task_id" >&2
  exit 1
fi

source setup.sh
source adapters/log.sh
source adapters/llm_worker.sh

TASK_FILE="$TASKS_DIR/claimed/$worker_id/$task_id.json"
LOG_FILE="$TASKS_DIR/logs/$task_id.log"

if [ ! -f "$TASK_FILE" ]; then
  port_log_error "Task file not found for $task_id"
  exit 1
fi

# Validate JSON structure before proceeding
if ! jq empty "$TASK_FILE" 2>/dev/null; then
  port_log_error "Task file contains invalid JSON: $task_id"
  exit 1
fi

description=$(jq -r '.description // ""' "$TASK_FILE")
prompt="Execute task $task_id: $description"

# Verify log directory is writable before execution
if [ ! -w "$TASKS_DIR/logs" ]; then
  port_log_error "Log directory is not writable: $TASKS_DIR/logs"
  exit 1
fi

call_llm_worker "$prompt" >"$LOG_FILE" 2>&1
status=$?

# Ensure destination directories exist before moving
mkdir -p "$TASKS_DIR/closed" "$TASKS_DIR/dead"

if [ $status -eq 0 ]; then
  if mv "$TASK_FILE" "$TASKS_DIR/closed/$task_id.json"; then
    port_log_info "✅ $task_id closed"
  else
    port_log_error "Failed to move $task_id to closed: $?"
    exit 1
  fi
else
  if mv "$TASK_FILE" "$TASKS_DIR/dead/$task_id.json"; then
    port_log_error "💀 $task_id failed"
  else
    port_log_error "Failed to move $task_id to dead: $?"
    exit 1
  fi
fi

# Clean up claimed worker directory to avoid stale slots
# Double-check worker_id is valid and directory exists before destructive operation
if [ -z "$worker_id" ] || [ ! -d "$TASKS_DIR/claimed/$worker_id" ]; then
  port_log_error "Invalid cleanup state for worker_id=$worker_id"
  exit 1
fi

if ! rm -rf "$TASKS_DIR/claimed/$worker_id"; then
  port_log_error "Failed to clean up worker directory: $worker_id"
  exit 1
fi

rm -f "$TASKS_DIR/pids/$worker_id.pid" 2>/dev/null || true

exit $status
