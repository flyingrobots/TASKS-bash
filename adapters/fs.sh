#!/usr/bin/env bash

# Enable strict mode for better error detection
set -euo pipefail

# ============================================================================
# adapters/fs.sh - Filesystem adapter for T.A.S.K.S.
# ============================================================================
#
# REQUIRED ENVIRONMENT VARIABLES:
#   TASKS_DIR - Root directory for task state (e.g., .tasks/)
#
# REQUIRED DIRECTORY STRUCTURE:
#   $TASKS_DIR/blocked/  - Tasks waiting on dependencies
#   $TASKS_DIR/open/     - Tasks ready to be claimed
#   $TASKS_DIR/claimed/  - Tasks currently being executed
#   $TASKS_DIR/closed/   - Successfully completed tasks
#   $TASKS_DIR/dead/     - Failed tasks
#   $TASKS_DIR/pids/     - Active worker PID files
#   $TASKS_DIR/logs/     - Task execution logs
#
# REQUIRED DEPENDENCIES:
#   jq                   - JSON parser (command-line tool)
#   get_worker_id        - Function to generate unique worker IDs
#
# ERROR HANDLING CONTRACT:
#   All port_* functions return 0 on success, non-zero on error.
#   Errors are written to stderr.
# ============================================================================

# Validate required environment and dependencies
_validate_tasks_dir() {
  if [ -z "$TASKS_DIR" ]; then
    echo "Error: TASKS_DIR environment variable is not set" >&2
    return 1
  fi

  if [ ! -d "$TASKS_DIR" ]; then
    echo "Error: TASKS_DIR does not exist: $TASKS_DIR" >&2
    return 1
  fi

  return 0
}

# Check for required tools and functions at startup
if ! command -v jq &>/dev/null; then
  echo "Error: jq command not found. Please install jq." >&2
  exit 1
fi

if ! declare -f get_worker_id &>/dev/null; then
  echo "Error: get_worker_id function not found. Ensure setup.sh is sourced." >&2
  exit 1
fi

# Validate TASKS_DIR at startup
if ! _validate_tasks_dir; then
  exit 1
fi

