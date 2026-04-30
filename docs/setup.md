# Setup Notes — first-time local checkout

이 문서는 처음 클론한 직후 한 번만 실행하면 되는 셋업 가이드입니다.

## 1. Prerequisites

- **JDK 21** (`brew install --cask temurin@21` on macOS)
- **Docker Desktop** (Kafka/Redis/Postgres 실행용)
- **Gradle 8.x** (Wrapper 생성을 위해 한 번만 필요. 이후엔 `./gradlew` 만 쓰면 됨)
  - macOS: `brew install gradle`

## 2. Generate Gradle Wrapper (first time only)

레포에는 wrapper 정의만 들어있고, 실제 `gradle-wrapper.jar` + `gradlew` 스크립트는
gitignore되어 있어 매번 새로 받아야 합니다. 한 번만 실행하면 됩니다:

```bash
cd event-pipeline-demo
gradle wrapper --gradle-version 8.10.2
```

이렇게 하면 `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar` 가 생성됩니다.

> Wrapper 생성 후에는 시스템에 Gradle이 없어도 `./gradlew` 만으로 빌드 가능합니다.

## 3. Build & Verify

```bash
# 의존성 다운로드 + 컴파일 + 테스트
./gradlew build

# producer 모듈 단위 테스트만
./gradlew :producer:test
```

성공하면 5개 테스트(`PipelineEventTest`)가 통과합니다.

## 4. Run Local Infrastructure

```bash
docker compose up -d
docker compose ps
```

다음 컨테이너가 healthy 상태여야 합니다:
- `ep-zookeeper`
- `ep-kafka`
- `ep-kafka-ui` (http://localhost:8089)
- `ep-redis`
- `ep-postgres`

## 5. Run Producer

```bash
./gradlew :producer:bootRun
```

새 터미널에서:

```bash
curl -X POST http://localhost:9080/v1/events \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"u-1","event_type":"order.created","payload":{"amount":1000}}'
```

응답 예:

```json
{"id":"<uuid>","ingestedAt":"2026-04-26T..."}
```

Kafka UI (http://localhost:8089)에서 `events` 토픽으로 들어가면
방금 발행된 메시지를 확인할 수 있어야 합니다.

## 6. Cleanup

```bash
docker compose down -v   # -v: 볼륨까지 삭제 (Postgres 데이터 초기화)
```

---

## Troubleshooting

**`./gradlew build` 가 의존성 다운로드 중 멈춤**
- 회사 망에서 Maven Central 차단 가능성. 개인 네트워크에서 시도.

**Kafka UI에 메시지가 안 보임**
- Producer가 `localhost:9092`로 연결 시도하는지 확인 (`application.yml`의 `app.kafka.bootstrap-servers`)
- `docker compose logs kafka` 로 로그 확인

**Reactor Kafka 빌드 실패 (의존성 미해결)**
- `reactor-kafka` 버전이 Spring Boot 3.4와 호환되는지 확인. 현재 1.3.23로 테스트됨.
