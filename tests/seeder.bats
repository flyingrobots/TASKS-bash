#!/usr/bin/env bats

setup() {
  PROJECT_ROOT="$(pwd)"
  TEST_TMP="$(mktemp -d)"
  cp "$PROJECT_ROOT/2_seeder.sh" "$PROJECT_ROOT/setup.sh" "$TEST_TMP/"
  mkdir -p "$TEST_TMP/adapters"
  cp "$PROJECT_ROOT/adapters/log.sh" "$TEST_TMP/adapters/"
  mkdir -p "$TEST_TMP/.tasks/manifest"
  cd "$TEST_TMP"
}

teardown() { rm -rf "$TEST_TMP"; }

@test "seeder splits DAG into open and blocked tasks" {
  cat > ./.tasks/manifest/dag.json <<'JSON'
{
  "tasks": [
    {"id":"task_a","dependencies":[],"description":"ready"},
    {"id":"task_b","dependencies":["task_a"],"description":"wait"}
  ]
}
JSON

  run bash ./2_seeder.sh
  [ "$status" -eq 0 ]

  [ -f .tasks/open/task_a.json ]
  [ -f .tasks/blocked/task_b.json ]
}
