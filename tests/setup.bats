#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "${PROJECT_ROOT}/setup.sh" "$TEST_TMP/"
  cd "$TEST_TMP"
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "setup.sh creates .tasks directory tree" {
  run bash -c "source ./setup.sh"
  [ "$status" -eq 0 ]

  for dir in manifest blocked open claimed closed dead logs prompts; do
    [ -d ".tasks/${dir}" ]
  done
}

@test "setup.sh exports expected environment variables" {
  run bash -c 'source ./setup.sh && echo "$TASKS_DIR:$MAX_WORKERS:$LLM_PLANNER_CMD:$LLM_WORKER_CMD"'
  [ "$status" -eq 0 ]

  IFS=':' read -r tasks_dir max_workers planner_cmd worker_cmd <<<"${output}"
  [ "$tasks_dir" = "$TEST_TMP/.tasks" ]
  [ "$max_workers" = "4" ]
  [ "$planner_cmd" = "claude -p" ]
  [ "$worker_cmd" = "claude --dangerously-skip-permissions" ]
}

@test "get_worker_id returns namespaced id" {
  run bash -c "source ./setup.sh && get_worker_id"
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^w_[0-9]{10}_[0-9]+$ ]]
}
