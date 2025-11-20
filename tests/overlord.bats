#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "$PROJECT_ROOT/3_overlord.sh" "$PROJECT_ROOT/4_minion.sh" "$PROJECT_ROOT/setup.sh" "$TEST_TMP/"
  mkdir -p "$TEST_TMP/adapters" "$TEST_TMP/lib"
  cp "$PROJECT_ROOT"/adapters/{fs.sh,log.sh,llm_worker.sh,control.sh} "$TEST_TMP/adapters/"
  cp "$PROJECT_ROOT/lib/domain.sh" "$TEST_TMP/lib/"

  mkdir -p "$TEST_TMP/.tasks/open" "$TEST_TMP/.tasks/claimed" "$TEST_TMP/.tasks/closed" "$TEST_TMP/.tasks/dead" "$TEST_TMP/.tasks/logs" "$TEST_TMP/.tasks/pids"
  cat >"$TEST_TMP/.tasks/open/t1.json" <<'JSON'
{"id":"t1","description":"first"}
JSON
  cat >"$TEST_TMP/.tasks/open/t2.json" <<'JSON'
{"id":"t2","description":"second"}
JSON

  # Stub worker: exits success immediately
  cat > "$TEST_TMP/fake_worker.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$TEST_TMP/fake_worker.sh"

  cd "$TEST_TMP"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "overlord spawns sequential tasks and reuses capacity" {
  export LLM_WORKER_CMD="$TEST_TMP/fake_worker.sh"
  export MAX_WORKERS=1
  export OVERLORD_TICKS=5
  export SLEEP_SECONDS=0

  chmod +x ./3_overlord.sh ./4_minion.sh adapters/*.sh lib/*.sh
  run bash ./3_overlord.sh
  [ "$status" -eq 0 ]

  [ -f .tasks/closed/t1.json ]
  [ -f .tasks/closed/t2.json ]
  # Claimed dirs should be cleaned up by minions
  [ ! -d .tasks/claimed ] || [ "$(find .tasks/claimed -mindepth 1 -print -quit)" = "" ]
}
