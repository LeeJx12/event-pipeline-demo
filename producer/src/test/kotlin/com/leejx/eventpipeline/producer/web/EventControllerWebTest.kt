package com.leejx.eventpipeline.producer.web

import com.leejx.eventpipeline.producer.domain.IncomingEvent
import com.leejx.eventpipeline.producer.domain.PipelineEvent
import com.leejx.eventpipeline.producer.service.EventPublisher
import com.ninjasquad.springmockk.MockkBean
import io.mockk.every
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.reactive.AutoConfigureWebTestClient
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.reactive.server.WebTestClient
import reactor.core.publisher.Mono

/**
 * Web layer test for EventController. Uses full SpringBootTest so that the
 * controller, its dependencies, and the GlobalExceptionHandler are all
 * registered through normal component scanning.
 *
 * EventPublisher is replaced with a MockkBean so we don't need a real Kafka
 * broker for these tests.
 */
@SpringBootTest
@AutoConfigureWebTestClient
@TestPropertySource(properties = ["app.kafka.bootstrap-servers=dummy:9092"])
class EventControllerWebTest {

    @Autowired
    private lateinit var client: WebTestClient

    @MockkBean
    private lateinit var publisher: EventPublisher

    @Test
    fun `valid request returns 202 Accepted with assigned id`() {
        val incoming = IncomingEvent(userId = "u-1", eventType = "order.created")
        val published = PipelineEvent.from(incoming)
        every { publisher.publish(any()) } returns Mono.just(published)

        client.post().uri("/v1/events")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(mapOf("user_id" to "u-1", "event_type" to "order.created"))
            .exchange()
            .expectStatus().isAccepted
            .expectBody()
            .jsonPath("$.id").isEqualTo(published.id)
            .jsonPath("$.ingestedAt").exists()
    }

    @Test
    fun `missing user_id returns 400`() {
        // Missing required field fails Jackson deserialization before bean
        // validation runs, surfacing as ServerWebInputException → "bad_request".
        client.post().uri("/v1/events")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(mapOf("event_type" to "order.created"))
            .exchange()
            .expectStatus().isBadRequest
            .expectBody()
            .jsonPath("$.error").isEqualTo("bad_request")
    }

    @Test
    fun `blank event_type returns 400`() {
        client.post().uri("/v1/events")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(mapOf("user_id" to "u-1", "event_type" to ""))
            .exchange()
            .expectStatus().isBadRequest
            .expectBody()
            .jsonPath("$.error").isEqualTo("validation_failed")
    }

    @Test
    fun `malformed JSON returns 400`() {
        client.post().uri("/v1/events")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue("{not json}")
            .exchange()
            .expectStatus().isBadRequest
            .expectBody()
            .jsonPath("$.error").isEqualTo("bad_request")
    }

    @Test
    fun `publisher exception returns 500`() {
        every { publisher.publish(any()) } returns Mono.error(RuntimeException("kafka down"))

        client.post().uri("/v1/events")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(mapOf("user_id" to "u-1", "event_type" to "x"))
            .exchange()
            .expectStatus().isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR)
            .expectBody()
            .jsonPath("$.error").isEqualTo("internal_error")
    }
}