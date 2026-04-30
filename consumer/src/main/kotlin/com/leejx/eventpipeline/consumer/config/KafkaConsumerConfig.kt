package com.leejx.eventpipeline.consumer.config

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import com.fasterxml.jackson.module.kotlin.kotlinModule
import org.apache.kafka.clients.consumer.ConsumerConfig
import org.apache.kafka.common.serialization.StringDeserializer
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import reactor.kafka.receiver.KafkaReceiver
import reactor.kafka.receiver.ReceiverOptions

@Configuration
class KafkaConsumerConfig {

    @Value("\${app.kafka.bootstrap-servers}")
    private lateinit var bootstrapServers: String

    @Value("\${app.kafka.group-id}")
    private lateinit var groupId: String

    @Value("\${app.kafka.topic}")
    private lateinit var topic: String

    /**
     * Explicit ObjectMapper bean. Without spring-boot-starter-web/webflux,
     * Jackson autoconfiguration is not triggered, so we register one here.
     * Includes JavaTime + Kotlin modules so PipelineEvent (with Instant +
     * Kotlin data class) deserializes correctly.
     */
    @Bean
    fun objectMapper(): ObjectMapper =
        ObjectMapper()
            .registerModule(kotlinModule())
            .registerModule(JavaTimeModule())

    /**
     * KafkaReceiver tuned for at-least-once with manual ack.
     *   - max.poll.records: small enough to process in one cycle but big enough to amortize overhead
     *   - session.timeout: 10s — fast detection of dead consumers in EKS
     *   - auto.offset.reset=earliest: replay from start on a fresh group
     */
    @Bean
    fun kafkaReceiver(): KafkaReceiver<String, String> {
        val props = mapOf<String, Any>(
            ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG to bootstrapServers,
            ConsumerConfig.GROUP_ID_CONFIG to groupId,
            ConsumerConfig.AUTO_OFFSET_RESET_CONFIG to "earliest",
            ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG to false,
            ConsumerConfig.MAX_POLL_RECORDS_CONFIG to 500,
            ConsumerConfig.SESSION_TIMEOUT_MS_CONFIG to 10_000,
            ConsumerConfig.HEARTBEAT_INTERVAL_MS_CONFIG to 3_000,
            ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG to StringDeserializer::class.java,
            ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG to StringDeserializer::class.java,
        )
        val options = ReceiverOptions.create<String, String>(props)
            .subscription(setOf(topic))
        return KafkaReceiver.create(options)
    }
}
