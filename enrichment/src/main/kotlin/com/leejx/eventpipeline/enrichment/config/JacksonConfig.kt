package com.leejx.eventpipeline.enrichment.config

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.kotlinModule
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

/**
 * Without spring-boot-starter-web/webflux on the classpath, Jackson
 * autoconfiguration is not triggered. We register a single ObjectMapper bean
 * here so UserEnrichmentRepository can serialize cache entries.
 *
 * Includes Kotlin module (data class support) and JavaTime module (Instant).
 */
@Configuration
class JacksonConfig {

    @Bean
    fun objectMapper(): ObjectMapper =
        ObjectMapper()
            .registerModule(kotlinModule())
            .registerModule(JavaTimeModule())
}
