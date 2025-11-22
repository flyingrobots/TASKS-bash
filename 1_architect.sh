#!/usr/bin/env bash
source setup.sh
source adapters/log.sh
source adapters/llm_planner.sh

GOAL="$1"
if [ -z "$GOAL" ]; then 
    echo "Usage: ./1_architect.sh 'Your goal here'" >&2
    exit 1
fi

PROMPT_TEMPLATE="${TASKS_ARCHITECT_TEMPLATE:-$TASKS_DIR/prompts/architect_template.txt}"
PROMPT_FILE="$TASKS_DIR/prompts/architect.txt"

# Load template (fallback to built-in default if missing)
if [ -f "$PROMPT_TEMPLATE" ]; then
    template_content=$(cat "$PROMPT_TEMPLATE")
else
    template_content="You are the T.A.S.K.S. Architect.\n\nCONTEXT:\n- Project file tree intentionally omitted to keep the prompt light.\n- If you need directory context, explicitly ask for a targeted, shallow listing rather than the whole repo.\n\nGOAL: {{GOAL}}\n\nRULES:\n1. Break the goal into atomic, bounded tasks (2-4 hours estimated effort).\n2. NO CYCLES in dependencies.\n3. Output ONLY valid JSON. Do not include markdown fences or chatter.\n4. Reference existing files from the context in your task scopes."
fi

# Render template
prompt_rendered=${template_content//{{GOAL}}/$GOAL}

if ! printf '%s\n' "$prompt_rendered" > "$PROMPT_FILE"; then
    port_log_error "Failed to write prompt file"
    exit 1
fi

port_log_info "🧠 Architect is thinking (using $TASKS_LLM_PLANNER_CMD)..."

# Use temp file to avoid creating output on failure
TEMP_MANIFEST="$TASKS_DIR/manifest/dag.json.tmp"
if ! port_call_planner "$PROMPT_FILE" "Generate the execution plan." > "$TEMP_MANIFEST"; then
    rm -f "$TEMP_MANIFEST"
    port_log_error "❌ Planner command failed"
    exit 1
fi

# Validate JSON output
if ! jq empty "$TEMP_MANIFEST" 2>/dev/null; then
    rm -f "$TEMP_MANIFEST"
    port_log_error "❌ Planner produced invalid JSON"
    exit 1
fi

# Check for empty tasks array
task_count=$(jq '.tasks | length' "$TEMP_MANIFEST" 2>/dev/null || echo 0)
if [ "$task_count" -eq 0 ]; then
    rm -f "$TEMP_MANIFEST"
    port_log_error "❌ Planner produced no tasks or empty tasks array"
    exit 1
fi

# Move to final location on success
mv "$TEMP_MANIFEST" "$TASKS_DIR/manifest/dag.json"
port_log_info "✅ Plan generated at $TASKS_DIR/manifest/dag.json"
