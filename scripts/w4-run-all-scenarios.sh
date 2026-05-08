#!/usr/bin/env bash
set -euo pipefail

# W4 full load-test runner.
# Runs all scenarios sequentially and stores blog-ready evidence under docs/evidence/w4/<run-id>/.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
NAMESPACE="${K8S_NAMESPACE:-event-pipeline}"
DEPLOYMENT="${CONSUMER_DEPLOYMENT:-event-pipeline-consumer}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="docs/evidence/w4/${RUN_ID}"
DB_PASSWORD="${DB_PASSWORD:-}"
TAIL_LINES="${TAIL_LINES:-3000}"

EXPECTED_ACCOUNT_ID="${EXPECTED_AWS_ACCOUNT_ID:-821465445446}"
ACTUAL_ACCOUNT_ID="$(AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws sts get-caller-identity --query Account --output text)"
if [[ "$ACTUAL_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  echo "ERROR: wrong AWS account. expected=$EXPECTED_ACCOUNT_ID actual=$ACTUAL_ACCOUNT_ID" >&2
  exit 1
fi

mkdir -p \
  "$OUT_DIR/00-run-summary" \
  "$OUT_DIR/01-architecture-state" \
  "$OUT_DIR/02-scenarios" \
  "$OUT_DIR/03-blog-captures" \
  "$OUT_DIR/04-raw-logs" \
  "$OUT_DIR/05-db" \
  "$OUT_DIR/06-kafka" \
  "$OUT_DIR/07-k8s" \
  "$OUT_DIR/08-ecs" \
  "$OUT_DIR/09-alb"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$OUT_DIR/00-run-summary/run.log"; }

run_cmd() {
  local title="$1"; shift
  local file="$1"; shift
  log "CAPTURE: $title -> $file"
  {
    echo "# $title"
    echo "# captured_at=$(date -Is)"
    echo "# command=$*"
    echo
    "$@"
  } > "$file" 2>&1 || true
}

producer_url() {
  (cd infra/terraform && terraform output -raw producer_url)
}

rds_endpoint() {
  (cd infra/terraform && terraform output -raw rds_endpoint)
}

capture_baseline() {
  log "Capturing baseline architecture state"
  local url
  url="$(producer_url)"
  echo "$url" > "$OUT_DIR/00-run-summary/producer-url.txt"

  run_cmd "ALB producer health" "$OUT_DIR/09-alb/producer-health.txt" \
    curl -i "$url/actuator/health"

  run_cmd "ECS services state" "$OUT_DIR/08-ecs/services.txt" \
    aws ecs describe-services \
      --cluster event-pipeline-demo-dev-cluster \
      --services event-pipeline-demo-dev-kafka event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
      --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
      --output table \
      --profile "$AWS_PROFILE_NAME" \
      --region "$AWS_REGION_NAME"

  run_cmd "EKS consumer pods" "$OUT_DIR/07-k8s/consumer-pods.txt" \
    kubectl get pods -n "$NAMESPACE" -o wide

  run_cmd "EKS consumer deployment" "$OUT_DIR/07-k8s/consumer-deployment.txt" \
    kubectl describe deploy "$DEPLOYMENT" -n "$NAMESPACE"

  run_cmd "Kubernetes recent events" "$OUT_DIR/07-k8s/events.txt" \
    kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp
}

capture_logs() {
  local scenario_dir="$1"
  mkdir -p "$scenario_dir/blog-ready" "$scenario_dir/raw/consumer-pods" "$scenario_dir/raw/ecs"

  run_cmd "Consumer pods after scenario" "$scenario_dir/blog-ready/consumer-pods.txt" \
    kubectl get pods -n "$NAMESPACE" -o wide

  run_cmd "ECS service state after scenario" "$scenario_dir/blog-ready/ecs-services.txt" \
    aws ecs describe-services \
      --cluster event-pipeline-demo-dev-cluster \
      --services event-pipeline-demo-dev-kafka event-pipeline-demo-dev-producer event-pipeline-demo-dev-enrichment \
      --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
      --output table \
      --profile "$AWS_PROFILE_NAME" \
      --region "$AWS_REGION_NAME"

  run_cmd "Consumer deployment logs" "$scenario_dir/raw/consumer-all.log" \
    kubectl logs -n "$NAMESPACE" deploy/"$DEPLOYMENT" --tail="$TAIL_LINES"

  # Pod-by-pod logs are more useful when replicas > 1.
  for pod in $(kubectl get pods -n "$NAMESPACE" -l app=event-pipeline-consumer -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true); do
    run_cmd "Consumer pod log $pod" "$scenario_dir/raw/consumer-pods/${pod}.log" \
      kubectl logs -n "$NAMESPACE" "$pod" --tail="$TAIL_LINES"
  done

  local all_log="$scenario_dir/raw/consumer-all.log"
  grep -E "Enriched event" "$all_log" > "$scenario_dir/blog-ready/01-enriched-events.log" || true
  grep -E "cacheHit=true" "$all_log" > "$scenario_dir/blog-ready/02-cache-hit-true.log" || true
  grep -E "cacheHit=false" "$all_log" > "$scenario_dir/blog-ready/03-cache-hit-false.log" || true
  grep -E "Persisted processed events batch" "$all_log" > "$scenario_dir/blog-ready/04-db-persist-batches.log" || true
  grep -E "degraded|ERROR|WARN|Failed" "$all_log" > "$scenario_dir/blog-ready/05-errors-warnings-degraded.log" || true
  grep -E "partition=.*offset=" "$all_log" > "$scenario_dir/blog-ready/06-partition-offsets.log" || true

  run_cmd "Kafka consumer lag" "$scenario_dir/blog-ready/consumer-lag.txt" \
    bash scripts/w4-consumer-lag.sh

  run_cmd "RDS events_processed count" "$scenario_dir/blog-ready/rds-events-processed-count.txt" \
    bash scripts/w4-rds-count.sh

  run_cmd "Producer ECS logs" "$scenario_dir/raw/ecs/producer.log" \
    aws logs tail /ecs/event-pipeline-demo-dev/producer --since 20m \
      --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME"

  run_cmd "Kafka ECS logs" "$scenario_dir/raw/ecs/kafka.log" \
    aws logs tail /ecs/event-pipeline-demo-dev/kafka --since 20m \
      --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME"

  run_cmd "Enrichment ECS logs" "$scenario_dir/raw/ecs/enrichment.log" \
    aws logs tail /ecs/event-pipeline-demo-dev/enrichment --since 20m \
      --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION_NAME"
}

scale_consumer() {
  local replicas="$1"
  log "Scaling consumer to replicas=$replicas"
  bash scripts/w4-scale-consumer.sh "$replicas" | tee -a "$OUT_DIR/00-run-summary/run.log"
  kubectl rollout status deploy/"$DEPLOYMENT" -n "$NAMESPACE" | tee -a "$OUT_DIR/00-run-summary/run.log"
  sleep 10
}

run_load() {
  local name="$1"
  local replicas="$2"
  local s1_rate="$3"
  local s1_duration="$4"
  local s2_rate="$5"
  local s2_duration="$6"
  local s3_rate="$7"
  local s3_duration="$8"
  local max_vus="$9"

  local scenario_dir="$OUT_DIR/02-scenarios/${name}"
  mkdir -p "$scenario_dir/blog-ready" "$scenario_dir/raw"

  log "Scenario START: $name replicas=$replicas rates=$s1_rate/$s2_rate/$s3_rate"
  scale_consumer "$replicas"

  {
    echo "scenario=$name"
    echo "consumer_replicas=$replicas"
    echo "stage1=${s1_rate}rps/${s1_duration}"
    echo "stage2=${s2_rate}rps/${s2_duration}"
    echo "stage3=${s3_rate}rps/${s3_duration}"
    echo "max_vus=$max_vus"
    echo "started_at=$(date -Is)"
  } > "$scenario_dir/scenario-info.txt"

  log "Running k6 for scenario=$name"
  STAGE1_RATE="$s1_rate" STAGE1_DURATION="$s1_duration" \
  STAGE2_RATE="$s2_rate" STAGE2_DURATION="$s2_duration" \
  STAGE3_RATE="$s3_rate" STAGE3_DURATION="$s3_duration" \
  MAX_VUS="$max_vus" \
  K6_SUMMARY_EXPORT="$scenario_dir/raw/k6-summary.json" \
  bash scripts/w4-load-test.sh 2>&1 | tee "$scenario_dir/blog-ready/k6-summary.txt"

  echo "finished_at=$(date -Is)" >> "$scenario_dir/scenario-info.txt"

  log "Waiting 30s for consumer drain"
  sleep 30

  capture_logs "$scenario_dir"

  log "Scenario END: $name"
}

make_blog_index() {
  local md="$OUT_DIR/README.md"
  cat > "$md" <<EOF2
# W4 Load Test Evidence - $RUN_ID

## What this run proves

- ALB -> ECS Producer -> ECS Kafka -> EKS Consumer -> ECS Enrichment(gRPC) -> Redis/RDS path is deployed on AWS.
- Consumer scaling can be compared by replica count.
- k6 summaries provide request rate, failure rate, p95/p99 latency.
- Consumer logs provide enrichment success, cache hit/miss, Kafka partition/offset, and DB batch persistence evidence.

## Blog-ready files

### Baseline
- `09-alb/producer-health.txt`
- `08-ecs/services.txt`
- `07-k8s/consumer-pods.txt`

### Per scenario
Each scenario has:
- `blog-ready/k6-summary.txt` — main screenshot for latency/RPS/failure rate
- `blog-ready/consumer-pods.txt` — screenshot for EKS replica count
- `blog-ready/consumer-lag.txt` — screenshot for Kafka lag
- `blog-ready/rds-events-processed-count.txt` — screenshot for DB persistence count
- `blog-ready/01-enriched-events.log` — screenshot for successful enrichment
- `blog-ready/02-cache-hit-true.log` — screenshot for Redis cache hit
- `blog-ready/03-cache-hit-false.log` — screenshot for Redis cache miss
- `blog-ready/04-db-persist-batches.log` — screenshot for batch insert
- `blog-ready/05-errors-warnings-degraded.log` — screenshot for failure/degraded analysis if any

## Suggested blog table

| Scenario | Consumer replicas | Target RPS | Failure rate | p95 | p99 | Consumer lag | DB rows |
|---|---:|---:|---:|---:|---:|---:|---:|
| 01-r500-replica1 | 1 | 500 | | | | | |
| 02-r500-replica2 | 2 | 500 | | | | | |
| 03-r500-replica3 | 3 | 500 | | | | | |
| 04-r1000-replica3 | 3 | 1000 | | | | | |

EOF2
}

capture_baseline

# Main benchmark scenarios. Total expected time: around 30~40 minutes including drain/capture.
run_load "01-r500-replica1" 1 100 2m 300 2m 500 2m 1000
run_load "02-r500-replica2" 2 100 2m 300 2m 500 2m 1000
run_load "03-r500-replica3" 3 100 2m 300 2m 500 2m 1000
run_load "04-r1000-replica3" 3 300 1m 700 2m 1000 2m 2000

make_blog_index

log "DONE. Evidence saved to: $OUT_DIR"
log "Open: $OUT_DIR/README.md"
