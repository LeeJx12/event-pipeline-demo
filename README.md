# event-pipeline-demo

> High-throughput event processing pipeline targeting **100k TPS**.
> Kafka + Reactive WebFlux Producer + EKS Consumer + gRPC Enrichment.

A personal benchmark project to measure how a moderately-sized backend
stack behaves under sustained load, and to surface real numbers that can
be cited with confidence — RPS, p99 latency, broker lag, recovery time.

> 🚧 **Status: W1 of 5.** Producer module scaffolded with WebFlux + Reactor Kafka.
> Consumer + Enrichment + gRPC + EKS scheduled for W2–W4.

---

## Architecture

```
Client ── HTTP ──▶ Producer (WebFlux)        ECS Fargate
                       │
                       ▼ publish
                     Kafka (MSK)
                       │
                       ▼ consume
                  Consumer (Kotlin)           EKS
                       │
                       ▼ gRPC enrich
                  Enrichment Service          ECS Fargate
                       │            │
                       ▼ cache       ▼ persist
                    Redis        PostgreSQL
                  (ElastiCache)    (RDS)
```

Why this shape:

- **WebFlux Producer** to demonstrate backpressure on the ingest hot path.
- **Reactor Kafka** sender with batching + lz4 compression for throughput.
- **EKS Consumer** to show horizontal scaling; ECS for everything else.
- **gRPC Enrichment** because internal RPC at scale is cheaper than REST.

---

## Modules

| Module | Stack | Status |
|---|---|---|
| `producer` | Spring Boot 3 + Kotlin + WebFlux + Reactor Kafka | scaffold + unit tests |
| `consumer` | Spring Boot 3 + Kotlin + Kafka + gRPC client | planned |
| `enrichment` | Spring Boot 3 + Kotlin + gRPC server + Redis | planned |
| `proto` | protobuf definitions | planned |

---

## Quick Start

### Local infrastructure (Kafka + Redis + Postgres)

```bash
docker compose up -d
# Kafka UI at http://localhost:8089
```

### Build & test (requires JDK 21)

```bash
./gradlew build
./gradlew :producer:test
```

### Run producer locally

```bash
./gradlew :producer:bootRun
```

### Send a test event

```bash
curl -X POST http://localhost:9080/v1/events \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "u-1",
    "event_type": "order.created",
    "payload": { "amount": 1000, "currency": "KRW" }
  }'
```

Expected response:

```json
{
  "id": "<uuid>",
  "ingestedAt": "2026-04-26T..."
}
```

The Kafka UI will show the message under topic `events`.

---

## Roadmap

- [x] **W1** — Producer scaffold, domain model, unit tests, docker-compose
- [ ] **W2** — Consumer + Enrichment + gRPC contract
- [ ] **W3** — Terraform: VPC, MSK, RDS, ElastiCache, ECS
- [ ] **W4** — EKS for consumer + Helm chart + first 100k TPS attempt
- [ ] **W5** — Failure scenarios (broker down, consumer lag)
- [ ] **W6** — Benchmark report + blog post

See [`docs/`](./docs/) for architecture details and benchmark results
as they become available.

---

## License

MIT
