package com.leejx.eventpipeline.consumer.enrichment

import com.leejx.eventpipeline.enrichment.v1.EnrichmentServiceGrpc
import com.leejx.eventpipeline.enrichment.v1.GetUserEnrichmentRequest
import com.leejx.eventpipeline.enrichment.v1.GetUserEnrichmentResponse
import com.leejx.eventpipeline.enrichment.v1.UserEnrichment
import io.grpc.StatusRuntimeException
import net.devh.boot.grpc.client.inject.GrpcClient
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import reactor.core.publisher.Mono
import reactor.core.scheduler.Schedulers

/**
 * Wraps the generated gRPC blocking stub so it slots into Reactor pipelines.
 *
 * Failure policy: if enrichment is unavailable (network, server down, timeout),
 * we return an "unknown" placeholder rather than failing the whole event.
 * This keeps the consumer running in degraded mode — the event is still
 * persisted, just without enrichment data attached. Downstream alerts on
 * elevated `enrichment_unavailable` counter would catch sustained outages.
 */
@Component
class EnrichmentClient(
    @GrpcClient("enrichment")
    private val stub: EnrichmentServiceGrpc.EnrichmentServiceBlockingStub,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    fun lookup(userId: String): Mono<EnrichmentResult> =
        Mono.fromCallable {
            val req = GetUserEnrichmentRequest.newBuilder().setUserId(userId).build()
            val resp: GetUserEnrichmentResponse = stub.getUserEnrichment(req)
            EnrichmentResult(
                enrichment = resp.enrichment,
                cacheHit = resp.cacheHit,
                available = true,
            )
        }
            // gRPC blocking stub must not run on the reactor thread
            .subscribeOn(Schedulers.boundedElastic())
            .onErrorResume(StatusRuntimeException::class.java) { ex ->
                log.warn("Enrichment gRPC call failed for {}: {}", userId, ex.status, ex)
                Mono.just(EnrichmentResult.unavailable())
            }
            .onErrorResume(Exception::class.java) { ex ->
                log.warn("Enrichment lookup failed for {}", userId, ex)
                Mono.just(EnrichmentResult.unavailable())
            }
}

data class EnrichmentResult(
    val enrichment: UserEnrichment,
    val cacheHit: Boolean,
    val available: Boolean,
) {
    companion object {
        fun unavailable(): EnrichmentResult = EnrichmentResult(
            enrichment = UserEnrichment.getDefaultInstance(),
            cacheHit = false,
            available = false,
        )
    }
}
