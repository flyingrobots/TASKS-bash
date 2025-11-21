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

  # If OVERLORD_TICKS is set, validate it's numeric
  # Use parameter expansion with default to handle set -u
  if [ -n "${OVERLORD_TICKS-}" ]; then
    if ! [[ "$OVERLORD_TICKS" =~ ^[0-9]+$ ]]; then
      echo "Error: OVERLORD_TICKS must be a non-negative integer, got: $OVERLORD_TICKS" >&2
      return 2
    fi
    # Explicit return based on comparison
    if [ "$tick" -lt "$OVERLORD_TICKS" ]; then
      return 0
    else
      return 1
    fi
  else
    return 0
  fi
}
