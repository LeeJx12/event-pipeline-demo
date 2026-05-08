# W4 Results Template

## Test Environment

- Date:
- Region: ap-northeast-2
- Producer: ECS Fargate
- Kafka: ECS single-node Kafka, ephemeral dev
- Consumer: EKS Deployment
- Enrichment: ECS Fargate + Cloud Map gRPC
- DB: RDS PostgreSQL
- Cache: ElastiCache Redis

## Test Matrix

| Run | Consumer Replicas | Target RPS | Duration | p95 | p99 | Fail Rate | Consumer Lag | Notes |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| smoke | 1 | 1 | - | - | - | - | - | E2E check |
| load-1 | 1 | 100/300/500 | 7m | | | | | |
| load-2 | 2 | 100/300/500 | 7m | | | | | |
| load-3 | 3 | 100/300/500 | 7m | | | | | |

## Key Logs

### Consumer enrichment success

```txt
Enriched event id=... cacheHit=false
Enriched event id=... cacheHit=true
```

### Batch persistence

```txt
Persisted processed events batch size=... rows=...
```

## Findings

- Bottleneck:
- First optimization:
- Next step:

## Interview Talking Point

> AWS 상에서 ALB → ECS Producer → Kafka → EKS Consumer → gRPC Enrichment → Redis/RDS까지 end-to-end로 연결했고, k6로 단계 부하를 주면서 consumer replica 변화에 따른 latency, lag, DB insert 처리량을 비교했습니다.
