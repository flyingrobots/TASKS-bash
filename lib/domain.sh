#!/usr/bin/env bash

# Domain-level functions that rely on port_* adapters provided by callers.

# Move any blocked task whose dependencies are all closed into open.
domain_unblock_ready_tasks() {
  # Use process substitution to safely iterate over task files
  while IFS= read -r task_file; do
    [ -e "$task_file" ] || continue

    # Use local variables to avoid polluting global scope
    local task_id deps all_met
    task_id=$(basename "$task_file" .json)
    deps=$(port_read_dependencies "$task_file")

    all_met=true
    if [ -n "$deps" ]; then
      # Read dependencies line-by-line to handle whitespace safely
      local dep
      while IFS= read -r dep; do
        if ! port_is_closed "$dep"; then
          all_met=false
          break
        fi
      done <<< "$deps"
    fi

    if [ "$all_met" = true ]; then
      port_unblock_task "$task_file"
      port_log_info "Unblocked $task_id"
    fi
  done < <(port_list_blocked_tasks)
}

# Spawn a worker if capacity and open tasks exist.
# Returns 0 if a spawn occurred, 1 otherwise.
domain_spawn_next_task() {
  local current open_count
  current=$(port_count_claimed_workers)
  open_count=$(port_count_open_tasks)

  if [ "$current" -ge "${MAX_WORKERS:-1}" ]; then
    return 1
  fi
  if [ "$open_count" -le 0 ]; then
    return 1
  fi

  # Use local variables to avoid global scope pollution
  local task_path task_id worker_id
  task_path=$(port_pick_open_task)
  [ -n "$task_path" ] || return 1
  task_id=$(basename "$task_path" .json)
  worker_id=$(port_new_worker_id)

  port_claim_task "$worker_id" "$task_path" "$task_id"
  port_launch_minion "$worker_id" "$task_id"
  port_log_info "Spawned $worker_id for $task_id"
  return 0
}
