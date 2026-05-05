package com.leejx.eventpipeline.enrichment.service

import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import org.springframework.r2dbc.core.DatabaseClient
import org.springframework.stereotype.Repository
import reactor.core.publisher.Mono

@Repository
class UserMetadataRepository(
    private val databaseClient: DatabaseClient,
) {
    fun findByUserId(userId: String): Mono<UserEnrichment> = databaseClient
        .sql(
            """
            SELECT user_id, country, tier, signup_unix_ms, tags
            FROM user_metadata
            WHERE user_id = :userId
            """.trimIndent(),
        )
        .bind("userId", userId)
        .map { row, _ ->
            val tags = when (val raw = row.get("tags")) {
                is Array<*> -> raw.filterIsInstance<String>()
                is Collection<*> -> raw.filterIsInstance<String>()
                else -> emptyList()
            }

            UserEnrichment.newBuilder()
                .setFound(true)
                .setCountry(row.get("country", String::class.java) ?: "")
                .setTier(row.get("tier", String::class.java) ?: "")
                .setSignupUnixMs(row.get("signup_unix_ms", java.lang.Long::class.java)?.toLong() ?: 0L)
                .addAllTags(tags)
                .build()
        }
        .one()
}
