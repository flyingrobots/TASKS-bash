#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "$PROJECT_ROOT/3_overlord.sh" "$PROJECT_ROOT/4_minion.sh" "$PROJECT_ROOT/setup.sh" "$TEST_TMP/"
  mkdir -p "$TEST_TMP/adapters" "$TEST_TMP/lib"
  cp "$PROJECT_ROOT"/adapters/{fs.sh,log.sh,llm_worker.sh,control.sh} "$TEST_TMP/adapters/"
  cp "$PROJECT_ROOT/lib/domain.sh" "$TEST_TMP/lib/"

  mkdir -p "$TEST_TMP/.tasks/open" "$TEST_TMP/.tasks/claimed" "$TEST_TMP/.tasks/closed" "$TEST_TMP/.tasks/dead" "$TEST_TMP/.tasks/logs" "$TEST_TMP/.tasks/pids"

  # Generate unique task IDs to avoid collisions
  export TASK1_ID="t1_$$_$RANDOM"
  export TASK2_ID="t2_$$_$RANDOM"

  cat >"$TEST_TMP/.tasks/open/${TASK1_ID}.json" <<JSON
{"id":"${TASK1_ID}","description":"first"}
JSON
  cat >"$TEST_TMP/.tasks/open/${TASK2_ID}.json" <<JSON
{"id":"${TASK2_ID}","description":"second"}
JSON

  # Enhanced stub worker: logs invocations and exits successfully
  cat > "$TEST_TMP/fake_worker.sh" <<SH
#!/usr/bin/env bash
echo "Worker invoked with args: \$*" >> "$TEST_TMP/worker.log"
exit 0
SH
  chmod +x "$TEST_TMP/fake_worker.sh"

  cd "$TEST_TMP"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "overlord spawns sequential tasks and reuses capacity" {
  export LLM_WORKER_CMD="$TEST_TMP/fake_worker.sh"
  export MAX_WORKERS=1
  export OVERLORD_TICKS=10
  export SLEEP_SECONDS=0.1

  chmod +x ./3_overlord.sh ./4_minion.sh adapters/*.sh lib/*.sh
  run bash ./3_overlord.sh
  [ "$status" -eq 0 ]

  # Verify tasks were processed using dynamic IDs
  [ -f ".tasks/closed/${TASK1_ID}.json" ]
  [ -f ".tasks/closed/${TASK2_ID}.json" ]

  # Claimed directory should exist and be empty
  [ -d .tasks/claimed ]
  empty_check=$(find .tasks/claimed -mindepth 1 -print -quit)
  [ -z "$empty_check" ]

  # Verify worker was invoked (enhanced stub logs invocations)
  [ -f "$TEST_TMP/worker.log" ]
}
