#!/usr/bin/env bash
source setup.sh
source adapters/log.sh

DAG_FILE="$TASKS_DIR/manifest/dag.json"

if [ ! -s "$DAG_FILE" ]; then
    port_log_error "❌ DAG not found. Run ./1_architect.sh first."
    exit 1
fi

port_log_info "🌱 Seeding tasks from $DAG_FILE"

jq -c '.tasks[]' "$DAG_FILE" | while read -r task; do
    id=$(echo "$task" | jq -er 'select(.id | type == "string" and length > 0) | .id' 2>/dev/null || true)
    if [ -z "$id" ]; then
        port_log_error "⚠️  Skipping task with missing/invalid id: $task"
        continue
    fi

    deps_type=$(echo "$task" | jq -r '(.dependencies // []) | type' 2>/dev/null || echo "error")
    if [ "$deps_type" != "array" ]; then
        port_log_error "⚠️  Skipping $id: dependencies must be an array (got $deps_type)"
        continue
    fi

    deps_json=$(echo "$task" | jq -c '(.dependencies // [])')
    deps_count=$(echo "$deps_json" | jq 'length')

    if [ "$deps_count" -eq 0 ]; then
        target="$TASKS_DIR/open/$id.json"
    else
        target="$TASKS_DIR/blocked/$id.json"
    fi

    sanitized_task=$(echo "$task" | jq --arg id "$id" --argjson deps "$deps_json" '.id = $id | .dependencies = $deps')

    target_dir=$(dirname "$target")
    mkdir -p "$target_dir" 2>/dev/null || { port_log_error "❌ Cannot create target directory $target_dir"; exit 1; }

    tmpfile=$(mktemp "$target_dir/.tmp.${id}.XXXX") || { port_log_error "❌ Failed to create temp file for $target"; exit 1; }

    if ! printf '%s\n' "$sanitized_task" > "$tmpfile"; then
        port_log_error "❌ Failed to write task $id to $tmpfile"
        rm -f "$tmpfile"
        exit 1
    fi

    if ! mv "$tmpfile" "$target"; then
        port_log_error "❌ Failed to place task $id at $target"
        rm -f "$tmpfile"
        exit 1
    fi

    port_log_info "Seeded $id -> $(basename "$(dirname "$target")")"
done

port_log_info "✅ Seeding complete"
