#!/usr/bin/env bash
set -euo pipefail

AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
NAMESPACE="${NAMESPACE:-event-pipeline}"
DEPLOYMENT="${DEPLOYMENT:-event-pipeline-consumer}"
CLUSTER_NAME="${ECS_CLUSTER_NAME:-event-pipeline-demo-dev-cluster}"
TAIL_LINES="${TAIL_LINES:-2000}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"
TS="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${EVIDENCE_DIR:-$ROOT_DIR/docs/evidence/w4/$TS}"

mkdir -p \
  "$OUT_DIR/00-run-summary" \
  "$OUT_DIR/03-blog-captures" \
  "$OUT_DIR/04-raw-logs/consumer-pods" \
  "$OUT_DIR/05-db" \
  "$OUT_DIR/06-kafka" \
  "$OUT_DIR/07-k8s" \
  "$OUT_DIR/08-ecs" \
  "$OUT_DIR/09-alb"

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

run_capture() {
  local label="$1"
  local output="$2"
  shift 2
  log "CAPTURE: $label -> ${output#$ROOT_DIR/}"
  set +e
  "$@" > "$output" 2>&1
  local code=$?
  set -e
  if [ "$code" -ne 0 ]; then
    echo "[capture failed] exit_code=$code" >> "$output"
  fi
}

cd "$ROOT_DIR"

log "Evidence dir: $OUT_DIR"

# Terraform outputs / ALB health
if [ -d "$TF_DIR" ]; then
  run_capture "Terraform outputs" "$OUT_DIR/00-run-summary/terraform-outputs.txt" \
    bash -lc "cd '$TF_DIR' && terraform output"

  PRODUCER_URL="$(cd "$TF_DIR" && terraform output -raw producer_url 2>/dev/null || true)"
  if [ -n "$PRODUCER_URL" ]; then
    run_capture "Producer ALB health" "$OUT_DIR/09-alb/producer-health.txt" \
      curl -i --max-time 10 "$PRODUCER_URL/actuator/health"
  else
    echo "producer_url terraform output not found" > "$OUT_DIR/09-alb/producer-health.txt"
  fi
else
  echo "terraform dir not found: $TF_DIR" > "$OUT_DIR/00-run-summary/terraform-outputs.txt"
fi

# ECS state/logs
run_capture "ECS services" "$OUT_DIR/08-ecs/services.txt" \
  aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services event-pipeline-demo-dev-kafka event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
    --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status,taskDefinition:taskDefinition}' \
    --output table \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION_NAME"

run_capture "Producer ECS logs" "$OUT_DIR/08-ecs/producer.log" \
  aws logs tail /ecs/event-pipeline-demo-dev/producer --since 30m \
    --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME"

run_capture "Kafka ECS logs" "$OUT_DIR/08-ecs/kafka.log" \
  aws logs tail /ecs/event-pipeline-demo-dev/kafka --since 30m \
    --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME"

run_capture "Enrichment ECS logs" "$OUT_DIR/08-ecs/enrichment.log" \
  aws logs tail /ecs/event-pipeline-demo-dev/enrichment --since 30m \
    --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME"

# Kubernetes state
run_capture "K8s nodes" "$OUT_DIR/07-k8s/nodes.txt" \
  kubectl get nodes -o wide

run_capture "Consumer pods" "$OUT_DIR/07-k8s/consumer-pods.txt" \
  kubectl get pods -n "$NAMESPACE" -o wide
cp "$OUT_DIR/07-k8s/consumer-pods.txt" "$OUT_DIR/03-blog-captures/consumer-pods.txt" || true

run_capture "Consumer deployment" "$OUT_DIR/07-k8s/consumer-deployment.txt" \
  kubectl describe deploy "$DEPLOYMENT" -n "$NAMESPACE"

run_capture "K8s recent events" "$OUT_DIR/07-k8s/events.txt" \
  kubectl get events -n "$NAMESPACE" --sort-by=.metadata.creationTimestamp

# Consumer logs: deployment + pod by pod
run_capture "Consumer deployment logs" "$OUT_DIR/04-raw-logs/consumer-all.log" \
  kubectl logs -n "$NAMESPACE" "deploy/$DEPLOYMENT" --tail="$TAIL_LINES" --all-containers=true

PODS="$(kubectl get pods -n "$NAMESPACE" -l app=event-pipeline-consumer -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
if [ -z "$PODS" ]; then
  PODS="$(kubectl get pods -n "$NAMESPACE" -o name 2>/dev/null | grep consumer | sed 's#pod/##' || true)"
fi

for pod in $PODS; do
  run_capture "Consumer pod log $pod" "$OUT_DIR/04-raw-logs/consumer-pods/$pod.log" \
    kubectl logs -n "$NAMESPACE" "$pod" --tail="$TAIL_LINES" --all-containers=true
 done

CONSUMER_ALL="$OUT_DIR/04-raw-logs/consumer-all.log"

