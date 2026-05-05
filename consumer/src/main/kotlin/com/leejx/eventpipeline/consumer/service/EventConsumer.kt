package com.leejx.eventpipeline.consumer.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.consumer.domain.PipelineEvent
import com.leejx.eventpipeline.consumer.enrichment.EnrichmentClient
import com.leejx.eventpipeline.consumer.enrichment.EnrichmentResult
import com.leejx.eventpipeline.consumer.persistence.ProcessedEvent
import com.leejx.eventpipeline.consumer.persistence.ProcessedEventRepository
import jakarta.annotation.PostConstruct
import jakarta.annotation.PreDestroy
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.Disposable
import reactor.core.publisher.Mono
import reactor.kafka.receiver.KafkaReceiver
import reactor.kafka.receiver.ReceiverRecord
import java.time.Duration
import java.util.concurrent.atomic.AtomicLong

/**
 * Subscribes to the events topic, enriches each event via gRPC, persists in
 * PostgreSQL, then manually acks Kafka offsets.
 *
 * Pipeline per record:
 * 1. Deserialize JSON → PipelineEvent
 * 2. Call EnrichmentClient.lookup(userId) (gRPC, may degrade)
 * 3. Buffer processed rows in batches of 100 (or 500ms timeout)
 * 4. Persist to events_processed
 * 5. Manual ack after DB write — at-least-once
 */
@Service
class EventConsumer(
    private val receiver: KafkaReceiver<String, String>,
    private val objectMapper: ObjectMapper,
    private val enrichmentClient: EnrichmentClient,
    private val processedEventRepository: ProcessedEventRepository,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    private val processed = AtomicLong()
    private val failed = AtomicLong()
    private val enrichmentMisses = AtomicLong()
    private val persisted = AtomicLong()

    private var subscription: Disposable? = null

    @PostConstruct
    fun start() {
        log.info("EventConsumer starting subscription")
        subscription = receiver.receive()
            // concurrency=8: process up to 8 enrichment calls in parallel.
            .flatMap({ record -> enrich(record) }, 8)
            .bufferTimeout(BATCH_SIZE, BATCH_TIMEOUT)
            .filter { it.isNotEmpty() }
            .concatMap { batch -> persistAndAck(batch) }
            .doOnError { err -> log.error("Receiver stream error", err) }
            .subscribe()
    }

    @PreDestroy
    fun stop() {
        log.info(
            "EventConsumer stopping. processed={} persisted={} failed={} enrichmentMisses={}",
            processed.get(),
            persisted.get(),
            failed.get(),
            enrichmentMisses.get(),
        )
        subscription?.dispose()
    }

    private fun enrich(record: ReceiverRecord<String, String>): Mono<RecordToPersist> {
        val event = try {
            objectMapper.readValue(record.value(), PipelineEvent::class.java)
        } catch (ex: Exception) {
            failed.incrementAndGet()
            log.error(
                "Failed to deserialize record key={} partition={} offset={}",
                record.key(),
                record.partition(),
                record.offset(),
                ex,
            )
            record.receiverOffset().acknowledge()
            return Mono.empty()
        }

        return enrichmentClient.lookup(event.userId)
            .map { result ->
                logEnriched(event, record, result)
                RecordToPersist(
                    record = record,
                    processedEvent = ProcessedEvent.from(event, result, record),
                )
            }
    }

    private fun persistAndAck(batch: List<RecordToPersist>): Mono<Void> = processedEventRepository
        .saveBatch(batch.map { it.processedEvent })
        .doOnNext { rows ->
            batch.forEach { item ->
                if (!item.processedEvent.enrichment.available) enrichmentMisses.incrementAndGet()
                processed.incrementAndGet()
                item.record.receiverOffset().acknowledge()
            }
            persisted.addAndGet(rows.toLong())
            log.debug("Persisted processed events batch size={} rows={}", batch.size, rows)
        }
        .onErrorResume { err ->
            failed.addAndGet(batch.size.toLong())
            log.error("Failed to persist processed events batch size={}. Offsets are not acked", batch.size, err)
            Mono.empty()
        }
        .then()

    private fun logEnriched(
        event: PipelineEvent,
        record: ReceiverRecord<String, String>,
        result: EnrichmentResult,
    ) {
        if (result.available) {
            log.info(
                "Enriched event id={} userId={} type={} country={} tier={} cacheHit={} partition={} offset={}",
                event.id,
                event.userId,
                event.eventType,
                result.enrichment.country,
                result.enrichment.tier,
                result.cacheHit,
                record.partition(),
                record.offset(),
            )
        } else {
            log.info(
                "Event consumed without enrichment (degraded) id={} userId={} type={} partition={} offset={}",
                event.id,
                event.userId,
                event.eventType,
                record.partition(),
                record.offset(),
            )
        }
    }

    fun stats(): Map<String, Long> = mapOf(
        "processed" to processed.get(),
        "persisted" to persisted.get(),
        "failed" to failed.get(),
        "enrichmentMisses" to enrichmentMisses.get(),
    )

    private data class RecordToPersist(
        val record: ReceiverRecord<String, String>,
        val processedEvent: ProcessedEvent,
    )

    companion object {
        private const val BATCH_SIZE = 100
        private val BATCH_TIMEOUT: Duration = Duration.ofMillis(500)
    }
}
