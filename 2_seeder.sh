#!/bin/bash
source setup.sh
source adapters/log.sh

DAG_FILE="$TASKS_DIR/manifest/dag.json"

if [ ! -s "$DAG_FILE" ]; then
    port_log_error "❌ DAG not found. Run ./1_architect.sh first."
    exit 1
fi

port_log_info "🌱 Seeding tasks from $DAG_FILE"

jq -c '.tasks[]' "$DAG_FILE" | while read -r task; do
    id=$(echo "$task" | jq -r '.id')
    deps_count=$(echo "$task" | jq '.dependencies | length')

    if [ "$deps_count" -eq 0 ]; then
        target="$TASKS_DIR/open/$id.json"
    else
        target="$TASKS_DIR/blocked/$id.json"
    fi

    echo "$task" > "$target"
    port_log_info "Seeded $id -> $(basename $(dirname "$target"))"
done

port_log_info "✅ Seeding complete"
