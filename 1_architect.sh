#!/usr/bin/env bash
source setup.sh
source adapters/log.sh
source adapters/llm_planner.sh

GOAL="$1"
if [ -z "$GOAL" ]; then 
    echo "Usage: ./1_architect.sh 'Your goal here'"
    exit 1
fi

echo "👀 Scanning project structure..."
PROJECT_STRUCTURE=$(find . -maxdepth 4 -not -path '*/.*' -not -path './.tasks*' | sed 's/^/  /')

PROMPT_FILE="$TASKS_DIR/prompts/architect.txt"
cat > "$PROMPT_FILE" <<EOF
You are the T.A.S.K.S. Architect.

CONTEXT:
The user is working in a codebase with this structure:
$PROJECT_STRUCTURE

GOAL:
$GOAL

RULES:
1. Break the goal into atomic, bounded tasks (2-4 hours estimated effort).
2. NO CYCLES in dependencies.
3. Output ONLY valid JSON. Do not include markdown fences or chatter.
4. Reference existing files from the context in your task scopes.
EOF

port_log_info "🧠 Architect is thinking (using $LLM_PLANNER_CMD)..."

port_call_planner "$PROMPT_FILE" "Generate the execution plan." > "$TASKS_DIR/manifest/dag.json"

if [ -s "$TASKS_DIR/manifest/dag.json" ]; then
    port_log_info "✅ Plan generated at $TASKS_DIR/manifest/dag.json"
else
    port_log_error "❌ Generation failed. Check LLM configuration."
    exit 1
fi
