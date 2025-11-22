#!/usr/bin/env bash
source setup.sh
source adapters/log.sh
source adapters/llm_planner.sh
source lib/tasks/architect.sh

tasks_architect "$@"
