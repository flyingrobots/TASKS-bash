#!/usr/bin/env bash

# Renamed from port_call_worker for clarity
call_llm_worker() {
  local prompt="$1"

  # Use eval to safely handle multi-word commands with flags
  # LLM_WORKER_CMD should be set in setup.sh (e.g., "claude --dangerously-skip-permissions")
  echo "$prompt" | eval "$LLM_WORKER_CMD"
}
