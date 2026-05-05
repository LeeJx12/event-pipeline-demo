package com.leejx.eventpipeline.enrichment.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import org.slf4j.LoggerFactory
import org.springframework.data.redis.core.ReactiveStringRedisTemplate
import org.springframework.stereotype.Repository
import reactor.core.publisher.Mono
import java.time.Duration

/**
 * Loads UserEnrichment data with Redis as the primary cache.
 *
 * Behavior:
 *   1. Attempt Redis GET — return on hit
 *   2. On miss, synthesize a deterministic UserEnrichment from the userId
 *      (this stands in for a future RDS lookup; W2 후반 / W3 에 RDS 도입 예정)
 *   3. Asynchronously cache the synthesized record with a 1-hour TTL
 *
 * The cache key namespace `enrichment:user:{userId}` keeps prefix scans cheap.
 */
@Repository
class UserEnrichmentRepository(
    private val redis: ReactiveStringRedisTemplate,
    private val objectMapper: ObjectMapper,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    fun findByUserId(userId: String): Mono<EnrichmentLookupResult> {
        val key = cacheKey(userId)
        return redis.opsForValue().get(key)
            .map { json -> EnrichmentLookupResult(deserialize(json), cacheHit = true) }
            .switchIfEmpty(loadAndCache(userId, key))
    }

    private fun loadAndCache(userId: String, key: String): Mono<EnrichmentLookupResult> =
        Mono.fromCallable { synthesizeFor(userId) }
            .flatMap { enrichment ->
                redis.opsForValue()
                    .set(key, serialize(enrichment), CACHE_TTL)
                    .doOnError { err -> log.warn("Failed to cache enrichment for {}", userId, err) }
                    .onErrorResume { Mono.just(true) }
                    .map { EnrichmentLookupResult(enrichment, cacheHit = false) }
            }

    private fun synthesizeFor(userId: String): UserEnrichment {
        // Deterministic stub. Replace with RDS lookup later.
        // Using userId hash so the same input yields the same output every time.
        val hash = userId.hashCode()
        val countries = listOf("KR", "US", "JP", "DE", "FR")
        val tiers = listOf("basic", "premium", "enterprise")
        return UserEnrichment.newBuilder()
            .setFound(true)
            .setCountry(countries[Math.floorMod(hash, countries.size)])
            .setTier(tiers[Math.floorMod(hash, tiers.size)])
            .setSignupUnixMs(SIGNUP_BASELINE + Math.floorMod(hash, 365L * 24 * 3600 * 1000))
            .addAllTags(if (hash % 2 == 0) listOf("a", "b") else listOf("c"))
            .build()
    }

    private fun serialize(enrichment: UserEnrichment): String {
        // Persist as JSON for human-debuggability in redis-cli.
        // Protobuf binary would be smaller but inscrutable on the wire.
        return objectMapper.writeValueAsString(enrichment.toJsonMap())
    }

    private fun deserialize(json: String): UserEnrichment {
        @Suppress("UNCHECKED_CAST")
        val m = objectMapper.readValue(json, Map::class.java) as Map<String, Any?>
        return UserEnrichment.newBuilder()
            .setFound(m["found"] as? Boolean ?: false)
            .setCountry(m["country"] as? String ?: "")
            .setTier(m["tier"] as? String ?: "")
            .setSignupUnixMs((m["signupUnixMs"] as? Number)?.toLong() ?: 0L)
            .addAllTags((m["tags"] as? List<*>)?.filterIsInstance<String>() ?: emptyList())
            .build()
    }

    private fun UserEnrichment.toJsonMap(): Map<String, Any?> = mapOf(
        "found" to found,
        "country" to country,
        "tier" to tier,
        "signupUnixMs" to signupUnixMs,
        "tags" to tagsList,
    )

    private fun cacheKey(userId: String) = "enrichment:user:$userId"

    companion object {
        private val CACHE_TTL: Duration = Duration.ofHours(1)
        private const val SIGNUP_BASELINE = 1_700_000_000_000L // late 2023
    }
}

data class EnrichmentLookupResult(
    val enrichment: UserEnrichment,
    val cacheHit: Boolean,
)
