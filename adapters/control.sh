#!/usr/bin/env bash

# Decide whether the overlord loop should continue. Accepts current tick as $1.
port_should_continue() {
  local tick="$1"
  if [ -n "$OVERLORD_TICKS" ]; then
    [ "$tick" -lt "$OVERLORD_TICKS" ]
  else
    return 0
  fi
}
