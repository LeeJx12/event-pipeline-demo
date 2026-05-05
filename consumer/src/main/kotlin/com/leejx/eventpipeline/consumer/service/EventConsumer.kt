package com.leejx.eventpipeline.consumer.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.consumer.domain.PipelineEvent
import com.leejx.eventpipeline.consumer.enrichment.EnrichmentClient
import com.leejx.eventpipeline.consumer.enrichment.EnrichmentResult
import jakarta.annotation.PostConstruct
import jakarta.annotation.PreDestroy
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.Disposable
import reactor.core.publisher.Mono
import reactor.kafka.receiver.KafkaReceiver
import reactor.kafka.receiver.ReceiverRecord
import java.util.concurrent.atomic.AtomicLong

/**
 * Subscribes to the events topic, enriches each event via gRPC, then logs.
 *
 * Pipeline per record:
 *   1. Deserialize JSON → PipelineEvent
 *   2. Call EnrichmentClient.lookup(userId)  (gRPC, may degrade)
 *   3. Log enriched view
 *   4. Manual ack — at-least-once
 *
 * Failure semantics:
 *   - Deserialization failure → log + ack (don't block partition)
 *   - Enrichment unavailable → continue with empty enrichment, increment counter
 *   - Acknowledge errors → bubble up (Reactor stream resilience handles it)
 */
@Service
class EventConsumer(
    private val receiver: KafkaReceiver<String, String>,
    private val objectMapper: ObjectMapper,
    private val enrichmentClient: EnrichmentClient,
) {
    private val log = LoggerFactory.getLogger(javaClass)
    private val processed = AtomicLong()
    private val failed = AtomicLong()
    private val enrichmentMisses = AtomicLong()
    private var subscription: Disposable? = null

    @PostConstruct
    fun start() {
        log.info("EventConsumer starting subscription")
        subscription = receiver.receive()
            // concurrency=8: process up to 8 records in parallel per partition stream.
            // Higher = better throughput; bounded so we don't exhaust enrichment.
            .flatMap({ record -> handle(record) }, 8)
            .doOnError { err -> log.error("Receiver stream error", err) }
            .subscribe()
    }

    @PreDestroy
    fun stop() {
        log.info(
            "EventConsumer stopping. processed={} failed={} enrichmentMisses={}",
            processed.get(),
            failed.get(),
            enrichmentMisses.get(),
        )
        subscription?.dispose()
    }

    private fun handle(record: ReceiverRecord<String, String>): Mono<Void> {
        val event = try {
            objectMapper.readValue(record.value(), PipelineEvent::class.java)
        } catch (ex: Exception) {
            failed.incrementAndGet()
            log.error(
                "Failed to deserialize record key={} partition={} offset={}",
                record.key(), record.partition(), record.offset(), ex,
            )
            record.receiverOffset().acknowledge()
            return Mono.empty()
        }

        return enrichmentClient.lookup(event.userId)
            .doOnNext { result -> logEnriched(event, record, result) }
            .doOnNext { result ->
                if (!result.available) enrichmentMisses.incrementAndGet()
                processed.incrementAndGet()
                record.receiverOffset().acknowledge()
            }
            .then()
    }

    private fun logEnriched(
        event: PipelineEvent,
        record: ReceiverRecord<String, String>,
        result: EnrichmentResult,
    ) {
        if (result.available) {
            log.info(
                "Enriched event id={} userId={} type={} country={} tier={} cacheHit={} partition={} offset={}",
                event.id, event.userId, event.eventType,
                result.enrichment.country, result.enrichment.tier, result.cacheHit,
                record.partition(), record.offset(),
            )
        } else {
            log.info(
                "Event consumed without enrichment (degraded) id={} userId={} type={} partition={} offset={}",
                event.id, event.userId, event.eventType,
                record.partition(), record.offset(),
            )
        }
    }

    fun stats(): Map<String, Long> = mapOf(
        "processed" to processed.get(),
        "failed" to failed.get(),
        "enrichmentMisses" to enrichmentMisses.get(),
    )
}
