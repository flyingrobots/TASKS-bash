#!/usr/bin/env bash

tasks_overlord() {
  source adapters/fs.sh
  source adapters/log.sh
  source adapters/control.sh
  source lib/domain.sh

  declare -a MINION_PIDS=()

  port_launch_minion() {
      mkdir -p "$TASKS_DIR/pids"
      ./4_minion.sh "$1" "$2" &
      pid=$!
      MINION_PIDS+=($pid)
      echo $pid >"$TASKS_DIR/pids/$1.pid"
  }

  echo "👁️  Overlord is watching. Max Workers: $TASKS_MAX_WORKERS"

  graceful_shutdown() {
      echo "Overlord shutting down..."
      local pids=(${MINION_PIDS[@]})
      if [ -d "$TASKS_DIR/pids" ]; then
          for f in "$TASKS_DIR/pids"/*.pid; do
              [ -e "$f" ] || continue
              pid=$(cat "$f" 2>/dev/null)
              [ -n "$pid" ] && pids+=($pid)
          done
      fi
      for pid in "${pids[@]}"; do
          [ -n "$pid" ] || continue
          if kill -0 "$pid" 2>/dev/null; then
              kill -TERM "$pid" 2>/dev/null
          fi
          wait "$pid" 2>/dev/null || true
      done
      rm -f "$TASKS_DIR/pids"/*.pid 2>/dev/null || true
      exit
  }

  trap graceful_shutdown SIGINT SIGTERM

  TASKS_SLEEP_SECONDS=${TASKS_SLEEP_SECONDS:-2}

  tick=0
  while port_should_continue "$tick"; do
      domain_unblock_ready_tasks
      domain_spawn_next_task || true

      if [ ${#MINION_PIDS[@]} -gt 0 ]; then
          alive=()
          for pid in "${MINION_PIDS[@]}"; do
              if kill -0 "$pid" 2>/dev/null; then
                  alive+=($pid)
              else
                  wait "$pid" 2>/dev/null || true
              fi
          done
          MINION_PIDS=("${alive[@]}")
      fi

      tick=$((tick+1))
      sleep "$TASKS_SLEEP_SECONDS"
  done
}

