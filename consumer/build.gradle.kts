plugins {
    kotlin("plugin.spring")
    id("org.springframework.boot")
    id("io.spring.dependency-management")
}

dependencies {
    // proto module — generated stubs (EnrichmentServiceGrpc, request/response types)
    implementation(project(":proto"))

    // Spring Boot
    implementation("org.springframework.boot:spring-boot-starter")
    implementation("org.springframework.boot:spring-boot-starter-actuator")

    // Reactor Kafka (consumer side)
    implementation("io.projectreactor.kafka:reactor-kafka:1.3.23")
    implementation("io.projectreactor:reactor-core")

    // gRPC client (LogNet starter — same family as the server side)
    implementation("net.devh:grpc-client-spring-boot-starter:3.1.0.RELEASE")
    // gRPC transport — LogNet starter does NOT bundle a transport,
    // so we need to pick one explicitly. netty-shaded is the standard choice.
    runtimeOnly("io.grpc:grpc-netty-shaded:1.68.1")

    // Kotlin
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("com.fasterxml.jackson.datatype:jackson-datatype-jsr310")
    implementation("io.projectreactor.kotlin:reactor-kotlin-extensions")

    // Logging
    implementation("net.logstash.logback:logstash-logback-encoder:8.0")

    // Test
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("io.projectreactor:reactor-test")
    testImplementation("org.testcontainers:junit-jupiter:1.20.4")
    testImplementation("org.testcontainers:kafka:1.20.4")
    testImplementation("io.mockk:mockk:1.13.13")
    testImplementation("com.ninja-squad:springmockk:4.0.2")
    testImplementation("org.awaitility:awaitility:4.2.2")
}
