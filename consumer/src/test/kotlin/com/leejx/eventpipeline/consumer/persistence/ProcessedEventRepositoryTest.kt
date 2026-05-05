package com.leejx.eventpipeline.consumer.persistence

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.kotlinModule
import com.leejx.eventpipeline.consumer.domain.PipelineEvent
import com.leejx.eventpipeline.consumer.enrichment.EnrichmentResult
import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test
import io.mockk.mockk
import org.springframework.r2dbc.core.DatabaseClient
import reactor.test.StepVerifier
import java.time.Instant

class ProcessedEventRepositoryTest {
    private val objectMapper = ObjectMapper()
        .registerModule(kotlinModule())
        .registerModule(JavaTimeModule())

    @Test
    fun `saveBatch returns zero for empty batch`() {
        val repository = ProcessedEventRepository(mockk<DatabaseClient>(), objectMapper)

        StepVerifier.create(repository.saveBatch(emptyList()))
            .expectNext(0)
            .verifyComplete()
    }

    @Test
    fun `processed event model carries enrichment fields`() {
        val event = PipelineEvent(
            id = "evt-1",
            userId = "u-1",
            eventType = "order.created",
            occurredAt = Instant.parse("2026-04-30T00:00:00Z"),
            ingestedAt = Instant.parse("2026-04-30T00:00:01Z"),
            payload = mapOf("amount" to 1000),
        )
        val enrichment = UserEnrichment.newBuilder()
            .setFound(true)
            .setCountry("US")
            .setTier("premium")
            .setSignupUnixMs(1704067200000)
            .addAllTags(listOf("order-heavy"))
            .build()

        val processed = ProcessedEvent(
            event = event,
            enrichment = EnrichmentResult(enrichment, cacheHit = false, available = true),
            kafkaPartition = 1,
            kafkaOffset = 42,
        )

        assertEquals("evt-1", processed.event.id)
        assertEquals("US", processed.enrichment.enrichment.country)
        assertEquals(1, processed.kafkaPartition)
        assertEquals(42, processed.kafkaOffset)
    }
}
