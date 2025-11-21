#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "$PROJECT_ROOT/4_minion.sh" "$PROJECT_ROOT/setup.sh" "$TEST_TMP/"
  mkdir -p "$TEST_TMP/adapters"
  cp "$PROJECT_ROOT/adapters/log.sh" "$PROJECT_ROOT/adapters/llm_worker.sh" "$TEST_TMP/adapters/"

  mkdir -p "$TEST_TMP/.tasks/claimed/w1" "$TEST_TMP/.tasks/logs"
  cat > "$TEST_TMP/.tasks/claimed/w1/task1.json" <<'JSON'
{"id":"task1","description":"do something"}
JSON

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

  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_success.sh"
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

  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_fail.sh"
  run bash ./4_minion.sh "${worker_id}" "${task_id}"
  [ "$status" -ne 0 ]
  [ -f ".tasks/dead/${task_id}.json" ]
  [ -f ".tasks/logs/${task_id}.log" ]
  [ ! -d ".tasks/claimed/${worker_id}" ]
}

@test "minion fails on malformed task JSON" {
  # Create task file with invalid JSON
  rm -f .tasks/closed/task_bad.json .tasks/dead/task_bad.json
  mkdir -p .tasks/claimed/w_bad
  echo "this is not valid JSON at all" > .tasks/claimed/w_bad/task_bad.json

  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_success.sh"
  run bash ./4_minion.sh w_bad task_bad
  [ "$status" -ne 0 ]
  [[ "$output" == *"jq"* ]] || [[ "$stderr" == *"parse"* ]] || [[ "$stderr" == *"JSON"* ]]
}

@test "minion fails when task file is missing" {
  # Start with nonexistent task file
  mkdir -p .tasks/claimed/w_missing
  rm -f .tasks/claimed/w_missing/task_missing.json

  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_success.sh"
  run bash ./4_minion.sh w_missing task_missing
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]] || [[ "$stderr" == *"not found"* ]]
}

@test "minion fails when log directory is unwritable" {
  # Make logs directory unwritable
  chmod -w .tasks/logs

  rm -f .tasks/closed/task_nolog.json .tasks/dead/task_nolog.json
  mkdir -p .tasks/claimed/w_nolog
  cat > .tasks/claimed/w_nolog/task_nolog.json <<'JSON'
{"id":"task_nolog","description":"test"}
JSON

  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_success.sh"
  run bash ./4_minion.sh w_nolog task_nolog
  [ "$status" -ne 0 ]

  # Restore permissions for cleanup
  chmod +w .tasks/logs
}

@test "minion reports cleanup failure when claimed dir is read-only" {
  rm -f .tasks/closed/task_ro.json .tasks/dead/task_ro.json
  mkdir -p .tasks/claimed/w_ro
  cat > .tasks/claimed/w_ro/task_ro.json <<'JSON'
{"id":"task_ro","description":"test"}
JSON

  # Make claimed directory read-only
  chmod -w .tasks/claimed

  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_success.sh"
  run bash ./4_minion.sh w_ro task_ro
  [ "$status" -ne 0 ]
  [[ "$output" == *"cleanup"* ]] || [[ "$stderr" == *"cleanup"* ]] || [[ "$output" == *"Invalid"* ]]

  # Restore permissions for cleanup
  chmod +w .tasks/claimed
}
