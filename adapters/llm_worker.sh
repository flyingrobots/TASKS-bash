#!/usr/bin/env bash

port_call_worker() {
  local prompt="$1"
  echo "$prompt" | $LLM_WORKER_CMD
}
