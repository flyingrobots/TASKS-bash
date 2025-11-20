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

  GOAL_IN_PROMPT=$(grep -F "Ship a new feature" .tasks/prompts/architect.txt | wc -l)
  [ "$GOAL_IN_PROMPT" -ge 1 ]

  jq -e '.tasks[0].id == "task_01"' .tasks/manifest/dag.json >/dev/null
}
