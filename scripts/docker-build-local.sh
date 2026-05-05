#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${IMAGE_TAG:-local}"
PLATFORM="${PLATFORM:-linux/amd64}"

for module in producer consumer enrichment; do
  echo "==> Building ${module}:${TAG}"
  docker buildx build \
    --platform "${PLATFORM}" \
    -f "${PROJECT_ROOT}/${module}/Dockerfile" \
    -t "event-pipeline-demo/${module}:${TAG}" \
    --load \
    "${PROJECT_ROOT}"
done
