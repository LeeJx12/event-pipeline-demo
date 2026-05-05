package com.leejx.eventpipeline.consumer.persistence

import com.fasterxml.jackson.databind.ObjectMapper
import org.springframework.r2dbc.core.DatabaseClient
import org.springframework.stereotype.Repository
import reactor.core.publisher.Flux
import reactor.core.publisher.Mono

@Repository
class ProcessedEventRepository(
    private val databaseClient: DatabaseClient,
    private val objectMapper: ObjectMapper,
) {
    fun saveBatch(events: Collection<ProcessedEvent>): Mono<Int> {
        if (events.isEmpty()) return Mono.just(0)

        return Flux.fromIterable(events)
            .concatMap { saveOne(it) }
            .reduce(0) { acc, rows -> acc + rows }
    }

    private fun saveOne(processed: ProcessedEvent): Mono<Int> {
        val event = processed.event
        val enrichment = processed.enrichment.enrichment
        val tags = enrichment.tagsList.toTypedArray()

        return databaseClient.sql(
            """
            INSERT INTO events_processed (
                event_id,
                user_id,
                event_type,
                occurred_at,
                ingested_at,
                processed_at,
                payload,
                enrichment_found,
                enrichment_country,
                enrichment_tier,
                enrichment_signup_unix_ms,
                enrichment_tags,
                enrichment_cache_hit,
                enrichment_available,
                kafka_partition,
                kafka_offset
            ) VALUES (
                :eventId,
                :userId,
                :eventType,
                :occurredAt,
                :ingestedAt,
                :processedAt,
                CAST(:payload AS JSONB),
                :enrichmentFound,
                :enrichmentCountry,
                :enrichmentTier,
                :enrichmentSignupUnixMs,
                :enrichmentTags,
                :enrichmentCacheHit,
                :enrichmentAvailable,
                :kafkaPartition,
                :kafkaOffset
            )
            ON CONFLICT (event_id) DO UPDATE SET
                processed_at = EXCLUDED.processed_at,
                enrichment_found = EXCLUDED.enrichment_found,
                enrichment_country = EXCLUDED.enrichment_country,
                enrichment_tier = EXCLUDED.enrichment_tier,
                enrichment_signup_unix_ms = EXCLUDED.enrichment_signup_unix_ms,
                enrichment_tags = EXCLUDED.enrichment_tags,
                enrichment_cache_hit = EXCLUDED.enrichment_cache_hit,
                enrichment_available = EXCLUDED.enrichment_available,
                kafka_partition = EXCLUDED.kafka_partition,
                kafka_offset = EXCLUDED.kafka_offset
            """.trimIndent(),
        )
            .bind("eventId", event.id)
            .bind("userId", event.userId)
            .bind("eventType", event.eventType)
            .bind("occurredAt", event.occurredAt)
            .bind("ingestedAt", event.ingestedAt)
            .bind("processedAt", processed.processedAt)
            .bind("payload", objectMapper.writeValueAsString(event.payload))
            .bind("enrichmentFound", enrichment.found)
            .bind("enrichmentCountry", enrichment.country)
            .bind("enrichmentTier", enrichment.tier)
            .bind("enrichmentSignupUnixMs", enrichment.signupUnixMs)
            .bind("enrichmentTags", tags)
            .bind("enrichmentCacheHit", processed.enrichment.cacheHit)
            .bind("enrichmentAvailable", processed.enrichment.available)
            .bind("kafkaPartition", processed.kafkaPartition)
            .bind("kafkaOffset", processed.kafkaOffset)
            .fetch()
            .rowsUpdated()
            .map { it.toInt() }
    }
}
