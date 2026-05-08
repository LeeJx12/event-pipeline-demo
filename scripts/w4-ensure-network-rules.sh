#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
VPC_CIDR="${VPC_CIDR:-10.20.0.0/16}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"

if [ ! -d "$TF_DIR" ]; then
  echo "ERROR: Terraform directory not found: $TF_DIR" >&2
  exit 1
fi

ECS_SG_ID="$(cd "$TF_DIR" && terraform output -raw ecs_service_security_group_id)"

add_rule() {
  local port="$1"
  local desc="$2"
  echo "Ensuring ECS SG ingress: ${VPC_CIDR} -> ${ECS_SG_ID}:${port} (${desc})"
  set +e
  aws ec2 authorize-security-group-ingress \
    --group-id "$ECS_SG_ID" \
    --protocol tcp \
    --port "$port" \
    --cidr "$VPC_CIDR" \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION_NAME" >/tmp/w4-sg-rule.out 2>/tmp/w4-sg-rule.err
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    if grep -q "InvalidPermission.Duplicate" /tmp/w4-sg-rule.err; then
      echo "Already exists: ${port}"
    else
      cat /tmp/w4-sg-rule.err >&2
      exit "$rc"
    fi
  else
    echo "Added: ${port}"
  fi
}

add_rule 9090 "EKS consumer to ECS enrichment gRPC"
add_rule 9092 "EKS consumer to ECS Kafka"
