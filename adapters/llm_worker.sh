#!/usr/bin/env bash

# Renamed from port_call_worker for clarity
call_llm_worker() {
  local prompt="$1"

  # LLM_WORKER_CMD must be an array (set in setup.sh and sourced, not executed)
  if ! declare -p LLM_WORKER_CMD 2>/dev/null | grep -q 'declare \-a'; then
    echo "Error: LLM_WORKER_CMD is not an array (ensure setup.sh is sourced)" >&2
    return 127
  fi
  if [ ${#LLM_WORKER_CMD[@]} -eq 0 ]; then
    echo "Error: LLM_WORKER_CMD is not set" >&2
    return 127
  fi

  # Send prompt with trailing newline; avoid shell interpretation
  printf '%s\n' "$prompt" | "${LLM_WORKER_CMD[@]}"
}
