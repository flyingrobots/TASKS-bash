#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="tasks-bash-tests"

# Preflight checks: verify docker is available
if ! command -v docker &>/dev/null; then
  echo "Error: docker command not found. Please install Docker." >&2
  exit 1
fi

# Verify docker daemon is accessible
if ! docker info &>/dev/null; then
  echo "Error: Cannot connect to Docker daemon. Is Docker running?" >&2
  exit 1
fi

# Build the test image
echo "Building test image..."
if ! docker build -f Dockerfile.test -t "$IMAGE_NAME" .; then
  echo "Error: docker build failed" >&2
  exit 1
fi

# Run the tests
echo "Running tests..."
if ! docker run --rm "$IMAGE_NAME"; then
  echo "Error: docker run failed" >&2
  exit 1
fi

echo "✅ All tests passed successfully!"
