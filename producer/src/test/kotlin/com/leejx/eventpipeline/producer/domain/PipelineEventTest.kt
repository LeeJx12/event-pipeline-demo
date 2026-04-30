package com.leejx.eventpipeline.producer.domain

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Test
import java.time.Instant

class PipelineEventTest {

    @Test
    fun `from() copies user id and event type from incoming`() {
        val incoming = IncomingEvent(
            userId = "user-1",
            eventType = "order.created",
            payload = mapOf("amount" to 1000),
        )

        val event = PipelineEvent.from(incoming)

        assertEquals("user-1", event.userId)
        assertEquals("order.created", event.eventType)
        assertEquals(mapOf("amount" to 1000), event.payload)
    }

    @Test
    fun `from() generates a unique id every call`() {
        val incoming = IncomingEvent(userId = "u", eventType = "e")

        val ids = (1..5).map { PipelineEvent.from(incoming).id }.toSet()

        assertEquals(5, ids.size, "every invocation must produce a unique id")
    }

    @Test
    fun `from() defaults occurredAt to ingestedAt when client did not supply it`() {
        val now = Instant.parse("2026-04-26T12:00:00Z")
        val incoming = IncomingEvent(userId = "u", eventType = "e", occurredAt = null)

        val event = PipelineEvent.from(incoming, now)

        assertEquals(now, event.occurredAt)
        assertEquals(now, event.ingestedAt)
    }

    @Test
    fun `from() preserves client-supplied occurredAt distinct from ingestedAt`() {
        val occurred = Instant.parse("2026-04-25T00:00:00Z")
        val ingested = Instant.parse("2026-04-26T12:00:00Z")
        val incoming = IncomingEvent(userId = "u", eventType = "e", occurredAt = occurred)

        val event = PipelineEvent.from(incoming, ingested)

        assertEquals(occurred, event.occurredAt)
        assertEquals(ingested, event.ingestedAt)
        assertNotEquals(event.occurredAt, event.ingestedAt)
    }

    @Test
    fun `event id is non-blank`() {
        val event = PipelineEvent.from(IncomingEvent(userId = "u", eventType = "e"))
        assertNotNull(event.id)
        assert(event.id.isNotBlank())
    }
}
