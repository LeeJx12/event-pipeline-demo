#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
K8S_NAMESPACE="${K8S_NAMESPACE:-event-pipeline}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"
EVIDENCE_DIR="${EVIDENCE_DIR:-$ROOT_DIR/docs/evidence/w4/$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$EVIDENCE_DIR"

echo "Capturing to $EVIDENCE_DIR"

aws ecs describe-services \
  --cluster event-pipeline-demo-dev-cluster \
  --services event-pipeline-demo-dev-kafka event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
  --output table \
  --profile "$AWS_PROFILE_NAME" \
  --region "$AWS_REGION_NAME" > "$EVIDENCE_DIR/ecs-services.txt" || true

kubectl get pods -n "$K8S_NAMESPACE" -o wide > "$EVIDENCE_DIR/eks-consumer-pods.txt" || true
kubectl top pods -n "$K8S_NAMESPACE" > "$EVIDENCE_DIR/eks-consumer-top-pods.txt" 2>&1 || true
kubectl logs -n "$K8S_NAMESPACE" deploy/event-pipeline-consumer --tail=300 > "$EVIDENCE_DIR/consumer.log" || true

aws logs tail /ecs/event-pipeline-demo-dev/producer --since 30m --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME" > "$EVIDENCE_DIR/producer.log" 2>&1 || true
aws logs tail /ecs/event-pipeline-demo-dev/enrichment --since 30m --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME" > "$EVIDENCE_DIR/enrichment.log" 2>&1 || true
aws logs tail /ecs/event-pipeline-demo-dev/kafka --since 30m --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME" > "$EVIDENCE_DIR/kafka.log" 2>&1 || true

(cd "$TF_DIR" && terraform output) > "$EVIDENCE_DIR/terraform-output.txt" || true

echo "Done: $EVIDENCE_DIR"
