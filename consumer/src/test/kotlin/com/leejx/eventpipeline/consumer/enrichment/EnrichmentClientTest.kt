package com.leejx.eventpipeline.consumer.enrichment

import com.leejx.eventpipeline.enrichment.v1.EnrichmentServiceGrpc
import com.leejx.eventpipeline.enrichment.v1.GetUserEnrichmentRequest
import com.leejx.eventpipeline.enrichment.v1.GetUserEnrichmentResponse
import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import io.grpc.Status
import io.grpc.StatusRuntimeException
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import java.time.Duration

class EnrichmentClientTest {

    private val stub = mockk<EnrichmentServiceGrpc.EnrichmentServiceBlockingStub>()
    private val client = EnrichmentClient(stub)

    @Test
    fun `successful gRPC call returns enrichment with cacheHit flag`() {
        every { stub.getUserEnrichment(any<GetUserEnrichmentRequest>()) } returns
            GetUserEnrichmentResponse.newBuilder()
                .setUserId("u-1")
                .setEnrichment(
                    UserEnrichment.newBuilder()
                        .setFound(true)
                        .setCountry("KR")
                        .setTier("premium")
                        .build()
                )
                .setCacheHit(true)
                .build()

        val result = client.lookup("u-1").block(Duration.ofSeconds(2))!!

        assertTrue(result.available)
        assertTrue(result.cacheHit)
        assertEquals("KR", result.enrichment.country)
        assertEquals("premium", result.enrichment.tier)
    }

    @Test
    fun `gRPC StatusRuntimeException degrades to unavailable`() {
        every { stub.getUserEnrichment(any<GetUserEnrichmentRequest>()) } throws
            StatusRuntimeException(Status.UNAVAILABLE.withDescription("server down"))

        val result = client.lookup("u-2").block(Duration.ofSeconds(2))!!

        assertFalse(result.available)
        assertFalse(result.cacheHit)
        assertEquals(UserEnrichment.getDefaultInstance(), result.enrichment)
    }

    @Test
    fun `generic runtime exception also degrades to unavailable`() {
        every { stub.getUserEnrichment(any<GetUserEnrichmentRequest>()) } throws
            RuntimeException("unexpected failure")

        val result = client.lookup("u-3").block(Duration.ofSeconds(2))!!

        assertFalse(result.available)
    }

    @Test
    fun `lookup forwards correct userId in request`() {
        every { stub.getUserEnrichment(any<GetUserEnrichmentRequest>()) } returns
            GetUserEnrichmentResponse.getDefaultInstance()

        client.lookup("user-abc").block(Duration.ofSeconds(2))

        verify {
            stub.getUserEnrichment(
                match<GetUserEnrichmentRequest> { it.userId == "user-abc" }
            )
        }
    }
}
