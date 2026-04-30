package com.leejx.eventpipeline.producer.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.producer.config.KafkaTopics
import com.leejx.eventpipeline.producer.domain.IncomingEvent
import com.leejx.eventpipeline.producer.domain.PipelineEvent
import org.apache.kafka.clients.producer.ProducerRecord
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import reactor.core.publisher.Mono
import reactor.kafka.sender.KafkaSender
import reactor.kafka.sender.SenderRecord

/**
 * Publishes incoming events to Kafka. The user_id is used as the partition key
 * so all events from the same user land on the same partition (ordering guarantee).
 */
@Service
class EventPublisher(
    private val sender: KafkaSender<String, String>,
    private val objectMapper: ObjectMapper,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    fun publish(incoming: IncomingEvent): Mono<PipelineEvent> {
        val event = PipelineEvent.from(incoming)
        val payload = objectMapper.writeValueAsString(event)

        val record = ProducerRecord<String, String>(
            KafkaTopics.EVENTS,
            event.userId,
            payload,
        )

        // SenderRecord.create wraps a ProducerRecord with optional correlation metadata.
        // We pass the event id as correlation so logs can trace round-trips.
        val senderRecord = SenderRecord.create(record, event.id)

        return sender.send(Mono.just(senderRecord))
            .next()
            .doOnNext { result ->
                if (result.exception() != null) {
                    log.error("Kafka publish failed for {}", event.id, result.exception())
                } else {
                    log.debug(
                        "Published event id={} partition={} offset={}",
                        event.id,
                        result.recordMetadata().partition(),
                        result.recordMetadata().offset(),
                    )
                }
            }
            .map { event }
    }
}
