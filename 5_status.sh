#!/bin/bash
# Verify setup.sh exists and source it with error checking
if [ ! -r setup.sh ]; then
    echo "Error: setup.sh not found or not readable" >&2
    exit 1
fi

if ! source setup.sh; then
    echo "Error: Failed to source setup.sh" >&2
    exit 1
fi

while true; do
    clear
    echo "============================================"
    echo "   T.A.S.K.S. OVERLORD DASHBOARD"
    echo "============================================"
    echo "   Press [CTRL+C] to exit dashboard"
    echo ""
    
    OPEN=$(ls .tasks/open/*.json 2>/dev/null | wc -l)
    BLOCKED=$(ls .tasks/blocked/*.json 2>/dev/null | wc -l)
    CLOSED=$(ls .tasks/closed/*.json 2>/dev/null | wc -l)
    DEAD=$(ls .tasks/dead/*.json 2>/dev/null | wc -l)
    CLAIMED=$(ls -d .tasks/claimed/*/ 2>/dev/null | wc -l)

    echo "🟢 OPEN (Ready):     $OPEN"
    echo "🟡 BLOCKED (Wait):   $BLOCKED"
    echo "🚀 CLAIMED (Active): $CLAIMED"
    echo "🏁 CLOSED (Done):    $CLOSED"
    echo "💀 DEAD (Failed):    $DEAD"
    
    echo ""
    echo "--- Active Workers ---"
    if [ "$CLAIMED" -eq 0 ]; then
        echo " (No active workers)"
    else
        # List worker IDs and the task they are working on
        # Enable nullglob to handle empty directories safely
        shopt -s nullglob
        for worker in .tasks/claimed/*; do
            [ -d "$worker" ] || continue
            w_id=$(basename "$worker")
            # Safely get first file without ls
            set -- "$worker"/*
            if [ ! -e "$1" ]; then
                t_id="(none)"
            else
                t_id=$(basename "$1")
            fi
            echo " 👷 $w_id -> $t_id"
        done
        shopt -u nullglob
    fi

    echo ""
    echo "--- Recent Failures (Dead) ---"
    if [ "$DEAD" -eq 0 ]; then
        echo " (None)"
    else
        # Use null-delimited pipeline to handle special characters safely
        find .tasks/dead -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null | \
            xargs -0 -n1 basename 2>/dev/null | head -n 5
    fi

    echo ""
    echo "--- Recent Logs ---"
    # Use portable sorting by mtime, avoiding fragile awk column extraction
    find .tasks/logs -maxdepth 1 -type f -name '*.log' -print0 2>/dev/null | \
        xargs -0 ls -1t 2>/dev/null | head -n 3

    sleep 2
done