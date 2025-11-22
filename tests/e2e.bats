#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
  if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Error: PROJECT_ROOT is not a directory: $PROJECT_ROOT" >&2
    return 1
  fi

  tmpdir=$(mktemp -d -t e2e_test.XXXXXX)
  mkdir -p "$tmpdir/repo"

  # Simple, readable copy with excludes using tar
  tar -C "$PROJECT_ROOT" \
      --exclude='.git' --exclude='node_modules' --exclude='.tasks' \
      -cpf - . | tar -C "$tmpdir/repo" -xpf - || { echo "Failed to copy repo" >&2; return 1; }

  cd "$tmpdir/repo" || { echo "Failed to enter $tmpdir/repo" >&2; return 1; }
}

teardown() {
  if [ -n "$tmpdir" ] && [ -d "$tmpdir" ]; then
    pwd_cur=$(pwd)
    case "$pwd_cur" in
      "$tmpdir"* )
        cd / || { echo "Warning: Could not leave $tmpdir" >&2; return 1; }
        ;;
    esac
    rm -rf "$tmpdir" || { echo "Warning: Failed to remove $tmpdir" >&2; return 1; }
  fi
}

@test "architect -> seeder -> overlord produces markdown previewer" {
  export TASKS_LLM_PLANNER_CMD="tests/fixtures/fake_planner.sh"
  export TASKS_LLM_WORKER_CMD_JSON='["tests/fixtures/fake_worker.sh"]'
  export TASKS_OVERLORD_TICKS=20
  export TASKS_MAX_WORKERS=3
  export TASKS_SLEEP_SECONDS=0

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
  run grep -q "<html" public/index.html
  [ "$status" -eq 0 ]

  [ -f tests/preview.bats ]
  run bats tests/preview.bats
  [ "$status" -eq 0 ]

  log_count=$(find .tasks/logs -name '*.log' -type f 2>/dev/null | wc -l)
  [ "$log_count" -ge 4 ]
  run grep -q "Watch mode" README.md
  [ "$status" -eq 0 ]
}