port_list_blocked_tasks() {
  # Ensure blocked directory exists and is readable
  if [ ! -d "$TASKS_DIR/blocked" ] || [ ! -r "$TASKS_DIR/blocked" ]; then
    echo "Error: blocked directory does not exist or is not readable" >&2
    return 1
  fi

  # Use nullglob to handle no-match case safely
  local old_nullglob=$(shopt -p nullglob || true)
  shopt -s nullglob
  local files=("$TASKS_DIR/blocked"/*.json)
  eval "$old_nullglob"

  # Print each file path
  for file in "${files[@]}"; do
    echo "$file"
  done

  return 0
}

port_read_dependencies() {
  local file="$1"

  # Validate input parameter
  if [ -z "$file" ]; then
    echo "Error: port_read_dependencies requires a file parameter" >&2
    return 1
  fi

  # Verify file exists and is readable
  if [ ! -f "$file" ]; then
    echo "Error: File does not exist: $file" >&2
    return 1
  fi

  if [ ! -r "$file" ]; then
    echo "Error: File is not readable: $file" >&2
    return 1
  fi

  # Ensure jq is available (already checked at startup, but extra safety)
  if ! command -v jq &>/dev/null; then
    echo "Error: jq command not found" >&2
    return 1
  fi

  # Execute jq and handle errors
  if ! jq -r '.dependencies[]?' "$file"; then
    echo "Error: Failed to parse dependencies from $file" >&2
    return 1
  fi

  return 0
}

port_is_closed() {
  local task_id="$1"

  # Validate parameter is provided
  if [ -z "$task_id" ]; then
    echo "Error: port_is_closed requires a task_id parameter" >&2
    return 1
  fi

  # Test file existence with quoted path
  [ -f "$TASKS_DIR/closed/$task_id.json" ]
}

port_unblock_task() {
  local task_path="$1"

  # Validate argument is provided
  if [ -z "$task_path" ]; then
    echo "Error: port_unblock_task requires task_path parameter" >&2
    return 1
  fi

  # Verify source exists and is a regular file
  if [ ! -f "$task_path" ]; then
    echo "Error: Task file does not exist: $task_path" >&2
    return 1
  fi

  # Ensure destination directory exists
  if ! mkdir -p "$TASKS_DIR/open"; then
    echo "Error: Failed to create open directory" >&2
    return 1
  fi

  # Perform move and check exit status
  if ! mv "$task_path" "$TASKS_DIR/open/"; then
    echo "Error: Failed to unblock task: $task_path" >&2
    return 1
  fi

  return 0
}

port_count_claimed_workers() {
  # Ensure pids directory exists with error checking
  if ! mkdir -p "$TASKS_DIR/pids"; then
    echo "Error: Failed to create pids directory" >&2
    return 1
  fi

  local alive=0
  local old_nullglob=$(shopt -p nullglob || true)
  shopt -s nullglob
  local pidfiles=("$TASKS_DIR/pids"/*.pid)
  eval "$old_nullglob"

  # Process each pidfile with robust error handling
  local pidfile pid
  for pidfile in "${pidfiles[@]}"; do
    # Read PID with error handling
    if ! pid=$(cat "$pidfile" 2>/dev/null); then
      # Failed to read, remove stale pidfile
      rm -f "$pidfile" 2>/dev/null || true
      continue
    fi

    # Skip empty PIDs
    if [ -z "$pid" ]; then
      rm -f "$pidfile" 2>/dev/null || true
      continue
    fi

    # Test if process is alive
    if kill -0 "$pid" 2>/dev/null; then
      alive=$((alive + 1))
    else
      # Process is dead, remove stale pidfile
      rm -f "$pidfile" 2>/dev/null || true
    fi
  done

  echo "$alive"
  return 0
}

port_count_open_tasks() {
  # Use nullglob to handle no-match case safely
  local old_nullglob=$(shopt -p nullglob || true)
  shopt -s nullglob
  local files=("$TASKS_DIR/open"/*.json)
  eval "$old_nullglob"

  # Return count
  echo "${#files[@]}"
  return 0
}

port_pick_open_task() {
  # Use nullglob to safely handle no matches
  local old_nullglob=$(shopt -p nullglob || true)
  shopt -s nullglob
  local files=("$TASKS_DIR/open"/*.json)
  eval "$old_nullglob"

  # Return first file if available, otherwise return non-zero
  if [ "${#files[@]}" -gt 0 ]; then
    echo "${files[0]}"
    return 0
  else
    return 1
  fi
}

port_new_worker_id() {
  # Verify get_worker_id function exists
  if ! declare -f get_worker_id &>/dev/null; then
    echo "Error: get_worker_id function not found" >&2
    return 1
  fi

  # Call get_worker_id and capture output and exit status
  local worker_id
  if ! worker_id=$(get_worker_id); then
    echo "Error: get_worker_id failed" >&2
    return 1
  fi

  # Validate output is non-empty
  if [ -z "$worker_id" ]; then
    echo "Error: get_worker_id returned empty worker_id" >&2
    return 1
  fi

  # Output the worker_id
  echo "$worker_id"
  return 0
}

port_claim_task() {
  local worker_id="$1" task_path="$2" task_id="$3"

  # Validate all required parameters
  if [ -z "$TASKS_DIR" ]; then
    echo "Error: TASKS_DIR is not set" >&2
    return 1
  fi

  if [ -z "$worker_id" ]; then
    echo "Error: worker_id is required" >&2
    return 1
  fi

  if [ -z "$task_path" ]; then
    echo "Error: task_path is required" >&2
    return 1
  fi

  if [ -z "$task_id" ]; then
    echo "Error: task_id is required" >&2
    return 1
  fi

  # Verify task_path exists and is a regular file
  if [ ! -f "$task_path" ]; then
    echo "Error: Task file does not exist: $task_path" >&2
    return 1
  fi

  # Create claimed directory and check for errors
  if ! mkdir -p "$TASKS_DIR/claimed/$worker_id"; then
    echo "Error: Failed to create claimed directory for worker $worker_id" >&2
    return 1
  fi

  # Perform atomic move: first to temp, then rename
  local dest="$TASKS_DIR/claimed/$worker_id/$task_id.json"
  local temp_dest="${dest}.tmp"

  if ! mv "$task_path" "$temp_dest"; then
    echo "Error: Failed to move task to temporary location: $task_path -> $temp_dest" >&2
    return 1
  fi

  if ! mv "$temp_dest" "$dest"; then
    echo "Error: Failed to rename task to final location: $temp_dest -> $dest" >&2
    # Try to recover by moving back
    mv "$temp_dest" "$task_path" 2>/dev/null || true
    return 1
  fi

  return 0
}
