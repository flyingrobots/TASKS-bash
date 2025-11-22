#!/usr/bin/env bash

tasks_overlord() {
  local script_dir="${1:-}"
  shift || true

  if [ -z "$script_dir" ]; then
    script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  fi

  [ -r "$script_dir/adapters/fs.sh" ] || { echo "missing: $script_dir/adapters/fs.sh" >&2; exit 1; }
  [ -r "$script_dir/adapters/log.sh" ] || { echo "missing: $script_dir/adapters/log.sh" >&2; exit 1; }
  [ -r "$script_dir/adapters/control.sh" ] || { echo "missing: $script_dir/adapters/control.sh" >&2; exit 1; }
  [ -r "$script_dir/lib/domain.sh" ] || { echo "missing: $script_dir/lib/domain.sh" >&2; exit 1; }

  source "$script_dir/adapters/fs.sh"
  source "$script_dir/adapters/log.sh"
  source "$script_dir/adapters/control.sh"
  source "$script_dir/lib/domain.sh"

  declare -a MINION_PIDS=()

  port_launch_minion() {
      mkdir -p "$TASKS_DIR/pids" || { port_log_error "Failed to ensure $TASKS_DIR/pids"; return 1; }
      "$script_dir/4_minion.sh" "$1" "$2" &
      local pid=$!
      MINION_PIDS+=("$pid")
      if ! echo "$pid" >"$TASKS_DIR/pids/$1.pid"; then
        port_log_error "Failed to record pid for $1"
        return 1
      fi
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

  command -v port_should_continue >/dev/null || { port_log_error "Missing port_should_continue"; exit 1; }
  command -v domain_unblock_ready_tasks >/dev/null || { port_log_error "Missing domain_unblock_ready_tasks"; exit 1; }
  command -v domain_spawn_next_task >/dev/null || { port_log_error "Missing domain_spawn_next_task"; exit 1; }

  tick=0
  while port_should_continue "$tick"; do

      domain_unblock_ready_tasks
      if ! domain_spawn_next_task; then
        port_log_error "domain_spawn_next_task failed at tick $tick"
      fi

      if [ ${#MINION_PIDS[@]} -gt 0 ]; then
          alive=()
          for pid in "${MINION_PIDS[@]}"; do
              if wait "$pid" 2>/dev/null; then
                  continue
              else
                  # if not finished yet, keep tracking
                  if kill -0 "$pid" 2>/dev/null; then
                      alive+=("$pid")
                  fi
              fi
          done
          MINION_PIDS=("${alive[@]}")
      fi

      tick=$((tick+1))
      sleep "$TASKS_SLEEP_SECONDS"
  done
}
