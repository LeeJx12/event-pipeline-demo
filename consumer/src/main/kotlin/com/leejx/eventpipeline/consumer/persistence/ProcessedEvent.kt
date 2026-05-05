package com.leejx.eventpipeline.consumer.persistence

import com.leejx.eventpipeline.consumer.domain.PipelineEvent
import com.leejx.eventpipeline.consumer.enrichment.EnrichmentResult
import reactor.kafka.receiver.ReceiverRecord
import java.time.Instant

data class ProcessedEvent(
    val event: PipelineEvent,
    val enrichment: EnrichmentResult,
    val kafkaPartition: Int,
    val kafkaOffset: Long,
    val processedAt: Instant = Instant.now(),
) {
    companion object {
        fun from(
            event: PipelineEvent,
            enrichment: EnrichmentResult,
            record: ReceiverRecord<String, String>,
        ): ProcessedEvent = ProcessedEvent(
            event = event,
            enrichment = enrichment,
            kafkaPartition = record.partition(),
            kafkaOffset = record.offset(),
        )
    }
}
