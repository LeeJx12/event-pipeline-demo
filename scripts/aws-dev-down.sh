#!/usr/bin/env bash
set -euo pipefail

# Tear down AWS dev env safely.
# Destroys RDS, Redis, ECS, ALB, VPC, ECR repos, and ECR images.

EXPECTED_ACCOUNT_ID="${EXPECTED_AWS_ACCOUNT_ID:-821465445446}"
AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/infra/terraform"

actual_account_id="$(
  AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" \
  aws sts get-caller-identity --query Account --output text
)"

if [[ "${actual_account_id}" != "${EXPECTED_ACCOUNT_ID}" ]]; then
  echo "ERROR: wrong AWS account"
  echo "expected: ${EXPECTED_ACCOUNT_ID}"
  echo "actual:   ${actual_account_id}"
  exit 1
fi

echo "AWS account OK: ${actual_account_id}"
echo "Profile: ${AWS_PROFILE_NAME}"
echo "Region: ${AWS_REGION_NAME}"

cd "${TF_DIR}"

echo
echo "==> Save latest Terraform outputs"
mkdir -p "${ROOT_DIR}/docs"
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" \
terraform output > "${ROOT_DIR}/docs/aws-outputs-last.txt" || true

echo
echo "==> Terraform destroy"
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" terraform destroy

echo
echo "AWS dev environment destroyed."
echo "Reminder: next terraform apply recreates empty ECR repos, so run ./scripts/ecr-build-push.sh or ./scripts/aws-dev-up.sh."
