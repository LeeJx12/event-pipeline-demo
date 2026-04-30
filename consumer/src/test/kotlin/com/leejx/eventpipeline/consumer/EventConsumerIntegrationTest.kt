package com.leejx.eventpipeline.consumer

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.consumer.service.EventConsumer
import org.apache.kafka.clients.producer.KafkaProducer
import org.apache.kafka.clients.producer.ProducerConfig
import org.apache.kafka.clients.producer.ProducerRecord
import org.apache.kafka.common.serialization.StringSerializer
import org.awaitility.Awaitility
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.kafka.ConfluentKafkaContainer
import org.testcontainers.utility.DockerImageName
import java.time.Duration
import java.util.UUID

@SpringBootTest
class EventConsumerIntegrationTest {

    @Autowired
    private lateinit var consumer: EventConsumer

    @Autowired
    private lateinit var objectMapper: ObjectMapper

    @Test
    fun `consumer processes a message published to the events topic`() {
        val baseline = consumer.stats()["processed"] ?: 0L

        val payload = mapOf(
            "id" to UUID.randomUUID().toString(),
            "user_id" to "u-1",
            "event_type" to "order.created",
            "occurred_at" to "2026-04-30T00:00:00Z",
            "ingested_at" to "2026-04-30T00:00:01Z",
            "payload" to mapOf("amount" to 1000),
        )
        publish("events", "u-1", objectMapper.writeValueAsString(payload))

        Awaitility.await()
            .atMost(Duration.ofSeconds(15))
            .pollInterval(Duration.ofMillis(200))
            .untilAsserted {
                val now = consumer.stats()["processed"] ?: 0L
                assertTrue(now > baseline, "expected processed count to increase past $baseline")
            }
    }

    private fun publish(topic: String, key: String, value: String) {
        val props = mapOf<String, Any>(
            ProducerConfig.BOOTSTRAP_SERVERS_CONFIG to KAFKA.bootstrapServers,
            ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG to StringSerializer::class.java,
            ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG to StringSerializer::class.java,
        )
        KafkaProducer<String, String>(props).use { p ->
            p.send(ProducerRecord(topic, key, value)).get()
        }
    }

    companion object {
        @JvmStatic
        private val KAFKA: ConfluentKafkaContainer = ConfluentKafkaContainer(
            DockerImageName.parse("confluentinc/cp-kafka:7.7.1")
        ).also { it.start() }

        @JvmStatic
        @DynamicPropertySource
        fun overrideProperties(registry: DynamicPropertyRegistry) {
            registry.add("app.kafka.bootstrap-servers") { KAFKA.bootstrapServers }
        }
    }
}
