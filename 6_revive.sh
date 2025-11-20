#!/bin/bash
source setup.sh

count=$(ls .tasks/dead/*.json 2>/dev/null | wc -l)

if [ "$count" -eq 0 ]; then
    echo "No dead tasks to revive."
    exit 0
fi

echo "Found $count dead tasks."
ls .tasks/dead/*.json | xargs -n 1 basename
echo ""
read -p "Revive all to 'open'? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    mv .tasks/dead/*.json .tasks/open/
    echo "✨ Tasks revived. The Overlord will retry them shortly."
fi