grep -E "Enriched event" "$CONSUMER_ALL" > "$OUT_DIR/03-blog-captures/01-enriched-events.log" || true
grep -E "cacheHit=true" "$CONSUMER_ALL" > "$OUT_DIR/03-blog-captures/02-cache-hit-true.log" || true
grep -E "cacheHit=false" "$CONSUMER_ALL" > "$OUT_DIR/03-blog-captures/03-cache-hit-false.log" || true
grep -E "Persisted processed events batch" "$CONSUMER_ALL" > "$OUT_DIR/03-blog-captures/04-db-persist-batches.log" || true
grep -Ei "ERROR|WARN|degraded|failed|timeout|Exception" "$CONSUMER_ALL" > "$OUT_DIR/03-blog-captures/05-errors-warnings-degraded.log" || true
grep -E "partition=.*offset=|partition=[0-9]+ offset=[0-9]+" "$CONSUMER_ALL" > "$OUT_DIR/03-blog-captures/06-partition-offsets.log" || true

# Kafka lag via kafka container in ECS if possible
KAFKA_TASK_ARN="$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name event-pipeline-demo-dev-kafka \
  --desired-status RUNNING \
  --query 'taskArns[0]' \
  --output text \
  --profile "$AWS_PROFILE_NAME" \
  --region "$AWS_REGION_NAME" 2>/dev/null || true)"

if [ -n "$KAFKA_TASK_ARN" ] && [ "$KAFKA_TASK_ARN" != "None" ]; then
  run_capture "Kafka consumer lag" "$OUT_DIR/06-kafka/consumer-lag.txt" \
    aws ecs execute-command \
      --cluster "$CLUSTER_NAME" \
      --task "$KAFKA_TASK_ARN" \
      --container kafka \
      --interactive \
      --command "/bin/bash -lc 'kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group event-pipeline-consumer || true'" \
      --profile "$AWS_PROFILE_NAME" \
      --region "$AWS_REGION_NAME"
else
  echo "No running kafka task found" > "$OUT_DIR/06-kafka/consumer-lag.txt"
fi
cp "$OUT_DIR/06-kafka/consumer-lag.txt" "$OUT_DIR/03-blog-captures/consumer-lag.txt" || true

# RDS count via psql if DB_PASSWORD exists. Otherwise store instruction.
RDS_ENDPOINT=""
if [ -d "$TF_DIR" ]; then
  RDS_ENDPOINT="$(cd "$TF_DIR" && terraform output -raw rds_endpoint 2>/dev/null || true)"
fi

if [ -n "${DB_PASSWORD:-}" ] && [ -n "$RDS_ENDPOINT" ] && command -v psql >/dev/null 2>&1; then
  run_capture "RDS events_processed count" "$OUT_DIR/05-db/events-processed-count.txt" \
    psql "postgresql://pipeline:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/pipeline?sslmode=require" \
      -c "select count(*) as events_processed_count from events_processed; select event_id, user_id, event_type, enrichment_country, enrichment_tier, enrichment_cache_hit, processed_at from events_processed order by processed_at desc limit 10;"
elif [ -n "${DB_PASSWORD:-}" ] && [ -n "$RDS_ENDPOINT" ]; then
  echo "psql not found. Install psql or run manually:" > "$OUT_DIR/05-db/events-processed-count.txt"
  echo "psql 'postgresql://pipeline:<DB_PASSWORD>@${RDS_ENDPOINT}:5432/pipeline?sslmode=require' -c 'select count(*) from events_processed;'" >> "$OUT_DIR/05-db/events-processed-count.txt"
else
  echo "DB_PASSWORD or rds_endpoint missing. Set DB_PASSWORD and rerun for DB count." > "$OUT_DIR/05-db/events-processed-count.txt"
fi
cp "$OUT_DIR/05-db/events-processed-count.txt" "$OUT_DIR/03-blog-captures/rds-events-processed-count.txt" || true

# Summary
cat > "$OUT_DIR/00-run-summary/README.md" <<SUMMARY
# W4 Evidence Capture

Captured at: $TS
Namespace: $NAMESPACE
Deployment: $DEPLOYMENT
ECS cluster: $CLUSTER_NAME
Tail lines: $TAIL_LINES

## Blog-ready files

- 03-blog-captures/consumer-pods.txt
- 03-blog-captures/consumer-lag.txt
- 03-blog-captures/rds-events-processed-count.txt
- 03-blog-captures/01-enriched-events.log
- 03-blog-captures/02-cache-hit-true.log
- 03-blog-captures/03-cache-hit-false.log
- 03-blog-captures/04-db-persist-batches.log
- 03-blog-captures/05-errors-warnings-degraded.log
- 03-blog-captures/06-partition-offsets.log
- 09-alb/producer-health.txt
- 08-ecs/services.txt

## Raw logs

- 04-raw-logs/consumer-all.log
- 04-raw-logs/consumer-pods/*.log
- 08-ecs/*.log
SUMMARY

log "Evidence captured: $OUT_DIR"
log "Blog-ready: $OUT_DIR/03-blog-captures"
