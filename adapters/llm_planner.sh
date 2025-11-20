#!/usr/bin/env bash

port_call_planner() {
  local prompt_file="$1" prompt_text="$2"
  $LLM_PLANNER_CMD "$prompt_file" "$prompt_text"
}
