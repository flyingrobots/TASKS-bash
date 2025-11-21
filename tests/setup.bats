#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "${PROJECT_ROOT}/setup.sh" "$TEST_TMP/"
  cd "$TEST_TMP" || return 1
}

teardown() {
  [ -n "$TEST_TMP" ] && rm -rf "$TEST_TMP"
}

@test "setup.sh creates .tasks directory tree" {
  rm -rf .tasks
  run bash ./setup.sh
  [ "$status" -eq 0 ]

  expected=(manifest blocked open claimed closed dead logs prompts pids)

  # exact directory set
  actual=( $(find .tasks -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort) )
  expected_sorted=( $(printf '%s\n' "${expected[@]}" | sort) )
  diff_output=$(diff <(printf '%s\n' "${expected_sorted[@]}") <(printf '%s\n' "${actual[@]}") || true)
  [ -z "$diff_output" ]

  for dir in "${expected[@]}"; do
    [ -d ".tasks/${dir}" ]
    [ "$(find ".tasks/${dir}" -mindepth 1 | wc -l)" -eq 0 ]
    perms=$(stat -c '%f' ".tasks/${dir}" 2>/dev/null || stat -f '%p' ".tasks/${dir}")
    # 0700 dirs => Linux raw mode 41c0, BSD/macOS raw mode 040700
    [[ "$perms" =~ (41c0|040700) ]]
  done
}

@test "setup.sh exports expected environment variables (defaults)" {
  run bash -c 'source ./setup.sh && printf "%s\n%s\n%s\n%s\n" "$TASKS_DIR" "$MAX_WORKERS" "$LLM_PLANNER_CMD" "$LLM_WORKER_CMD"'
  [ "$status" -eq 0 ]

  mapfile -t vars <<<"${output}"
  [ "${vars[0]}" = "$TEST_TMP/.tasks" ]
  [ "${vars[1]}" = "4" ]
  [ "${vars[2]}" = "claude -p" ]
  [ "${vars[3]}" = "claude --dangerously-skip-permissions" ]
}

@test "get_worker_id returns namespaced id (format)" {
  run bash -c "source ./setup.sh && get_worker_id && get_worker_id"
  [ "$status" -eq 0 ]
  mapfile -t ids <<<"${output}"
  id1="${ids[0]}"; id2="${ids[1]}"
  [[ "$id1" =~ ^w_[0-9]{10,}_[0-9]+_[0-9]+$ ]]
  [[ "$id2" =~ ^w_[0-9]{10,}_[0-9]+_[0-9]+$ ]]
  [ "$id1" != "$id2" ]
}
