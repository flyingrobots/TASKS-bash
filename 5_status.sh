#!/bin/bash
source setup.sh

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
        for worker in .tasks/claimed/*; do
            [ -d "$worker" ] || continue
            w_id=$(basename "$worker")
            # Use head to ensure we just get one file name if weirdness happens
            t_id=$(ls "$worker" | head -n 1)
            echo " 👷 $w_id -> $t_id"
        done
    fi

    echo ""
    echo "--- Recent Failures (Dead) ---"
    if [ "$DEAD" -eq 0 ]; then
        echo " (None)"
    else
        ls .tasks/dead/*.json 2>/dev/null | xargs -n 1 basename | head -n 5
    fi

    echo ""
    echo "--- Recent Logs ---"
    ls -lt .tasks/logs/*.log 2>/dev/null | head -n 3 | awk '{print $9}'

    sleep 2
done