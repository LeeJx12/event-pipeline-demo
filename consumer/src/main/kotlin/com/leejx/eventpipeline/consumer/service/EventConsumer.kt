package com.leejx.eventpipeline.consumer.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.consumer.domain.PipelineEvent
import jakarta.annotation.PostConstruct
import jakarta.annotation.PreDestroy
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.Disposable
import reactor.kafka.receiver.KafkaReceiver
import reactor.kafka.receiver.ReceiverRecord
import java.util.concurrent.atomic.AtomicLong

/**
 * Subscribes to the events topic and processes each message.
 *
 * Current behavior: parse JSON, log, manually commit offset.
 * W2 후반: enrichment gRPC call + Postgres write.
 *
 * The receiver is started in @PostConstruct so the consumer is active
 * as soon as the Spring context is ready, and disposed on shutdown
 * to avoid orphaned Kafka connections.
 */
@Service
class EventConsumer(
    private val receiver: KafkaReceiver<String, String>,
    private val objectMapper: ObjectMapper,
) {
    private val log = LoggerFactory.getLogger(javaClass)
    private val processed = AtomicLong()
    private val failed = AtomicLong()
    private var subscription: Disposable? = null

    @PostConstruct
    fun start() {
        log.info("EventConsumer starting subscription")
        subscription = receiver.receive()
            .doOnNext { handle(it) }
            .doOnError { err -> log.error("Receiver stream error", err) }
            .subscribe()
    }

    @PreDestroy
    fun stop() {
        log.info(
            "EventConsumer stopping. processed={} failed={}",
            processed.get(),
            failed.get(),
        )
        subscription?.dispose()
    }

    private fun handle(record: ReceiverRecord<String, String>) {
        try {
            val event = objectMapper.readValue(record.value(), PipelineEvent::class.java)
            log.info(
                "Consumed event id={} userId={} type={} partition={} offset={}",
                event.id,
                event.userId,
                event.eventType,
                record.partition(),
                record.offset(),
            )
            // Manual ack only after successful handling — at-least-once semantics
            record.receiverOffset().acknowledge()
            processed.incrementAndGet()
        } catch (ex: Exception) {
            failed.incrementAndGet()
            log.error(
                "Failed to handle record key={} partition={} offset={}",
                record.key(),
                record.partition(),
                record.offset(),
                ex,
            )
            // For now: ack anyway to avoid infinite retry. W2 후반에 DLQ 추가
            record.receiverOffset().acknowledge()
        }
    }

    fun stats(): Map<String, Long> = mapOf(
        "processed" to processed.get(),
        "failed" to failed.get(),
    )
}
