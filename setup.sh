#!/bin/bash

# ==========================================
# T.A.S.K.S. CONFIGURATION
# ==========================================

# Directories
export TASKS_DIR="$(pwd)/.tasks"
mkdir -p .tasks/{manifest,blocked,open,claimed,closed,dead,logs,prompts,pids}

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

# Helper function to generate a timestamped worker ID
get_worker_id() {
    echo "w_$(date +%s)_$RANDOM"
}
