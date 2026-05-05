package com.leejx.eventpipeline.enrichment.service

import com.fasterxml.jackson.databind.ObjectMapper
import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import org.slf4j.LoggerFactory
import org.springframework.data.redis.core.ReactiveStringRedisTemplate
import org.springframework.stereotype.Repository
import reactor.core.publisher.Mono
import java.time.Duration

/**
 * Loads UserEnrichment data with Redis as cache-aside.
 *
 * Behavior:
 * 1. Redis GET — return immediately on hit
 * 2. Redis miss → PostgreSQL user_metadata lookup
 * 3. DB hit → async Redis write-back with 1h TTL
 * 4. DB miss → deterministic synthetic fallback, also cached
 *
 * Redis/cache failures never fail the lookup. DB failures fall back to synthetic
 * data so enrichment stays available in degraded mode.
 */
@Repository
class UserEnrichmentRepository(
    private val redis: ReactiveStringRedisTemplate,
    private val objectMapper: ObjectMapper,
    private val userMetadataRepository: UserMetadataRepository,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    fun findByUserId(userId: String): Mono<EnrichmentLookupResult> {
        val key = cacheKey(userId)
        return redis.opsForValue().get(key)
            .map { json -> EnrichmentLookupResult(deserialize(json), cacheHit = true) }
            .doOnError { err -> log.warn("Redis read failed for {}", userId, err) }
            .onErrorResume { Mono.empty() }
            .switchIfEmpty(Mono.defer { loadFromDbOrFallbackAndCache(userId, key) })
    }

    private fun loadFromDbOrFallbackAndCache(userId: String, key: String): Mono<EnrichmentLookupResult> =
        userMetadataRepository.findByUserId(userId)
            .doOnNext { log.debug("User metadata DB hit for {}", userId) }
            .onErrorResume { err ->
                log.warn("User metadata DB lookup failed for {}. Falling back to synthetic enrichment", userId, err)
                Mono.empty()
            }
            .switchIfEmpty(Mono.fromCallable { synthesizeFor(userId) })
            .flatMap { enrichment -> cacheAndReturn(key, userId, enrichment) }

    private fun cacheAndReturn(
        key: String,
        userId: String,
        enrichment: UserEnrichment,
    ): Mono<EnrichmentLookupResult> = redis.opsForValue()
        .set(key, serialize(enrichment), CACHE_TTL)
        .doOnError { err -> log.warn("Failed to cache enrichment for {}", userId, err) }
        .onErrorResume { Mono.just(true) }
        .map { EnrichmentLookupResult(enrichment, cacheHit = false) }

    private fun synthesizeFor(userId: String): UserEnrichment {
        val hash = userId.hashCode()
        val countries = listOf("KR", "US", "JP", "DE", "FR")
        val tiers = listOf("basic", "premium", "enterprise")
        return UserEnrichment.newBuilder()
            .setFound(true)
            .setCountry(countries[Math.floorMod(hash, countries.size)])
            .setTier(tiers[Math.floorMod(hash, tiers.size)])
            .setSignupUnixMs(SIGNUP_BASELINE + Math.floorMod(hash, (365L * 24 * 3600 * 1000).toInt()))
            .addAllTags(if (hash % 2 == 0) listOf("a", "b") else listOf("c"))
            .build()
    }

    private fun serialize(enrichment: UserEnrichment): String =
        objectMapper.writeValueAsString(enrichment.toJsonMap())

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
