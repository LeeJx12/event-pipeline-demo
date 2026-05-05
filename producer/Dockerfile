FROM eclipse-temurin:21-jdk-jammy AS builder
WORKDIR /workspace

COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
COPY proto ./proto
COPY producer ./producer

RUN chmod +x ./gradlew
RUN ./gradlew :producer:bootJar --no-daemon

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app app
COPY --from=builder /workspace/producer/build/libs/*.jar /app/app.jar
RUN chown -R app:app /app
USER app

EXPOSE 9080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
