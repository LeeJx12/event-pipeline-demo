package com.leejx.eventpipeline.consumer.domain

import com.fasterxml.jackson.annotation.JsonProperty
import java.time.Instant

/**
 * Mirror of producer's PipelineEvent (deserialized from Kafka).
 *
 * Kept as a separate type in this module to avoid coupling consumer to
 * producer internals — they only share the wire format (JSON), not code.
 */
data class PipelineEvent(
    val id: String,
    @JsonProperty("user_id") val userId: String,
    @JsonProperty("event_type") val eventType: String,
    @JsonProperty("occurred_at") val occurredAt: Instant,
    @JsonProperty("ingested_at") val ingestedAt: Instant,
    val payload: Map<String, Any?> = emptyMap(),
)
