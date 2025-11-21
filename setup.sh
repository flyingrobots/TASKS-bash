#!/usr/bin/env bash

# ==========================================
# T.A.S.K.S. CONFIGURATION
# ==========================================

# Directories (allow override for tests)
export TASKS_DIR="${TASKS_DIR:-$(pwd)/.tasks}"

# Create task directories with error handling and optional lockdown
if [ "${TASKS_SKIP_LOCKDOWN:-0}" = "1" ]; then
  mkdir -p "$TASKS_DIR"/{manifest,blocked,open,claimed,closed,dead,logs,prompts,pids} || {
    echo "Error: failed to create task directories under $TASKS_DIR" >&2
    exit 1
  }
else
  old_umask=$(umask)
  cleanup_umask() { umask "$old_umask"; trap - EXIT INT TERM HUP ERR; }
  trap cleanup_umask EXIT INT TERM HUP ERR
  umask 077
  mkdir -p "$TASKS_DIR"/{manifest,blocked,open,claimed,closed,dead,logs,prompts,pids} || {
    echo "Error: failed to create task directories under $TASKS_DIR" >&2
    exit 1
  }

  # Lock down directory and file permissions; fail fast on errors
  if ! find "$TASKS_DIR" -type d -exec chmod 700 {} +; then
    echo "Error: failed to set directory permissions in $TASKS_DIR" >&2
    exit 1
  fi
  if ! find "$TASKS_DIR" -type f -exec chmod 600 {} +; then
    echo "Error: failed to set file permissions in $TASKS_DIR" >&2
    exit 1
  fi

  cleanup_umask
fi

# Worker Configuration
export MAX_WORKERS=${MAX_WORKERS:-4}

# ==========================================
# LLM ABSTRACTION LAYER
# ==========================================
# To swap LLMs, change these commands. 
# The command must accept the Prompt as the last argument.

# 1. The Planner (Architect)
# Requirements: Must output valid JSON to stdout.
# Input format: LLM_PLANNER_CMD <prompt_file> <user_input_string>
export LLM_PLANNER_CMD="${LLM_PLANNER_CMD:-claude -p}"

# 2. The Worker (Minion)
# Requirements: Must be capable of File I/O (editing files in place).
# Input format: Preferred LLM_WORKER_CMD_JSON as a JSON array of strings; defaults to claude if unset.
# Note: We use --dangerously-skip-permissions for full autonomy.
LLM_WORKER_CMD_DEFAULT=(claude --dangerously-skip-permissions)

# Resolve worker command (JSON only + default)
if [ -n "${LLM_WORKER_CMD_JSON:-}" ]; then
  if ! mapfile -t LLM_WORKER_CMD < <(printf '%s' "$LLM_WORKER_CMD_JSON" | jq -r 'if type=="array" then .[] else error("LLM_WORKER_CMD_JSON must be an array") end'); then
    echo "Error: LLM_WORKER_CMD_JSON must be a JSON array of strings" >&2
    exit 1
  fi
else
  LLM_WORKER_CMD=("${LLM_WORKER_CMD_DEFAULT[@]}")
fi

if [ ${#LLM_WORKER_CMD[@]} -eq 0 ]; then
  echo "Error: LLM_WORKER_CMD is empty after initialization" >&2
  exit 1
fi

export LLM_WORKER_CMD
# For logging/tests, keep a shell-escaped string form mirroring the resolved array
LLM_WORKER_CMD_STR=$(printf '%q ' "${LLM_WORKER_CMD[@]}")
LLM_WORKER_CMD_STR=${LLM_WORKER_CMD_STR%% }  # trim trailing space
export LLM_WORKER_CMD_STR

# Helper function to generate a high-entropy worker ID
get_worker_id() {
    # High-entropy worker id: urandom hex (16 bytes) with timestamp/pid suffix for traceability
    local rand
  if rand=$(head -c 16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n') && [ -n "${rand}" ]; then
    rand="$rand"
  elif command -v uuidgen >/dev/null 2>&1; then
    rand=$(uuidgen | tr -d '-\n')
  else
    local ts=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    rand="fallback${ts}$$$RANDOM"
  fi
  if [ -z "${rand// /}" ]; then
    local ts=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
    rand="fallback${ts}$$$RANDOM"
    echo "Warning: rand generation empty, using fallback" >&2
  fi
    local ts_short=$(date +%s)
    echo "w_${rand}_${ts_short}_$$"
}
