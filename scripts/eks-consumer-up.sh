#!/usr/bin/env bash
set -euo pipefail

EXPECTED_ACCOUNT_ID="${EXPECTED_AWS_ACCOUNT_ID:-821465445446}"
AWS_PROFILE_NAME="${AWS_PROFILE:-leejx2}"
AWS_REGION_NAME="${AWS_REGION:-ap-northeast-2}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${PROJECT_ROOT}/infra/terraform"

ACTUAL_ACCOUNT_ID="$(AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws sts get-caller-identity --query Account --output text)"
if [[ "$ACTUAL_ACCOUNT_ID" != "$EXPECTED_ACCOUNT_ID" ]]; then
  echo "ERROR: Wrong AWS account. expected=${EXPECTED_ACCOUNT_ID}, actual=${ACTUAL_ACCOUNT_ID}" >&2
  exit 1
fi

if [[ -z "${DB_PASSWORD:-}" ]]; then
  echo "ERROR: DB_PASSWORD env is required for consumer RDS/Flyway config." >&2
  echo "Example: export DB_PASSWORD='<same value as terraform.tfvars db_password>'" >&2
  exit 1
fi

cd "$TF_DIR"
CLUSTER_NAME="$(terraform output -raw eks_cluster_name)"
CONSUMER_ECR="$(terraform output -raw consumer_ecr_repository_url)"
RDS_ENDPOINT="$(terraform output -raw rds_endpoint)"
RDS_PORT="$(terraform output -raw rds_port)"
KAFKA_BOOTSTRAP="$(terraform output -raw kafka_bootstrap_servers)"
ENRICHMENT_DNS="$(terraform output -raw enrichment_cloud_map_dns)"
IMAGE_TAG="${IMAGE_TAG:-dev-latest}"

if [[ "$CLUSTER_NAME" == "null" || -z "$CLUSTER_NAME" ]]; then
  echo "ERROR: EKS is not enabled or terraform output eks_cluster_name is empty." >&2
  exit 1
fi

AWS_PROFILE="$AWS_PROFILE_NAME" AWS_REGION="$AWS_REGION_NAME" aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$AWS_REGION_NAME" \
  --profile "$AWS_PROFILE_NAME"

kubectl create namespace event-pipeline --dry-run=client -o yaml | kubectl apply -f -

cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: event-pipeline-consumer
  namespace: event-pipeline
  labels:
    app: event-pipeline-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: event-pipeline-consumer
  template:
    metadata:
      labels:
        app: event-pipeline-consumer
    spec:
      containers:
        - name: consumer
          image: ${CONSUMER_ECR}:${IMAGE_TAG}
          imagePullPolicy: Always
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: aws
            - name: SPRING_KAFKA_BOOTSTRAP_SERVERS
              value: ${KAFKA_BOOTSTRAP}
            - name: KAFKA_BOOTSTRAP_SERVERS
              value: ${KAFKA_BOOTSTRAP}
            - name: APP_KAFKA_BOOTSTRAP_SERVERS
              value: ${KAFKA_BOOTSTRAP}
            - name: GRPC_CLIENT_ENRICHMENT_ADDRESS
              value: static://${ENRICHMENT_DNS}:9090
            - name: SPRING_R2DBC_URL
              value: r2dbc:postgresql://${RDS_ENDPOINT}:${RDS_PORT}/pipeline?sslMode=require
            - name: SPRING_R2DBC_USERNAME
              value: pipeline
            - name: SPRING_R2DBC_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: event-pipeline-consumer-secret
                  key: db-password
            - name: SPRING_FLYWAY_URL
              value: jdbc:postgresql://${RDS_ENDPOINT}:${RDS_PORT}/pipeline?sslMode=require
            - name: SPRING_FLYWAY_USER
              value: pipeline
            - name: SPRING_FLYWAY_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: event-pipeline-consumer-secret
                  key: db-password
          resources:
            requests:
              cpu: "250m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1024Mi"
---
apiVersion: v1
kind: Secret
metadata:
  name: event-pipeline-consumer-secret
  namespace: event-pipeline
type: Opaque
stringData:
  db-password: "${DB_PASSWORD}"
YAML

kubectl -n event-pipeline rollout status deployment/event-pipeline-consumer --timeout=180s
kubectl -n event-pipeline get pods -l app=event-pipeline-consumer -o wide
