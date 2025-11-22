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

cleanup_worker_state() {
  local reason="$1" task_file="$2" log_file="$3"
  # Best-effort cleanup; partial failures are logged
  mkdir -p "$TASKS_DIR/dead" 2>/dev/null || port_log_error "Failed to ensure dead dir for $task_id"
  if [ -f "$task_file" ]; then
    mv "$task_file" "$TASKS_DIR/dead/$task_id.json" 2>/dev/null || port_log_error "Failed to move $task_id to dead ($reason)"
  fi
  rm -rf "$TASKS_DIR/claimed/$worker_id" 2>/dev/null || port_log_error "Failed to remove claimed dir for $worker_id"
  rm -f "$TASKS_DIR/pids/$worker_id.pid" 2>/dev/null || true
  if [ -n "$log_file" ]; then
    printf '%s\n' "$reason" >>"$log_file" 2>/dev/null || true
  fi
}

TASK_FILE="$TASKS_DIR/claimed/$worker_id/$task_id.json"
LOG_FILE="$TASKS_DIR/logs/$task_id.log"

if [ ! -f "$TASK_FILE" ]; then
  port_log_error "Task file not found for $task_id"
  exit 1
fi

# Validate JSON structure before proceeding
if ! jq empty "$TASK_FILE" 2>"$LOG_FILE"; then
  port_log_error "Task file contains invalid JSON: $task_id" 
  cleanup_worker_state "invalid JSON" "$TASK_FILE" "$LOG_FILE"
  exit 1
fi

# Sanitize description to avoid prompt/shell injection
description_raw=$(jq -r '.description // ""' "$TASK_FILE")
description_clean=$(printf '%s' "$description_raw" | tr -cd '[:print:]' | head -c 2000)

# Load worker prompt template (supports customization via TASKS_WORKER_PROMPT_TEMPLATE)
template_path=${TASKS_WORKER_PROMPT_TEMPLATE:-$TASKS_DIR/prompts/worker.txt}
if [ -f "$template_path" ]; then
  template_content=$(cat "$template_path")
else
  template_content="You are one of multiple parallel workers on the same git branch.\nYou MUST NOT run git commands.\nOther workers may modify files concurrently; transient test/build/edit failures may be caused by their edits—retry locally without git.\n\nTask ID: {{TASK_ID}}\nDescription: {{TASK_DESCRIPTION}}"
fi

# Replace placeholders in template body
prompt_body=${template_content//{{TASK_ID}}/$task_id}
prompt_body=${prompt_body//{{TASK_DESCRIPTION}}/$description_clean}

# Ensure first line carries the task description for downstream tools
prompt=$(printf 'Task %s: %s\n%s\n' "$task_id" "$description_clean" "$prompt_body")

# Verify log directory is writable before execution
if [ ! -w "$TASKS_DIR/logs" ]; then
  port_log_error "Log directory is not writable: $TASKS_DIR/logs"
  exit 1
fi

TIMEOUT_SECONDS=${TASKS_TIMEOUT_SECONDS:-300}
if command -v timeout >/dev/null 2>&1; then
  printf '%s\n' "$prompt" | timeout --preserve-status "${TIMEOUT_SECONDS}s" "${TASKS_LLM_WORKER_CMD[@]}" >"$LOG_FILE" 2>&1
  status=$?
  if [ $status -eq 124 ] || [ $status -eq 137 ]; then
    port_log_error "LLM worker timed out for $task_id"
  fi
else
  printf '%s\n' "$prompt" | "${TASKS_LLM_WORKER_CMD[@]}" >"$LOG_FILE" 2>&1
  status=$?
fi

# Ensure destination directories exist before moving
mkdir -p "$TASKS_DIR/closed" "$TASKS_DIR/dead"

cleanup_fail=0

if [ $status -eq 0 ]; then
  if mv "$TASK_FILE" "$TASKS_DIR/closed/$task_id.json"; then
    port_log_info "✅ $task_id closed"
  else
    port_log_error "Failed to move $task_id to closed: $?"
    cleanup_worker_state "move-to-closed failed (status $status)" "$TASK_FILE" "$LOG_FILE"
    cleanup_fail=1
  fi
else
  cleanup_worker_state "execution failed (status $status)" "$TASK_FILE" "$LOG_FILE"
fi

# Unified cleanup that does not override task exit status unless cleanup fails
if [ $status -eq 0 ] && [ -n "$worker_id" ] && [ -d "$TASKS_DIR/claimed/$worker_id" ]; then
  rm -rf "$TASKS_DIR/claimed/$worker_id" 2>/dev/null || { port_log_error "Failed to clean up worker directory: $worker_id"; cleanup_fail=1; }
fi
rm -f "$TASKS_DIR/pids/$worker_id.pid" 2>/dev/null || true

if [ $cleanup_fail -ne 0 ] && [ $status -eq 0 ]; then
  port_log_error "Cleanup failed after successful task for $task_id (worker $worker_id)"
  status=1
fi

exit $status
