package com.leejx.eventpipeline.enrichment.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.springframework.data.redis.core.ReactiveStringRedisTemplate
import org.springframework.data.redis.core.ReactiveValueOperations
import reactor.core.publisher.Mono
import java.time.Duration

class UserEnrichmentRepositoryTest {
    private val redis = mockk<ReactiveStringRedisTemplate>()
    private val valueOps = mockk<ReactiveValueOperations<String, String>>()
    private val db = mockk<UserMetadataRepository>()
    private val objectMapper = ObjectMapper()
    private val repo = UserEnrichmentRepository(redis, objectMapper, db)

    init {
        every { redis.opsForValue() } returns valueOps
    }

    @Test
    fun `cache hit returns enrichment from redis without db lookup`() {
        val cached = """{"found":true,"country":"KR","tier":"premium","signupUnixMs":1700000000000,"tags":["a","b"]}"""
        every { valueOps.get("enrichment:user:u-1") } returns Mono.just(cached)

        val result = repo.findByUserId("u-1").block(Duration.ofSeconds(2)) ?: error("null result")

        assertTrue(result.cacheHit)
        assertEquals("KR", result.enrichment.country)
        assertEquals("premium", result.enrichment.tier)
        verify(exactly = 0) { db.findByUserId(any<String>()) }
        verify(exactly = 0) { valueOps.set(any<String>(), any<String>(), any<Duration>()) }
    }

    @Test
    fun `cache miss loads from db and writes back to redis`() {
        val enrichment = UserEnrichment.newBuilder()
            .setFound(true)
            .setCountry("US")
            .setTier("premium")
            .setSignupUnixMs(1704067200000)
            .addAllTags(listOf("order-heavy", "ios"))
            .build()

        every { valueOps.get("enrichment:user:u-1") } returns Mono.empty()
        every { db.findByUserId("u-1") } returns Mono.just(enrichment)
        every { valueOps.set("enrichment:user:u-1", any<String>(), any<Duration>()) } returns Mono.just(true)

        val result = repo.findByUserId("u-1").block(Duration.ofSeconds(2)) ?: error("null result")

        assertFalse(result.cacheHit)
        assertEquals("US", result.enrichment.country)
        assertEquals("premium", result.enrichment.tier)
        verify(exactly = 1) { db.findByUserId("u-1") }
        verify(exactly = 1) { valueOps.set("enrichment:user:u-1", any<String>(), Duration.ofHours(1)) }
    }

    @Test
    fun `db miss synthesizes fallback and writes back to redis`() {
        every { valueOps.get("enrichment:user:u-404") } returns Mono.empty()
        every { db.findByUserId("u-404") } returns Mono.empty()
        every { valueOps.set("enrichment:user:u-404", any<String>(), any<Duration>()) } returns Mono.just(true)

        val result = repo.findByUserId("u-404").block(Duration.ofSeconds(2)) ?: error("null result")

        assertFalse(result.cacheHit)
        assertTrue(result.enrichment.found)
        verify(exactly = 1) { db.findByUserId("u-404") }
        verify(exactly = 1) { valueOps.set("enrichment:user:u-404", any<String>(), Duration.ofHours(1)) }
    }

    @Test
    fun `cache write failure does not fail the lookup`() {
        every { valueOps.get(any<String>()) } returns Mono.empty()
        every { db.findByUserId(any<String>()) } returns Mono.empty()
        every { valueOps.set(any<String>(), any<String>(), any<Duration>()) } returns Mono.error<Boolean>(RuntimeException("redis down"))

        val result = repo.findByUserId("u-3").block(Duration.ofSeconds(2)) ?: error("null result")

        assertFalse(result.cacheHit)
        assertTrue(result.enrichment.found)
    }
}
