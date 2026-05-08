# W4 Blog Evidence Runbook

이 문서는 W4 부하테스트를 한 번에 돌리고 블로그 캡처용 증거 파일을 남기는 방법이다.

## 실행 전 조건

- AWS dev 환경이 올라와 있어야 한다.
- ECS producer/kafka/enrichment가 running=1이어야 한다.
- EKS consumer가 배포 가능해야 한다.
- k6가 설치되어 있어야 한다.

```bash
brew install k6
```

## 전체 시나리오 실행

```bash
export AWS_PROFILE=leejx2
export AWS_REGION=ap-northeast-2
export DB_PASSWORD='<terraform.tfvars의 db_password>'

./scripts/w4-run-all-scenarios.sh
```

총 실행 시간은 대략 30~40분이다.

## 실행되는 시나리오

1. `01-r500-replica1`
   - consumer replicas: 1
   - 100 RPS 2m → 300 RPS 2m → 500 RPS 2m

2. `02-r500-replica2`
   - consumer replicas: 2
   - 100 RPS 2m → 300 RPS 2m → 500 RPS 2m

3. `03-r500-replica3`
   - consumer replicas: 3
   - 100 RPS 2m → 300 RPS 2m → 500 RPS 2m

4. `04-r1000-replica3`
   - consumer replicas: 3
   - 300 RPS 1m → 700 RPS 2m → 1000 RPS 2m

## 결과 위치

```txt
docs/evidence/w4/<timestamp>/
```

각 시나리오 폴더에는 `blog-ready/`와 `raw/`가 있다.

## 블로그 캡처용 파일

각 시나리오의 아래 파일만 보면 된다.

```txt
blog-ready/k6-summary.txt
blog-ready/consumer-pods.txt
blog-ready/consumer-lag.txt
blog-ready/rds-events-processed-count.txt
blog-ready/01-enriched-events.log
blog-ready/02-cache-hit-true.log
blog-ready/03-cache-hit-false.log
blog-ready/04-db-persist-batches.log
blog-ready/05-errors-warnings-degraded.log
```

## 블로그에 넣을 핵심 증거

- `k6-summary.txt`
  - 전체 요청 수
  - 실패율
  - p95/p99 latency

- `consumer-pods.txt`
  - consumer replica 1/2/3 스케일링 증거

- `consumer-lag.txt`
  - Kafka lag가 얼마나 쌓였는지

- `01-enriched-events.log`
  - Consumer가 gRPC enrichment 성공한 증거

- `02-cache-hit-true.log` / `03-cache-hit-false.log`
  - Redis cache-aside 패턴 증거

- `04-db-persist-batches.log`
  - RDS batch insert 증거

## 끝나면 비용 방지

```bash
./scripts/aws-dev-down.sh
```
