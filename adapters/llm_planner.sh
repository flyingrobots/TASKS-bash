#!/usr/bin/env bash

port_call_planner() {
  local prompt_file="$1" prompt_text="$2"

  # Use eval to safely handle multi-word commands with flags
  # TASKS_LLM_PLANNER_CMD should be set in setup.sh (e.g., "claude -p")
  eval "$TASKS_LLM_PLANNER_CMD" '"$prompt_file"' '"$prompt_text"'
}
