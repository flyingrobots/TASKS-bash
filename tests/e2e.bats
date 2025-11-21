#!/usr/bin/env bats

setup() {
  tmpdir=$(mktemp -d)
  cp -R . "$tmpdir/repo"
  cd "$tmpdir/repo"
}

teardown() {
  cd /tmp || true
  rm -rf "$tmpdir"
}

@test "architect -> seeder -> overlord produces markdown previewer" {
  export LLM_PLANNER_CMD="tests/fixtures/fake_planner.sh"
  export LLM_WORKER_CMD="tests/fixtures/fake_worker.sh"
  export OVERLORD_TICKS=20
  export MAX_WORKERS=3
  export SLEEP_SECONDS=0

  run ./setup.sh
  [ "$status" -eq 0 ]

  run ./1_architect.sh "Build a Markdown previewer CLI with watch mode and tests"
  [ "$status" -eq 0 ]

  run ./2_seeder.sh
  [ "$status" -eq 0 ]

  run ./3_overlord.sh
  [ "$status" -eq 0 ]

  # All tasks should have closed, none dead
  closed_count=$(ls .tasks/closed/*.json 2>/dev/null | wc -l)
  [ "$closed_count" -eq 4 ]
  dead_count=$(ls .tasks/dead/*.json 2>/dev/null | wc -l)
  [ "$dead_count" -eq 0 ]

  # Artifacts exist and basic behavior works
  [ -x app/preview.sh ]
  run app/preview.sh README.md public/index.html
  [ "$status" -eq 0 ]
  grep "<html" public/index.html

  [ -f tests/preview.bats ]
  run bats tests/preview.bats
  [ "$status" -eq 0 ]

  grep -q "build:" Makefile
  grep -q "test:" Makefile
  grep -q "Watch mode" README.md

  log_count=$(ls .tasks/logs/*.log 2>/dev/null | wc -l)
  [ "$log_count" -ge 4 ]
}
