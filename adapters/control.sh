#!/usr/bin/env bash

# Decide whether the overlord loop should continue. Accepts current tick as $1.
# Returns:
#   0 - Continue (tick < TASKS_OVERLORD_TICKS, or TASKS_OVERLORD_TICKS unset)
#   1 - Stop (tick >= TASKS_OVERLORD_TICKS)
#   2 - Parameter error (invalid/missing tick, or invalid TASKS_OVERLORD_TICKS)
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

  # If TASKS_OVERLORD_TICKS is set, validate it's numeric (empty is an error)
  if [ -n "${TASKS_OVERLORD_TICKS+x}" ]; then
    if [ -z "${TASKS_OVERLORD_TICKS}" ]; then
      echo "Error: TASKS_OVERLORD_TICKS is set but empty" >&2
      return 2
    fi
    if ! [[ "$TASKS_OVERLORD_TICKS" =~ ^[0-9]+$ ]]; then
      echo "Error: TASKS_OVERLORD_TICKS must be a non-negative integer, got: $TASKS_OVERLORD_TICKS" >&2
      return 2
    fi
    if [ "$tick" -lt "$TASKS_OVERLORD_TICKS" ]; then
      return 0
    else
      return 1
    fi
  else
    return 0
  fi
}
