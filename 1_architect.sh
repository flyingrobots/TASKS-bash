#!/usr/bin/env bash
source setup.sh
source adapters/log.sh
source adapters/llm_planner.sh

GOAL="$1"
if [ -z "$GOAL" ]; then 
    echo "Usage: ./1_architect.sh 'Your goal here'" >&2
    exit 1
fi

PROMPT_FILE="$TASKS_DIR/prompts/architect.txt"
if ! cat > "$PROMPT_FILE" <<EOF
You are the T.A.S.K.S. Architect.

CONTEXT:
- Project file tree intentionally omitted to keep the prompt light.
- If you need directory context, explicitly ask for a targeted, shallow listing rather than the whole repo.

GOAL:
$GOAL

RULES:
1. Break the goal into atomic, bounded tasks (2-4 hours estimated effort).
2. NO CYCLES in dependencies.
3. Output ONLY valid JSON. Do not include markdown fences or chatter.
4. Reference existing files from the context in your task scopes.
EOF
then
    port_log_error "Failed to write prompt file"
    exit 1
fi

port_log_info "🧠 Architect is thinking (using $LLM_PLANNER_CMD)..."

port_call_planner "$PROMPT_FILE" "Generate the execution plan." > "$TASKS_DIR/manifest/dag.json"

if [ -s "$TASKS_DIR/manifest/dag.json" ]; then
    port_log_info "✅ Plan generated at $TASKS_DIR/manifest/dag.json"
else
    port_log_error "❌ Generation failed. Check LLM configuration."
    exit 1
fi
