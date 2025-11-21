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
  umask 077
  mkdir -p "$TASKS_DIR"/{manifest,blocked,open,claimed,closed,dead,logs,prompts,pids} || {
    echo "Error: failed to create task directories under $TASKS_DIR" >&2
    umask "$old_umask"
    exit 1
  }
  umask "$old_umask"

  # Lock down directory and file permissions; fail fast on errors
  if ! find "$TASKS_DIR" -type d -exec chmod 700 {} +; then
    echo "Error: failed to set directory permissions in $TASKS_DIR" >&2
    exit 1
  fi
  if ! find "$TASKS_DIR" -type f -exec chmod 600 {} +; then
    echo "Error: failed to set file permissions in $TASKS_DIR" >&2
    exit 1
  fi
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
# Input format: LLM_WORKER_CMD <full_prompt_string>
# Note: We use --dangerously-skip-permissions for full autonomy.
export LLM_WORKER_CMD="${LLM_WORKER_CMD:-claude --dangerously-skip-permissions}"

# Helper function to generate a high-entropy worker ID
get_worker_id() {
    # High-entropy worker id: urandom hex (16 bytes) with timestamp/pid suffix for traceability
    local rand
    if rand=$(head -c 16 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n'); then
        :
    elif command -v uuidgen >/dev/null 2>&1; then
        rand=$(uuidgen | tr -d '-\n')
    else
        local ts=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
        rand="fallback${ts}$$$RANDOM"
    fi
    local ts_short=$(date +%s)
    echo "w_${rand}_${ts_short}_$$"
}
