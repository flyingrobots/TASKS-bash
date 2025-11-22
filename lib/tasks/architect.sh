#!/usr/bin/env bash

tasks_architect() {
  local goal="$1"
  if [ -z "$goal" ]; then
    echo "Usage: tasks_architect '<goal>'" >&2
    return 1
  fi

  local prompt_template="${TASKS_ARCHITECT_TEMPLATE:-$TASKS_DIR/prompts/architect_template.txt}"
  local prompt_file="$TASKS_DIR/prompts/architect.txt"

  if [ -f "$prompt_template" ]; then
    template_content=$(cat "$prompt_template")
  else
    template_content="You are the T.A.S.K.S. Architect.\n\nCONTEXT:\n- Project file tree intentionally omitted to keep the prompt light.\n- If you need directory context, explicitly ask for a targeted, shallow listing rather than the whole repo.\n\nGOAL: {{GOAL}}\n\nRULES:\n1. Break the goal into atomic, bounded tasks (2-4 hours).\n2. NO CYCLES in dependencies.\n3. Output ONLY valid JSON.\n4. Reference existing files from the context in your task scopes."
  fi

  prompt_rendered=${template_content//\{\{GOAL\}\}/$goal}
  if ! printf '%s\n' "$prompt_rendered" > "$prompt_file"; then
    port_log_error "Failed to write prompt file"
    return 1
  fi

  local temp_manifest="$TASKS_DIR/manifest/dag.json.tmp"
  if ! port_call_planner "$prompt_file" "Generate the execution plan." > "$temp_manifest"; then
    rm -f "$temp_manifest"
    port_log_error "❌ Planner command failed"
    return 1
  fi

  if ! jq empty "$temp_manifest" 2>/dev/null; then
    rm -f "$temp_manifest"
    port_log_error "❌ Planner produced invalid JSON"
    return 1
  fi

  local task_count
  task_count=$(jq '.tasks | length' "$temp_manifest" 2>/dev/null || echo 0)
  if [ "$task_count" -eq 0 ]; then
    rm -f "$temp_manifest"
    port_log_error "❌ Planner produced no tasks or empty tasks array"
    return 1
  fi

  mv "$temp_manifest" "$TASKS_DIR/manifest/dag.json"
  port_log_info "✅ Plan generated at $TASKS_DIR/manifest/dag.json"
}

