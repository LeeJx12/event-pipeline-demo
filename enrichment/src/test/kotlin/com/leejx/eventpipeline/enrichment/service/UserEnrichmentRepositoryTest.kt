package com.leejx.eventpipeline.enrichment.service

import com.fasterxml.jackson.databind.ObjectMapper
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
    private val objectMapper = ObjectMapper()
    private val repo = UserEnrichmentRepository(redis, objectMapper)

    init {
        every { redis.opsForValue() } returns valueOps
    }

    @Test
    fun `cache hit returns enrichment from redis without re-synthesizing`() {
        val userId = "u-1"
        val cached = """{"found":true,"country":"KR","tier":"premium","signupUnixMs":1700000000000,"tags":["a","b"]}"""
        every { valueOps.get("enrichment:user:u-1") } returns Mono.just(cached)

        val result = repo.findByUserId(userId).block(Duration.ofSeconds(2))
            ?: error("null result")

        assertTrue(result.cacheHit)
        assertEquals("KR", result.enrichment.country)
        assertEquals("premium", result.enrichment.tier)
        verify(exactly = 0) { valueOps.set(any(), any(), any<Duration>()) }
    }

    @Test
    fun `cache miss synthesizes and writes back to redis`() {
        val userId = "u-2"
        every { valueOps.get("enrichment:user:u-2") } returns Mono.empty()
        every { valueOps.set("enrichment:user:u-2", any(), any<Duration>()) } returns Mono.just(true)

        val result = repo.findByUserId(userId).block(Duration.ofSeconds(2))
            ?: error("null result")

        assertFalse(result.cacheHit)
        assertTrue(result.enrichment.found)
        verify(exactly = 1) { valueOps.set("enrichment:user:u-2", any(), Duration.ofHours(1)) }
    }

    @Test
    fun `synthesized enrichment is deterministic for the same userId`() {
        every { valueOps.get(any<String>()) } returns Mono.empty()
        every { valueOps.set(any<String>(), any(), any<Duration>()) } returns Mono.just(true)

        val a = repo.findByUserId("user-x").block(Duration.ofSeconds(2))!!.enrichment
        val b = repo.findByUserId("user-x").block(Duration.ofSeconds(2))!!.enrichment

        assertEquals(a.country, b.country)
        assertEquals(a.tier, b.tier)
        assertEquals(a.signupUnixMs, b.signupUnixMs)
    }

    @Test
    fun `cache write failure does not fail the lookup`() {
        every { valueOps.get(any<String>()) } returns Mono.empty()
        every { valueOps.set(any<String>(), any(), any<Duration>()) } returns Mono.error(RuntimeException("redis down"))

        val result = repo.findByUserId("u-3").block(Duration.ofSeconds(2))
            ?: error("null result")

        assertFalse(result.cacheHit)
        assertTrue(result.enrichment.found)
    }
}
