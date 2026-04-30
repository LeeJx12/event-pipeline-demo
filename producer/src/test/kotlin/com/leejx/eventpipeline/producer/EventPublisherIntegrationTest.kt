package com.leejx.eventpipeline.producer

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.producer.config.KafkaTopics
import com.leejx.eventpipeline.producer.domain.IncomingEvent
import com.leejx.eventpipeline.producer.domain.PipelineEvent
import com.leejx.eventpipeline.producer.service.EventPublisher
import org.apache.kafka.clients.consumer.ConsumerConfig
import org.apache.kafka.clients.consumer.KafkaConsumer
import org.apache.kafka.common.serialization.StringDeserializer
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.DynamicPropertyRegistry
import org.springframework.test.context.DynamicPropertySource
import org.testcontainers.kafka.ConfluentKafkaContainer
import org.testcontainers.utility.DockerImageName
import java.time.Duration
import java.util.UUID

/**
 * Spins up a real Kafka container, sends an event through the publisher,
 * then consumes from the topic to verify the message landed with the right
 * key and payload.
 *
 * Container is started eagerly in a static initializer so it is up before
 * @DynamicPropertySource is evaluated by Spring.
 */
@SpringBootTest
class EventPublisherIntegrationTest {

    @Autowired
    private lateinit var publisher: EventPublisher

    @Autowired
    private lateinit var objectMapper: ObjectMapper

    @Test
    fun `publish lands a message on the events topic with userId as key`() {
        val incoming = IncomingEvent(
            userId = "user-${UUID.randomUUID()}",
            eventType = "order.created",
            payload = mapOf("amount" to 1000, "currency" to "KRW"),
        )

        val published = publisher.publish(incoming).block(Duration.ofSeconds(10))
            ?: error("publisher returned null")

        val consumer = newConsumer()
        consumer.use { c ->
            c.subscribe(listOf(KafkaTopics.EVENTS))
            val records = pollUntilFound(c, Duration.ofSeconds(10))
            val match = records.firstOrNull { it.key() == incoming.userId }
                ?: error("No record found with key=${incoming.userId}")

            assertEquals(incoming.userId, match.key())
            val parsed = objectMapper.readValue(match.value(), PipelineEvent::class.java)
            assertEquals(published.id, parsed.id)
            assertEquals(incoming.userId, parsed.userId)
            assertEquals(incoming.eventType, parsed.eventType)
            assertEquals(1000, parsed.payload["amount"])
            assertNotNull(parsed.ingestedAt)
        }
    }

    private fun newConsumer(): KafkaConsumer<String, String> {
        val props = mapOf<String, Any>(
            ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG to KAFKA.bootstrapServers,
            ConsumerConfig.GROUP_ID_CONFIG to "test-${UUID.randomUUID()}",
            ConsumerConfig.AUTO_OFFSET_RESET_CONFIG to "earliest",
            ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG to false,
            ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG to StringDeserializer::class.java,
            ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG to StringDeserializer::class.java,
        )
        return KafkaConsumer(props)
    }

    private fun pollUntilFound(
        consumer: KafkaConsumer<String, String>,
        timeout: Duration,
    ): List<org.apache.kafka.clients.consumer.ConsumerRecord<String, String>> {
        val deadline = System.nanoTime() + timeout.toNanos()
        val collected = mutableListOf<org.apache.kafka.clients.consumer.ConsumerRecord<String, String>>()
        while (System.nanoTime() < deadline) {
            val records = consumer.poll(Duration.ofMillis(500))
            records.forEach { collected += it }
            if (collected.isNotEmpty()) return collected
        }
        return collected
    }

    companion object {
        // Started eagerly via init block so that @DynamicPropertySource sees a running container
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
