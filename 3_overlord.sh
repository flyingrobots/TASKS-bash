#!/bin/bash
source setup.sh
source adapters/fs.sh
source adapters/log.sh
source lib/domain.sh

port_launch_minion() { ./4_minion.sh "$1" "$2" & }

echo "👁️  Overlord is watching. Max Workers: $MAX_WORKERS"
trap "echo 'Overlord shutting down...'; exit" SIGINT SIGTERM

while true; do
    domain_unblock_ready_tasks
    domain_spawn_next_task || true
    sleep 2
done
