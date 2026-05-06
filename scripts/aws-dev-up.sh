#!/usr/bin/env bash
set -euo pipefail

# Bring up AWS dev env safely.
# terraform destroy deletes ECR repos/images.
# After every fresh terraform apply, push images again.

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

echo
echo "==> Terraform apply"
cd "${TF_DIR}"
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" terraform init
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" terraform apply

echo
echo "==> Push Docker images to ECR"
cd "${ROOT_DIR}"
export AWS_PROFILE="${AWS_PROFILE_NAME}"
export AWS_REGION="${AWS_REGION_NAME}"
export IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD)}"
./scripts/ecr-build-push.sh

echo
echo "==> Force ECS redeploy"
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" \
aws ecs update-service \
  --cluster event-pipeline-demo-dev-cluster \
  --service event-pipeline-demo-dev-producer \
  --force-new-deployment >/dev/null

AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" \
aws ecs update-service \
  --cluster event-pipeline-demo-dev-cluster \
  --service event-pipeline-demo-dev-enrichment \
  --force-new-deployment >/dev/null

echo
echo "==> ECS service status"
AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" \
aws ecs describe-services \
  --cluster event-pipeline-demo-dev-cluster \
  --services event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
  --output table

echo
echo "==> ALB health check"
cd "${TF_DIR}"
producer_url="$(AWS_PROFILE="${AWS_PROFILE_NAME}" AWS_REGION="${AWS_REGION_NAME}" terraform output -raw producer_url)"
echo "Producer URL: ${producer_url}"
curl -i "${producer_url}/actuator/health" || true

echo
echo "AWS dev environment up routine finished."
