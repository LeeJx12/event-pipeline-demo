# W4 Load Test & Metrics Capture

## Goal

AWS full path 기준으로 부하테스트 수치와 블로그/evidence 자료를 확보한다.

```
ALB → ECS Producer → ECS Kafka → EKS Consumer → ECS Enrichment → Redis/RDS
```

## 0. Preconditions

- `./scripts/aws-dev-up.sh` 완료
- ECS producer/kafka/enrichment running=1
- EKS consumer pod running
- `/v1/events` smoke test 202 확인
- consumer log에서 `Enriched event ...` + `Persisted processed events batch ...` 확인

## 1. Network rules 확인

EKS consumer가 ECS Kafka/Enrichment에 붙으려면 ECS service SG에 VPC CIDR ingress가 필요하다.

```bash
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2
./scripts/w4-ensure-network-rules.sh
```

열리는 포트:

- `9092`: EKS consumer → ECS Kafka
- `9090`: EKS consumer → ECS Enrichment gRPC

## 2. Smoke test

```bash
./scripts/aws-e2e-smoke.sh
```

성공 기준:

```txt
Producer health: 200
Publish event: 202
ECS services: kafka/producer/enrichment running=1
EKS consumer: Running
Consumer logs: Enriched event + Persisted batch
```

## 3. k6 부하테스트

기본 단계는 100 → 300 → 500 RPS다.

```bash
brew install k6 # 없으면

export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2

./scripts/w4-load-test.sh
```

커스텀 예시:

```bash
STAGE1_RATE=100 STAGE1_DURATION=1m \
STAGE2_RATE=500 STAGE2_DURATION=2m \
STAGE3_RATE=1000 STAGE3_DURATION=2m \
MAX_VUS=2000 \
./scripts/w4-load-test.sh
```

결과는 `docs/evidence/w4/<timestamp>/`에 저장된다.

## 4. Consumer scale 테스트

```bash
./scripts/w4-scale-consumer.sh 1
./scripts/w4-load-test.sh
./scripts/w4-consumer-lag.sh

./scripts/w4-scale-consumer.sh 2
./scripts/w4-load-test.sh
./scripts/w4-consumer-lag.sh

./scripts/w4-scale-consumer.sh 3
./scripts/w4-load-test.sh
./scripts/w4-consumer-lag.sh
```

비교할 것:

- k6 p95/p99 latency
- consumer lag
- DB insert count 증가량
- consumer pod CPU/memory
- `cacheHit=false`에서 `cacheHit=true`로 바뀌는 로그

## 5. Metrics/evidence 캡처

```bash
./scripts/w4-capture-metrics.sh
```

저장 항목:

- ECS service running count
- EKS consumer pod 목록
- `kubectl top pods`
- consumer logs
- producer/enrichment/kafka CloudWatch logs
- terraform outputs

## 6. RDS row count

로컬에서 RDS 접근 가능해야 한다. RDS가 private이면 VPN/bastion 없이 직접 접근은 안 된다. 이 경우 CloudWatch/log evidence로 먼저 간다.

```bash
export DB_PASSWORD='<terraform.tfvars의 db_password>'
./scripts/w4-rds-count.sh
```

## 7. 블로그용 캡처 체크리스트

- [ ] AWS 구조도: ALB/ECS/EKS/RDS/Redis/Kafka
- [ ] k6 summary: http_req_duration p95/p99
- [ ] k6 RPS 단계별 결과
- [ ] ECS services running=1
- [ ] EKS consumer replicas 1/2/3 비교
- [ ] consumer log: `Enriched event ... cacheHit=false/true`
- [ ] consumer log: `Persisted processed events batch size=... rows=...`
- [ ] consumer lag output
- [ ] RDS row count

## 8. 비용 방지

작업 끝나면 반드시:

```bash
./scripts/aws-dev-down.sh
```
