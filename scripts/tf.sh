#!/usr/bin/env bash
set -euo pipefail

# Safe Terraform wrapper. Always checks AWS account before running terraform.

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
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" terraform "$@"
