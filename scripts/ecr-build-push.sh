#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-ap-northeast-2}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo dev-latest)}"
PLATFORM="${PLATFORM:-linux/amd64}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-$PROJECT_ROOT/infra/terraform}"

if ! command -v aws >/dev/null 2>&1; then
  echo "aws CLI가 필요함" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI가 필요함" >&2
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform CLI가 필요함" >&2
  exit 1
fi

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "AWS account: ${ACCOUNT_ID}"
echo "Region: ${REGION}"
echo "Image tag: ${TAG}"

authenticate_ecr() {
  aws ecr get-login-password --region "${REGION}" \
    | docker login --username AWS --password-stdin "${REGISTRY}"
}

terraform_output() {
  local key="$1"
  terraform -chdir="${TERRAFORM_DIR}" output -raw "${key}"
}

build_and_push() {
  local module="$1"
  local output_key="$2"
  local repository_url
  repository_url="$(terraform_output "${output_key}")"

  echo ""
  echo "==> Building ${module} -> ${repository_url}:${TAG}"
  docker buildx build \
    --platform "${PLATFORM}" \
    -f "${PROJECT_ROOT}/${module}/Dockerfile" \
    -t "${repository_url}:${TAG}" \
    -t "${repository_url}:${ENVIRONMENT}-latest" \
    --push \
    "${PROJECT_ROOT}"
}

authenticate_ecr
build_and_push producer producer_ecr_repository_url
build_and_push consumer consumer_ecr_repository_url
build_and_push enrichment enrichment_ecr_repository_url

echo ""
echo "Done. pushed tag=${TAG}, ${ENVIRONMENT}-latest"
