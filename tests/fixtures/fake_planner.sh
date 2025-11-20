#!/usr/bin/env bash

# Minimal fake planner used in tests to avoid external LLM calls.
# Ignores all arguments and prints deterministic JSON to stdout.
cat <<'JSON'
{
  "tasks": [
    {
      "id": "task_01",
      "title": "Example Task",
      "description": "Test task created by fake planner"
    }
  ]
}
JSON
