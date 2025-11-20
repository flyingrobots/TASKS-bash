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
  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_success.sh"
  run bash ./4_minion.sh w1 task1
  [ "$status" -eq 0 ]
  [ -f .tasks/closed/task1.json ]
  [ -f .tasks/logs/task1.log ]
}

@test "minion moves task to dead on failure" {
  cp .tasks/closed/task1.json .tasks/claimed/w1/task1.json 2>/dev/null || true
  rm -f .tasks/closed/task1.json .tasks/dead/task1.json
  export LLM_WORKER_CMD="$TEST_TMP/fake_worker_fail.sh"
  run bash ./4_minion.sh w1 task1
  [ "$status" -eq 1 ]
  [ -f .tasks/dead/task1.json ]
  [ -f .tasks/logs/task1.log ]
}
