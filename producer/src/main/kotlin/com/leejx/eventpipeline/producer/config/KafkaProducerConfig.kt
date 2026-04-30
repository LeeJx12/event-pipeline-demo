package com.leejx.eventpipeline.producer.config

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.producer.domain.PipelineEvent
import org.apache.kafka.clients.producer.ProducerConfig
import org.apache.kafka.common.serialization.StringSerializer
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import reactor.kafka.sender.KafkaSender
import reactor.kafka.sender.SenderOptions

@Configuration
class KafkaProducerConfig {

    @Value("\${app.kafka.bootstrap-servers}")
    private lateinit var bootstrapServers: String

    @Value("\${app.kafka.client-id:event-producer}")
    private lateinit var clientId: String

    /**
     * Reactor Kafka sender. Configured for high-throughput:
     *   - acks=1 (leader ack, balances durability vs latency)
     *   - linger.ms=5 to batch sends
     *   - compression=lz4 for network efficiency
     *   - max.in.flight=5 to keep ordering per partition
     */
    @Bean
    fun kafkaSender(objectMapper: ObjectMapper): KafkaSender<String, String> {
        val props = mapOf<String, Any>(
            ProducerConfig.BOOTSTRAP_SERVERS_CONFIG to bootstrapServers,
            ProducerConfig.CLIENT_ID_CONFIG to clientId,
            ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG to StringSerializer::class.java,
            ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG to StringSerializer::class.java,
            ProducerConfig.ACKS_CONFIG to "1",
            ProducerConfig.LINGER_MS_CONFIG to 5,
            ProducerConfig.BATCH_SIZE_CONFIG to 32_768,
            ProducerConfig.COMPRESSION_TYPE_CONFIG to "lz4",
            ProducerConfig.MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION to 5,
            ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG to false, // intentionally off for throughput
        )
        val options = SenderOptions.create<String, String>(props)
        return KafkaSender.create(options)
    }
}

object KafkaTopics {
    const val EVENTS = "events"
    const val EVENTS_DLQ = "events.dlq"
}
