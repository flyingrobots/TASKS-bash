#!/usr/bin/env bash
# Deterministic planner stub: ignores input and emits a fixed DAG
cat <<'JSON'
{"tasks":[
 {"dependencies":[],"description":"Create project skeleton: app/, tests/, README stub","id":"bootstrap"},
 {"dependencies":["bootstrap"],"description":"Add app/preview.sh to convert README.md to public/index.html using pandoc if present, otherwise a minimal sed/awk fallback; add bats tests","id":"parser"},
 {"dependencies":["parser"],"description":"Add --watch flag that rebuilds on change using inotifywait/fswatch fallback","id":"watch"},
 {"dependencies":["watch"],"description":"Add Makefile targets build/test and update README usage section","id":"packaging"}
]}
JSON
