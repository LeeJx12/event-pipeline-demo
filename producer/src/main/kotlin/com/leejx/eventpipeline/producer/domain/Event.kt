package com.leejx.eventpipeline.producer.domain

import com.fasterxml.jackson.annotation.JsonProperty
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import java.time.Instant
import java.util.UUID

/**
 * Incoming event from external clients (HTTP POST).
 *
 * Validation: userId and eventType are required.
 * Optional fields (occurredAt, payload) get sensible defaults.
 */
data class IncomingEvent(
    @field:NotBlank
    @JsonProperty("user_id")
    val userId: String,

    @field:NotBlank
    @JsonProperty("event_type")
    val eventType: String,

    @JsonProperty("occurred_at")
    val occurredAt: Instant? = null,

    val payload: Map<String, Any?> = emptyMap(),
)

/**
 * Internal event published to Kafka. Has a server-assigned ID + ingestion timestamp.
 */
data class PipelineEvent(
    val id: String,
    @JsonProperty("user_id") val userId: String,
    @JsonProperty("event_type") val eventType: String,
    @JsonProperty("occurred_at") val occurredAt: Instant,
    @JsonProperty("ingested_at") val ingestedAt: Instant,
    val payload: Map<String, Any?>,
) {
    companion object {
        fun from(incoming: IncomingEvent, now: Instant = Instant.now()): PipelineEvent =
            PipelineEvent(
                id = UUID.randomUUID().toString(),
                userId = incoming.userId,
                eventType = incoming.eventType,
                occurredAt = incoming.occurredAt ?: now,
                ingestedAt = now,
                payload = incoming.payload,
            )
    }
}
