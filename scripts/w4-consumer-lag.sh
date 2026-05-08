#!/usr/bin/env bash
set -euo pipefail

K8S_NAMESPACE="${K8S_NAMESPACE:-event-pipeline}"
BOOTSTRAP="${KAFKA_BOOTSTRAP_SERVERS:-kafka.event-pipeline-demo-dev.local:9092}"
GROUP="${CONSUMER_GROUP:-event-pipeline-consumer}"

echo "Kafka bootstrap: $BOOTSTRAP"
echo "Consumer group:   $GROUP"

kubectl run kafka-tools-$(date +%s) \
  -n "$K8S_NAMESPACE" \
  --rm -i \
  --restart=Never \
  --image=confluentinc/cp-kafka:7.7.1 \
  --command -- bash -lc "kafka-consumer-groups --bootstrap-server '$BOOTSTRAP' --describe --group '$GROUP' || true"
