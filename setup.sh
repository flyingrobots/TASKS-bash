#!/usr/bin/env bash

# ==========================================
# T.A.S.K.S. CONFIGURATION
# ==========================================

# Directories (allow override for tests)
export TASKS_DIR="${TASKS_DIR:-$(pwd)/.tasks}"

# Create task directories with error handling and optional lockdown
fail() {
  echo "$1" >&2
  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    exit 1
  else
    return 1
  fi
}

if [ "${TASKS_SKIP_LOCKDOWN:-0}" = "1" ]; then
  mkdir -p "$TASKS_DIR"/{manifest,blocked,open,claimed,closed,dead,logs,prompts,pids} || fail "Error: failed to create task directories under $TASKS_DIR"
else
  old_umask=$(umask)
  cleanup_umask() { umask "$old_umask"; trap - EXIT INT TERM HUP ERR; }
  trap cleanup_umask EXIT INT TERM HUP ERR
  umask 077
  mkdir -p "$TASKS_DIR"/{manifest,blocked,open,claimed,closed,dead,logs,prompts,pids} || fail "Error: failed to create task directories under $TASKS_DIR"

  # Lock down permissions: 700 for dirs, 600 for files (defensive for future files)
  find "$TASKS_DIR" -type d -exec chmod 700 {} + || fail "Error: failed to set directory permissions in $TASKS_DIR"
  find "$TASKS_DIR" -type f -exec chmod 600 {} + || fail "Error: failed to set file permissions in $TASKS_DIR"

  cleanup_umask
fi

# Worker Configuration (prefixed envs; legacy aliases supported for compatibility)
export TASKS_MAX_WORKERS=${TASKS_MAX_WORKERS:-4}
export TASKS_TIMEOUT_SECONDS=${TASKS_TIMEOUT_SECONDS:-300}

# ==========================================
# LLM ABSTRACTION LAYER
# ==========================================
# To swap LLMs, change these commands. 
# The command must accept the Prompt as the last argument.

# 1. The Planner (Architect)
# Requirements: Must output valid JSON to stdout.
# Input format: TASKS_LLM_PLANNER_CMD <prompt_file> <user_input_string>
export TASKS_LLM_PLANNER_CMD="${TASKS_LLM_PLANNER_CMD:-claude -p}"

# 2. The Worker (Minion)
# Requirements: Must be capable of File I/O (editing files in place).
# Input format: Preferred TASKS_LLM_WORKER_CMD_JSON as a JSON array of strings; defaults to claude if unset.
# Note: We use --dangerously-skip-permissions for full autonomy.
TASKS_LLM_WORKER_CMD_DEFAULT=(claude --dangerously-skip-permissions)

# Resolve worker command (JSON only + default)
if [ -n "${TASKS_LLM_WORKER_CMD_JSON:-}" ]; then
  TASKS_LLM_WORKER_CMD_JSON_EFFECTIVE=${TASKS_LLM_WORKER_CMD_JSON}
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required to parse TASKS_LLM_WORKER_CMD_JSON" >&2
    exit 1
  fi
  jq_tmp_err=$(mktemp)
  jq_output=$(printf '%s' "$TASKS_LLM_WORKER_CMD_JSON_EFFECTIVE" | jq -r 'if type=="array" and length>0 then .[] else error("TASKS_LLM_WORKER_CMD_JSON must be a non-empty array") end' 2>"$jq_tmp_err") || {
    err_msg=$(cat "$jq_tmp_err" 2>/dev/null || true)
    rm -f "$jq_tmp_err"
    if [ -n "$err_msg" ]; then
      echo "$err_msg" >&2
    else
      echo "Error: TASKS_LLM_WORKER_CMD_JSON must be a JSON array of strings" >&2
    fi
    exit 1
  }
  rm -f "$jq_tmp_err"
  mapfile -t TASKS_LLM_WORKER_CMD <<<"$jq_output"
  if [ ${#TASKS_LLM_WORKER_CMD[@]} -eq 0 ]; then
    echo "Error: TASKS_LLM_WORKER_CMD_JSON must not be empty" >&2
    exit 1
  fi
else
  TASKS_LLM_WORKER_CMD=("${TASKS_LLM_WORKER_CMD_DEFAULT[@]}")
fi

if [ ${#TASKS_LLM_WORKER_CMD[@]} -eq 0 ]; then
  echo "Error: TASKS_LLM_WORKER_CMD is empty after initialization" >&2
  exit 1
fi

export TASKS_LLM_WORKER_CMD
# For logging/tests, keep a shell-escaped string form mirroring the resolved array
TASKS_LLM_WORKER_CMD_STR=$(printf '%q ' "${TASKS_LLM_WORKER_CMD[@]}")
TASKS_LLM_WORKER_CMD_STR=${TASKS_LLM_WORKER_CMD_STR%% }  # trim trailing space
export TASKS_LLM_WORKER_CMD_STR

# Helper function to generate a high-entropy worker ID
get_worker_id() {
  # High-entropy worker id: urandom hex (16 bytes) with timestamp/pid suffix for traceability
  local rand
  if rand=$(head -c 16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n') && [ -n "${rand}" ]; then
    : # success
  elif command -v uuidgen >/dev/null 2>&1; then
    rand=$(uuidgen | tr -d '-\n')
  else
    local ts=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    rand="fallback${ts}$$${RANDOM}"
  fi
  if [ -z "${rand// /}" ]; then
    local ts=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    rand="fallback${ts}$$${RANDOM}"
    echo "Warning: rand generation empty, using fallback" >&2
  fi
  local ts_short
  ts_short=$(date +%s)
  echo "w_${rand}_${ts_short}_$$"
}
