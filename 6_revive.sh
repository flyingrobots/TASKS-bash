#!/usr/bin/env bash
source setup.sh

# Use bash array to safely count files (handles newlines/spaces)
shopt -s nullglob
files=(.tasks/dead/*.json)
shopt -u nullglob

count=${#files[@]}

if [ "$count" -eq 0 ]; then
    echo "No dead tasks to revive."
    exit 0
fi

echo "Found $count dead tasks."
# Use null-delimited pipeline to safely list filenames
find .tasks/dead -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null | \
    xargs -0 -n1 basename 2>/dev/null
echo ""
read -p "Revive all to 'open'? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Verify files exist and move them, checking for errors
    if [ "${#files[@]}" -eq 0 ]; then
        echo "Error: No files to move" >&2
        exit 1
    fi

    if mv .tasks/dead/*.json .tasks/open/; then
        echo "✨ Tasks revived. The Overlord will retry them shortly."
    else
        echo "Error: Failed to revive tasks" >&2
        exit 1
    fi
fi