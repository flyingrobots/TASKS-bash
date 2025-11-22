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
    errors=0
    for f in "${files[@]}"; do
        if [ ! -e "$f" ]; then
            echo "Skip missing file: $f" >&2
            continue
        fi
        if ! mv -- "$f" .tasks/open/; then
            echo "Error: Failed to move $f to .tasks/open/" >&2
            errors=$((errors+1))
        fi
    done
    if [ "$errors" -ne 0 ]; then
        echo "Failed to revive $errors task(s)" >&2
        exit 1
    fi
    echo "✨ Tasks revived. The Overlord will retry them shortly."
fi
