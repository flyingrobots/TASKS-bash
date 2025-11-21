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
  mapfile -t actual < <(find .tasks -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
  mapfile -t expected_sorted < <(printf '%s\n' "${expected[@]}" | sort)
  diff_output=$(diff <(printf '%s\n' "${expected_sorted[@]}") <(printf '%s\n' "${actual[@]}") || true)
  [ -z "$diff_output" ]

  for dir in "${expected[@]}"; do
    [ "$(find ".tasks/${dir}" -mindepth 1 | wc -l)" -eq 0 ]
  perms=$(stat -c '%a' ".tasks/${dir}" 2>/dev/null || stat -f '%Lp' ".tasks/${dir}")
    perms=${perms#0}
    [ "$perms" = "700" ]
  done
}

@test "setup.sh exports expected environment variables (defaults)" {
  run bash -c 'source ./setup.sh && printf "%s\n%s\n%s\n%s\n" "$TASKS_DIR" "$MAX_WORKERS" "$LLM_PLANNER_CMD" "$LLM_WORKER_CMD_STR"'
  [ "$status" -eq 0 ]

  mapfile -t vars < <(printf '%s' "$output")
  [ "${vars[0]}" = "$TEST_TMP/.tasks" ]
  [ "${vars[1]}" = "4" ]
  [ "${vars[2]}" = "claude -p" ]
  [ "${vars[3]}" = "claude --dangerously-skip-permissions" ]
}

@test "get_worker_id returns namespaced id (format)" {
  run bash -c "source ./setup.sh && get_worker_id && get_worker_id"
  [ "$status" -eq 0 ]
  mapfile -t ids < <(printf '%s' "$output")
  id1="${ids[0]}"; id2="${ids[1]}"
  [[ "$id1" =~ ^w_[A-Za-z0-9]+_[0-9]+_[0-9]+$ ]]
  [[ "$id2" =~ ^w_[A-Za-z0-9]+_[0-9]+_[0-9]+$ ]]
  IFS='_' read -r p1 rand1 ts1 pid1 <<<"$id1"
  IFS='_' read -r p2 rand2 ts2 pid2 <<<"$id2"
  [[ -n "$p1" && -n "$rand1" && -n "$ts1" && -n "$pid1" ]]
  [[ -n "$p2" && -n "$rand2" && -n "$ts2" && -n "$pid2" ]]
  [ "$rand1" != "$rand2" ] || [ "$ts1" != "$ts2" ] || [ "$pid1" != "$pid2" ]
}

@test "TASKS_SKIP_LOCKDOWN leaves default permissions" {
  export TASKS_DIR="$TEST_TMP/skiplock"
  export TASKS_SKIP_LOCKDOWN=1
  run bash -c 'umask 022 && ./setup.sh'
  [ "$status" -eq 0 ]

  perms=$(stat -c '%a' "$TASKS_DIR" 2>/dev/null || stat -f '%Lp' "$TASKS_DIR")
  [ "$perms" != "700" ]
}
