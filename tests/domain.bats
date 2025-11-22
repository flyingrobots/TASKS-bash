#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  export TASKS_DIR="$TEST_TMP/.tasks"
  mkdir -p "$TASKS_DIR"/{blocked,open,closed,claimed}
  export TASKS_MAX_WORKERS=1

  # Minimal adapters for domain use
  port_list_blocked_tasks() { ls "$TASKS_DIR/blocked"/*.json 2>/dev/null || true; }
  port_read_dependencies() { jq -r '.dependencies[]?' "$1"; }
  port_is_closed() { [ -f "$TASKS_DIR/closed/$1.json" ]; }
  port_unblock_task() { mv "$1" "$TASKS_DIR/open/"; }
  port_count_claimed_workers() { ls -d "$TASKS_DIR/claimed"/*/ 2>/dev/null | wc -l; }
  port_count_open_tasks() { ls "$TASKS_DIR/open"/*.json 2>/dev/null | wc -l; }
  port_pick_open_task() { ls "$TASKS_DIR/open"/*.json 2>/dev/null | head -n1; }
  port_new_worker_id() { echo "w_test_${BATS_TEST_NUMBER}_$RANDOM"; }
  port_claim_task() {
    local worker_id="$1" task_path="$2" task_id="$3"
    mkdir -p "$TASKS_DIR/claimed/$worker_id"
    mv "$task_path" "$TASKS_DIR/claimed/$worker_id/$task_id.json"
  }
  port_launch_minion() { echo "$1 $2" >>"$TEST_TMP/spawned.txt"; }
  port_log_info() { :; }
  port_log_error() { :; }

  # Export all adapter functions for subprocess use
  export -f port_list_blocked_tasks
  export -f port_read_dependencies
  export -f port_is_closed
  export -f port_unblock_task
  export -f port_count_claimed_workers
  export -f port_count_open_tasks
  export -f port_pick_open_task
  export -f port_new_worker_id
  export -f port_claim_task
  export -f port_launch_minion
  export -f port_log_info
  export -f port_log_error

  # Check domain.sh exists before sourcing
  if [ ! -f "$PROJECT_ROOT/lib/domain.sh" ]; then
    echo "Error: domain.sh not found at $PROJECT_ROOT/lib/domain.sh" >&2
    exit 1
  fi

  source "$PROJECT_ROOT/lib/domain.sh"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "unblock_ready_tasks moves blocked task when deps are closed" {
  # Generate unique task IDs to avoid collisions
  local id0="t0_${BATS_TEST_NUMBER}_$RANDOM"
  local id1="t1_${BATS_TEST_NUMBER}_$RANDOM"

  cat >"$TASKS_DIR/blocked/${id1}.json" <<JSON
{"id":"${id1}","dependencies":["${id0}"]}
JSON
  touch "$TASKS_DIR/closed/${id0}.json"

  domain_unblock_ready_tasks

  [ ! -f "$TASKS_DIR/blocked/${id1}.json" ]
  [ -f "$TASKS_DIR/open/${id1}.json" ]
}

@test "unblock_ready_tasks leaves task blocked when deps missing" {
  # Generate unique task IDs to avoid collisions
  local RAND="$(date +%s)${BATS_TEST_NUMBER}_$RANDOM"
  local TID="t2_${RAND}"
  local MISSING="missing_${RAND}"

  cat >"$TASKS_DIR/blocked/${TID}.json" <<JSON
{"id":"${TID}","dependencies":["${MISSING}"]}
JSON

  domain_unblock_ready_tasks

  [ -f "$TASKS_DIR/blocked/${TID}.json" ]
  [ ! -f "$TASKS_DIR/open/${TID}.json" ]
}

@test "spawn_next_task respects TASKS_MAX_WORKERS and claims task" {
  # Generate unique task and worker IDs
  local TASK_ID="t3_${BATS_TEST_NUMBER}_$RANDOM"
  local EXISTING_WORKER="worker_existing_${BATS_TEST_NUMBER}_$RANDOM"

  mkdir -p "$TASKS_DIR/claimed/${EXISTING_WORKER}"
  cat >"$TASKS_DIR/open/${TASK_ID}.json" <<JSON
{"id":"${TASK_ID}"}
JSON

  # With one existing worker, should refuse spawn
  run domain_spawn_next_task
  [ "$status" -eq 1 ]

  # Free slot and try again
  rm -rf "$TASKS_DIR/claimed/${EXISTING_WORKER}"
  run domain_spawn_next_task
  [ "$status" -eq 0 ]

  # Check that a worker was claimed (pattern matches unique worker ID)
  claimed_workers=$(ls -d "$TASKS_DIR/claimed"/w_test_* 2>/dev/null | wc -l)
  [ "$claimed_workers" -eq 1 ]

  # Check that task was moved to claimed
  claimed_task=$(find "$TASKS_DIR/claimed" -name "${TASK_ID}.json" | wc -l)
  [ "$claimed_task" -eq 1 ]

  # Validate spawned.txt contains the expected task ID
  [ -f "$TEST_TMP/spawned.txt" ]
  spawned_content=$(cat "$TEST_TMP/spawned.txt")
  [[ "$spawned_content" == *"${TASK_ID}"* ]] || {
    echo "Expected task ID ${TASK_ID} in spawned.txt, got: $spawned_content" >&2
    exit 1
  }
}
