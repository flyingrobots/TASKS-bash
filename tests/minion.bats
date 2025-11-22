#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "$PROJECT_ROOT/4_minion.sh" "$PROJECT_ROOT/setup.sh" "$TEST_TMP/"
  mkdir -p "$TEST_TMP/adapters"
  cp "$PROJECT_ROOT/adapters/log.sh" "$PROJECT_ROOT/adapters/llm_worker.sh" "$TEST_TMP/adapters/"

  mkdir -p "$TEST_TMP/.tasks/logs"

  cat > "$TEST_TMP/fake_worker_success.sh" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
exit 0
SH
  chmod +x "$TEST_TMP/fake_worker_success.sh"

  cat > "$TEST_TMP/fake_worker_fail.sh" <<'SH'
#!/usr/bin/env bash
exit 1
SH
  chmod +x "$TEST_TMP/fake_worker_fail.sh"

  cd "$TEST_TMP"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "minion moves task to closed on success" {
  # Generate unique IDs to avoid collisions
  local worker_id="w_${BATS_TEST_NUMBER}_$RANDOM"
  local task_id="task_${BATS_TEST_NUMBER}_$RANDOM"

  # Prepare fresh task file
  mkdir -p ".tasks/claimed/${worker_id}"
  cat > ".tasks/claimed/${worker_id}/${task_id}.json" <<JSON
{"id":"${task_id}","description":"do something"}
JSON

  TASKS_LLM_WORKER_CMD_JSON=$(jq -nc --arg p "$TEST_TMP/fake_worker_success.sh" '[ $p ]')
  export TASKS_LLM_WORKER_CMD_JSON
  run bash ./4_minion.sh "${worker_id}" "${task_id}"
  [ "$status" -eq 0 ]
  [ -f ".tasks/closed/${task_id}.json" ]
  [ -f ".tasks/logs/${task_id}.log" ]
  [ ! -d ".tasks/claimed/${worker_id}" ]
}

@test "minion moves task to dead on failure" {
  # Generate unique IDs to avoid collisions
  local worker_id="w_${BATS_TEST_NUMBER}_$RANDOM"
  local task_id="task_${BATS_TEST_NUMBER}_$RANDOM"

  # Explicitly prepare fresh state for this test
  rm -f ".tasks/closed/${task_id}.json" ".tasks/dead/${task_id}.json"
  mkdir -p ".tasks/claimed/${worker_id}"
  cat > ".tasks/claimed/${worker_id}/${task_id}.json" <<JSON
{"id":"${task_id}","description":"do something"}
JSON

  TASKS_LLM_WORKER_CMD_JSON=$(jq -nc --arg p "$TEST_TMP/fake_worker_fail.sh" '[ $p ]')
  export TASKS_LLM_WORKER_CMD_JSON
  run bash ./4_minion.sh "${worker_id}" "${task_id}"
  [ "$status" -ne 0 ]
  [ -f ".tasks/dead/${task_id}.json" ]
  [ -f ".tasks/logs/${task_id}.log" ]
  [ ! -d ".tasks/claimed/${worker_id}" ]
}

@test "minion fails on malformed task JSON" {
  # Create task file with invalid JSON
  local worker_id="w_${BATS_TEST_NUMBER}_$RANDOM"
  local task_id="task_${BATS_TEST_NUMBER}_$RANDOM"
  rm -f ".tasks/closed/${task_id}.json" ".tasks/dead/${task_id}.json"
  mkdir -p ".tasks/claimed/${worker_id}"
  echo "this is not valid JSON at all" > ".tasks/claimed/${worker_id}/${task_id}.json"

  TASKS_LLM_WORKER_CMD_JSON=$(jq -nc --arg p "$TEST_TMP/fake_worker_success.sh" '[ $p ]')
  export TASKS_LLM_WORKER_CMD_JSON
  run bash ./4_minion.sh "$worker_id" "$task_id"
  [ "$status" -ne 0 ]
  [[ "$output" =~ (JSON|parse|jq) ]]  # Regex is clearer than substring glob
  [ ! -f ".tasks/closed/${task_id}.json" ]
  [ -f ".tasks/dead/${task_id}.json" ]
  [ ! -d ".tasks/claimed/${worker_id}" ]
}
@test "minion fails when task file is missing" {
  # Start with nonexistent task file
  local worker_id="w_${BATS_TEST_NUMBER}_$RANDOM"
  local task_id="task_${BATS_TEST_NUMBER}_$RANDOM"
  mkdir -p ".tasks/claimed/${worker_id}"
  rm -f ".tasks/claimed/${worker_id}/${task_id}.json"

  TASKS_LLM_WORKER_CMD_JSON=$(jq -nc --arg p "$TEST_TMP/fake_worker_success.sh" '[ $p ]')
  export TASKS_LLM_WORKER_CMD_JSON
  run bash ./4_minion.sh "$worker_id" "$task_id"
  [ "$status" -ne 0 ]
  [[ "$output" =~ Task\ file\ not\ found\ for ]]
}

@test "minion fails when log directory is unwritable" {
  # Make logs directory unwritable
  chmod -w .tasks/logs

  local worker_id="w_${BATS_TEST_NUMBER}_$RANDOM"
  local task_id="task_${BATS_TEST_NUMBER}_$RANDOM"

  rm -f ".tasks/closed/${task_id}.json" ".tasks/dead/${task_id}.json"
  mkdir -p ".tasks/claimed/${worker_id}"
  cat > ".tasks/claimed/${worker_id}/${task_id}.json" <<JSON
{"id":"${task_id}","description":"test"}
JSON

  TASKS_LLM_WORKER_CMD_JSON=$(jq -nc --arg p "$TEST_TMP/fake_worker_success.sh" '[ $p ]')
  export TASKS_LLM_WORKER_CMD_JSON
  export TASKS_SKIP_LOCKDOWN=1
  run bash ./4_minion.sh "$worker_id" "$task_id"
  [ "$status" -ne 0 ]
  [ ! -f ".tasks/logs/${task_id}.log" ]

  # Restore permissions for cleanup
  chmod +w .tasks/logs
}

@test "minion reports cleanup failure when claimed dir is read-only" {
  local worker_id="w_${BATS_TEST_NUMBER}_$RANDOM"
  local task_id="task_${BATS_TEST_NUMBER}_$RANDOM"

  rm -f ".tasks/closed/${task_id}.json" ".tasks/dead/${task_id}.json"
  mkdir -p ".tasks/claimed/${worker_id}"
  cat > ".tasks/claimed/${worker_id}/${task_id}.json" <<JSON
{"id":"${task_id}","description":"test"}
JSON

  # Make claimed directory read-only and guarantee restoration
  trap 'chmod -R +w .tasks/claimed 2>/dev/null || true' EXIT
  chmod -w .tasks/claimed

  TASKS_LLM_WORKER_CMD_JSON=$(jq -nc --arg p "$TEST_TMP/fake_worker_success.sh" '[ $p ]')
  export TASKS_LLM_WORKER_CMD_JSON
  export TASKS_SKIP_LOCKDOWN=1
  run bash ./4_minion.sh "$worker_id" "$task_id"
  [ "$status" -ne 0 ]
  # The worker dir should remain because cleanup failed
  [[ "$output" == *"Failed to clean up worker directory"* ]]
  [ -d ".tasks/claimed/${worker_id}" ]
  chmod -R +w .tasks/claimed
}
