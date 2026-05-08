#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${PROJECT_ROOT}/infra/terraform"

cd "$TF_DIR"
PRODUCER_URL="$(terraform output -raw producer_url)"

printf '\n==> Producer health\n'
curl -i "${PRODUCER_URL}/actuator/health"

printf '\n\n==> Publish one event\n'
curl -i -X POST "${PRODUCER_URL}/v1/events" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"u-1","event_type":"order.created","payload":{"amount":1000}}'

printf '\n\n==> ECS services\n'
AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws ecs describe-services \
  --cluster event-pipeline-demo-dev-cluster \
  --services event-pipeline-demo-dev-kafka event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
  --output table

printf '\n==> Consumer pods\n'
kubectl -n event-pipeline get pods -l app=event-pipeline-consumer -o wide

printf '\n==> Recent consumer logs\n'
kubectl -n event-pipeline logs deployment/event-pipeline-consumer --tail=80
