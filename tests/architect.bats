#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "${PROJECT_ROOT}/setup.sh" "${PROJECT_ROOT}/1_architect.sh" "$TEST_TMP/"
  mkdir -p "$TEST_TMP/adapters"
  cp "${PROJECT_ROOT}/adapters/log.sh" "${PROJECT_ROOT}/adapters/llm_planner.sh" "$TEST_TMP/adapters/"
  mkdir -p "$TEST_TMP/tests/fixtures"
  cp "${PROJECT_ROOT}/tests/fixtures/fake_planner.sh" "$TEST_TMP/tests/fixtures/"
  chmod +x "$TEST_TMP/tests/fixtures/fake_planner.sh"
  cd "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "1_architect.sh requires a goal argument" {
  run bash ./1_architect.sh
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "1_architect.sh produces manifest JSON using fake planner" {
  export LLM_PLANNER_CMD="$TEST_TMP/tests/fixtures/fake_planner.sh"

  run bash ./1_architect.sh "Ship a new feature"
  [ "$status" -eq 0 ]

  [ -f .tasks/manifest/dag.json ]
  [ -s .tasks/manifest/dag.json ]
  [ -f .tasks/prompts/architect.txt ]

  # Validate structured GOAL format with exact match
  run grep -c "^GOAL: Ship a new feature$" .tasks/prompts/architect.txt
  GOAL_COUNT=${output:-0}
  [ "$GOAL_COUNT" -eq 1 ]

  jq -e '.tasks[0].id == "bootstrap"' .tasks/manifest/dag.json >/dev/null
}

@test "1_architect.sh fails when planner exits non-zero" {
  # Create a fixture planner that exits with error
  cat >"$TEST_TMP/tests/fixtures/failing_planner.sh" <<'SCRIPT'
#!/usr/bin/env bash
echo "Planner error occurred" >&2
exit 1
SCRIPT
  chmod +x "$TEST_TMP/tests/fixtures/failing_planner.sh"

  export LLM_PLANNER_CMD="$TEST_TMP/tests/fixtures/failing_planner.sh"

  run bash ./1_architect.sh "Test goal"
  [ "$status" -ne 0 ]
  [ ! -f .tasks/manifest/dag.json ]
}

@test "1_architect.sh fails on invalid JSON from planner" {
  # Create a fixture planner that outputs invalid JSON
  cat >"$TEST_TMP/tests/fixtures/invalid_json_planner.sh" <<'SCRIPT'
#!/usr/bin/env bash
echo "This is not valid JSON"
SCRIPT
  chmod +x "$TEST_TMP/tests/fixtures/invalid_json_planner.sh"

  export LLM_PLANNER_CMD="$TEST_TMP/tests/fixtures/invalid_json_planner.sh"

  run bash ./1_architect.sh "Test goal"
  [ "$status" -ne 0 ]
  [[ "$output" == *"parse"* ]] || [[ "$output" == *"JSON"* ]] || [[ "$output" == *"jq"* ]]
}

@test "1_architect.sh handles empty tasks array" {
  # Create a fixture planner that returns empty tasks
  cat >"$TEST_TMP/tests/fixtures/empty_tasks_planner.sh" <<'SCRIPT'
#!/usr/bin/env bash
echo '{"tasks":[]}'
SCRIPT
  chmod +x "$TEST_TMP/tests/fixtures/empty_tasks_planner.sh"

  export LLM_PLANNER_CMD="$TEST_TMP/tests/fixtures/empty_tasks_planner.sh"

  run bash ./1_architect.sh "Test goal"
  # Script should handle empty manifest appropriately
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty"* ]] || [[ "$output" == *"no tasks"* ]]
}

@test "1_architect.sh fails when manifest directory is unwritable" {
  # Create directories first
  mkdir -p .tasks/manifest .tasks/prompts

  # Make the manifest directory unwritable
  chmod -w .tasks/manifest

  export LLM_PLANNER_CMD="$TEST_TMP/tests/fixtures/fake_planner.sh"

  run bash ./1_architect.sh "Test goal"
  [ "$status" -ne 0 ]
  [[ "$output" == *"write"* ]] || [[ "$output" == *"permission"* ]] || [[ "$output" == *"denied"* ]]

  # Restore permissions for teardown
  chmod +w .tasks/manifest
}
