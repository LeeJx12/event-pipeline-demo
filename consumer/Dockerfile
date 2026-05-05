FROM eclipse-temurin:21-jdk-jammy AS builder
WORKDIR /workspace

COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
COPY proto ./proto
COPY consumer ./consumer

RUN chmod +x ./gradlew
RUN ./gradlew :consumer:bootJar --no-daemon

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app app
COPY --from=builder /workspace/consumer/build/libs/*.jar /app/app.jar
RUN chown -R app:app /app
USER app

EXPOSE 9081
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
