#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  export TASKS_DIR="$TEST_TMP/.tasks"
  mkdir -p "$TASKS_DIR"/{blocked,open,closed,claimed}
  export MAX_WORKERS=1

  # Minimal adapters for domain use
  port_list_blocked_tasks() { ls "$TASKS_DIR/blocked"/*.json 2>/dev/null || true; }
  port_read_dependencies() { jq -r '.dependencies[]?' "$1"; }
  port_is_closed() { [ -f "$TASKS_DIR/closed/$1.json" ]; }
  port_unblock_task() { mv "$1" "$TASKS_DIR/open/"; }
  port_count_claimed_workers() { ls -d "$TASKS_DIR/claimed"/*/ 2>/dev/null | wc -l; }
  port_count_open_tasks() { ls "$TASKS_DIR/open"/*.json 2>/dev/null | wc -l; }
  port_pick_open_task() { ls "$TASKS_DIR/open"/*.json 2>/dev/null | head -n1; }
  port_new_worker_id() { echo "w_test"; }
  port_claim_task() {
    worker_id="$1"; task_path="$2"; task_id="$3"
    mkdir -p "$TASKS_DIR/claimed/$worker_id"
    mv "$task_path" "$TASKS_DIR/claimed/$worker_id/$task_id.json"
  }
  port_launch_minion() { echo "$1 $2" >>"$TEST_TMP/spawned.txt"; }
  port_log_info() { :; }
  port_log_error() { :; }

  source "$PROJECT_ROOT/lib/domain.sh"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "unblock_ready_tasks moves blocked task when deps are closed" {
  cat >"$TASKS_DIR/blocked/t1.json" <<'JSON'
{"id":"t1","dependencies":["t0"]}
JSON
  touch "$TASKS_DIR/closed/t0.json"

  domain_unblock_ready_tasks

  [ ! -f "$TASKS_DIR/blocked/t1.json" ]
  [ -f "$TASKS_DIR/open/t1.json" ]
}

@test "unblock_ready_tasks leaves task blocked when deps missing" {
  cat >"$TASKS_DIR/blocked/t2.json" <<'JSON'
{"id":"t2","dependencies":["missing"]}
JSON

  domain_unblock_ready_tasks

  [ -f "$TASKS_DIR/blocked/t2.json" ]
  [ ! -f "$TASKS_DIR/open/t2.json" ]
}

@test "spawn_next_task respects MAX_WORKERS and claims task" {
  export MAX_WORKERS=1
  mkdir -p "$TASKS_DIR/claimed/worker_existing"
  touch "$TASKS_DIR/claimed/worker_existing/.keep"
  cat >"$TASKS_DIR/open/t3.json" <<'JSON'
{"id":"t3"}
JSON

  # With one existing worker, should refuse spawn
  run domain_spawn_next_task
  [ "$status" -eq 1 ]

  # Free slot and try again
  rm -rf "$TASKS_DIR/claimed/worker_existing"
  run domain_spawn_next_task
  [ "$status" -eq 0 ]
  [ -f "$TASKS_DIR/claimed/w_test/t3.json" ]
  [ -f "$TEST_TMP/spawned.txt" ]
}
