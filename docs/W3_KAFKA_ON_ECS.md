# W3-4 ECS Kafka

## 목적

AWS dev 환경에서 Producer가 실제 Kafka bootstrap server로 이벤트를 publish할 수 있게 한다.

이번 Kafka는 **dev/demo용 단일 노드 ECS/Fargate Kafka**다. 운영용 Kafka가 아니다. W4 부하테스트/운영성 시연 단계에서는 MSK 또는 EKS 기반 Kafka로 교체할 수 있다.

## 구성

```txt
ALB
  -> producer:9080
       -> kafka.event-pipeline-demo-dev.local:9092

enrichment.event-pipeline-demo-dev.local:9090
kafka.event-pipeline-demo-dev.local:9092
```

추가 리소스:

```txt
ECS service: event-pipeline-demo-dev-kafka
Task definition: event-pipeline-demo-dev-kafka
CloudWatch log group: /ecs/event-pipeline-demo-dev/kafka
Cloud Map DNS: kafka.event-pipeline-demo-dev.local
Security group rule: ECS service self-ingress 9092
```

## 적용

```bash
cd /Users/rarenote-myles/Documents/event-pipeline-demo
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2

./scripts/tf.sh apply
```

## 확인

```bash
cd infra/terraform
terraform output kafka_bootstrap_servers
terraform output producer_url
```

ECS running count:

```bash
aws ecs describe-services \
  --cluster event-pipeline-demo-dev-cluster \
  --services \
    event-pipeline-demo-dev-kafka \
    event-pipeline-demo-dev-producer \
    event-pipeline-demo-dev-enrichment \
  --query 'services[].{name:serviceName,running:runningCount,desired:desiredCount,status:status}' \
  --output table \
  --profile leejx2 \
  --region ap-northeast-2
```

ALB health:

```bash
PRODUCER_URL=$(terraform output -raw producer_url)
curl -i "$PRODUCER_URL/actuator/health"
```

Publish smoke test:

```bash
curl -i -X POST "$PRODUCER_URL/v1/events" \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"u-1","event_type":"order.created","payload":{"amount":1000}}'
```

Producer logs:

```bash
aws logs tail /ecs/event-pipeline-demo-dev/producer \
  --since 10m \
  --profile leejx2 \
  --region ap-northeast-2
```

Kafka logs:

```bash
aws logs tail /ecs/event-pipeline-demo-dev/kafka \
  --since 10m \
  --profile leejx2 \
  --region ap-northeast-2
```

## 주의

- 이 Kafka는 Fargate ephemeral storage 기반 단일 노드다.
- `terraform destroy` 하면 Kafka 데이터도 사라진다.
- 비용/검증 목적상 W3 단계에서는 이게 맞다.
- 면접에서는 “AWS 연결 검증용 ephemeral Kafka, 부하테스트 단계에서는 MSK/EKS 구조로 교체 가능”이라고 말하면 된다.
