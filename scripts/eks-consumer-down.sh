#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${PROJECT_ROOT}/infra/terraform"

cd "$TF_DIR"
CLUSTER_NAME="$(terraform output -raw eks_cluster_name 2>/dev/null || true)"
if [[ -z "$CLUSTER_NAME" || "$CLUSTER_NAME" == "null" ]]; then
  echo "EKS cluster output not found. Nothing to delete from Kubernetes."
  exit 0
fi

AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION_NAME" \
  --profile "$AWS_PROFILE_NAME"

kubectl delete namespace event-pipeline --ignore-not-found=true
