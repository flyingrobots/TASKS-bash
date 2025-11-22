#!/usr/bin/env bash

# Decide whether the overlord loop should continue. Accepts current tick as $1.
port_should_continue() {
  local tick="$1"

  # Validate tick parameter is provided and is a non-negative integer
  if [ -z "$tick" ]; then
    echo "Error: port_should_continue requires a tick parameter" >&2
    return 2
  fi

  if ! [[ "$tick" =~ ^[0-9]+$ ]]; then
    echo "Error: tick must be a non-negative integer, got: $tick" >&2
    return 2
  fi

  # If TASKS_OVERLORD_TICKS is set, validate it's numeric
  local ticks_var=${TASKS_OVERLORD_TICKS-}
  if [ -n "$ticks_var" ]; then
    if ! [[ "$ticks_var" =~ ^[0-9]+$ ]]; then
      echo "Error: TASKS_OVERLORD_TICKS must be a non-negative integer, got: $ticks_var" >&2
      return 2
    fi
    # Explicit return based on comparison
    if [ "$tick" -lt "$ticks_var" ]; then
      return 0
    else
      return 1
    fi
  else
    return 0
  fi
}
