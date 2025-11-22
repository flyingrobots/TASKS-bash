#!/usr/bin/env bash

port_call_planner() {
  local prompt_file="$1" prompt_text="$2"

  if ! declare -p TASKS_LLM_PLANNER_CMD 2>/dev/null | grep -q 'declare -a'; then
    echo "Error: TASKS_LLM_PLANNER_CMD must be an array (set in setup.sh)" >&2
    return 127
  fi
  if [ ${#TASKS_LLM_PLANNER_CMD[@]} -eq 0 ]; then
    echo "Error: TASKS_LLM_PLANNER_CMD is empty" >&2
    return 127
  fi

  "${TASKS_LLM_PLANNER_CMD[@]}" "$prompt_file" "$prompt_text"
}
