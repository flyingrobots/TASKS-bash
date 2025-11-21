#!/usr/bin/env bash

# Minimal fake planner used in tests to avoid external LLM calls.
# Ignores all arguments and prints deterministic JSON to stdout.
cat <<'JSON'
{
  "tasks": [
    {
      "description": "Test task created by fake planner",
      "id": "task_01",
      "title": "Example Task"
    }
  ]
}
JSON
