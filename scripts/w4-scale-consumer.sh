#!/usr/bin/env bash
set -euo pipefail

REPLICAS="${1:-${REPLICAS:-1}}"
K8S_NAMESPACE="${K8S_NAMESPACE:-event-pipeline}"

kubectl scale deployment/event-pipeline-consumer -n "$K8S_NAMESPACE" --replicas="$REPLICAS"
kubectl rollout status deployment/event-pipeline-consumer -n "$K8S_NAMESPACE"
kubectl get pods -n "$K8S_NAMESPACE" -o wide
