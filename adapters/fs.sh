#!/usr/bin/env bash

port_list_blocked_tasks() { ls "$TASKS_DIR/blocked"/*.json 2>/dev/null || true; }
port_read_dependencies() { jq -r '.dependencies[]?' "$1"; }
port_is_closed() { [ -f "$TASKS_DIR/closed/$1.json" ]; }
port_unblock_task() { mv "$1" "$TASKS_DIR/open/"; }
port_count_claimed_workers() {
  mkdir -p "$TASKS_DIR/pids"
  local alive=0
  for pidfile in "$TASKS_DIR/pids"/*.pid; do
    [ -e "$pidfile" ] || continue
    pid=$(cat "$pidfile" 2>/dev/null || true)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      alive=$((alive+1))
    else
      rm -f "$pidfile"
    fi
  done
  echo "$alive"
}
port_count_open_tasks() { ls "$TASKS_DIR/open"/*.json 2>/dev/null | wc -l; }
port_pick_open_task() { ls "$TASKS_DIR/open"/*.json 2>/dev/null | head -n1; }
port_new_worker_id() { get_worker_id; }
port_claim_task() {
  local worker_id="$1" task_path="$2" task_id="$3"
  mkdir -p "$TASKS_DIR/claimed/$worker_id"
  mv "$task_path" "$TASKS_DIR/claimed/$worker_id/$task_id.json"
}
