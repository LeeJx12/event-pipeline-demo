#!/usr/bin/env bash
set -euo pipefail

EXPECTED_ACCOUNT_ID="${AWS_ACCOUNT_ID:-821465445446}"
AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
PROJECT_NAME="${PROJECT_NAME:-event-pipeline-demo}"
ENVIRONMENT="${ENVIRONMENT:-dev}"

ACTUAL_ACCOUNT_ID="$(AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws sts get-caller-identity --query Account --output text)"

if [[ "$ACTUAL_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  echo "ERROR: Wrong AWS account."
  echo "Expected: $EXPECTED_ACCOUNT_ID"
  echo "Actual:   $ACTUAL_ACCOUNT_ID"
  exit 1
fi

echo "AWS account OK: $ACTUAL_ACCOUNT_ID"
echo "Profile: $AWS_PROFILE_NAME"
echo "Region:  $AWS_REGION_NAME"

for repo in producer consumer enrichment; do
  repo_name="${PROJECT_NAME}-${ENVIRONMENT}-${repo}"
  echo "Cleaning ECR images: ${repo_name}"

  image_ids="$(AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws ecr list-images \
    --repository-name "$repo_name" \
    --query 'imageIds' \
    --output json 2>/dev/null || echo '[]')"

  if [[ "$image_ids" != "[]" && -n "$image_ids" ]]; then
    tmp_file="$(mktemp)"
    echo "$image_ids" > "$tmp_file"
    AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws ecr batch-delete-image \
      --repository-name "$repo_name" \
      --image-ids "file://$tmp_file" >/dev/null || true
    rm -f "$tmp_file"
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TF_DIR="$REPO_ROOT/infra/terraform"

mkdir -p "$REPO_ROOT/docs"
if [[ -d "$TF_DIR" ]]; then
  cd "$TF_DIR"
  terraform output > "$REPO_ROOT/docs/aws-outputs-last.txt" 2>/dev/null || true
  AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" terraform destroy
else
  echo "ERROR: Terraform directory not found: $TF_DIR"
  exit 1
fi

echo "AWS dev environment destroyed."
echo "Next apply recreates ECR repositories, so images must be pushed again."
