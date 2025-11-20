#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="tasks-bash-tests"

docker build -f Dockerfile.test -t "$IMAGE_NAME" .
docker run --rm "$IMAGE_NAME"
