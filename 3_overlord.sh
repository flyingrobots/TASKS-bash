#!/bin/bash
source setup.sh
source adapters/fs.sh
source adapters/log.sh
source adapters/control.sh
source lib/domain.sh

port_launch_minion() {
    mkdir -p "$TASKS_DIR/pids"
    ./4_minion.sh "$1" "$2" &
    echo $! >"$TASKS_DIR/pids/$1.pid"
}

echo "👁️  Overlord is watching. Max Workers: $MAX_WORKERS"
trap "echo 'Overlord shutting down...'; exit" SIGINT SIGTERM

SLEEP_SECONDS=${SLEEP_SECONDS:-2}

tick=0
while port_should_continue "$tick"; do
    domain_unblock_ready_tasks
    domain_spawn_next_task || true

    # Reap finished minions to prevent zombies
    while wait -n 2>/dev/null; do :; done

    tick=$((tick+1))

    sleep "$SLEEP_SECONDS"
done
