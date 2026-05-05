package com.leejx.eventpipeline.enrichment.grpc

import com.leejx.eventpipeline.enrichment.service.UserEnrichmentRepository
import com.leejx.eventpipeline.enrichment.v1.BatchGetUserEnrichmentRequest
import com.leejx.eventpipeline.enrichment.v1.BatchGetUserEnrichmentResponse
import com.leejx.eventpipeline.enrichment.v1.EnrichmentServiceGrpc
import com.leejx.eventpipeline.enrichment.v1.GetUserEnrichmentRequest
import com.leejx.eventpipeline.enrichment.v1.GetUserEnrichmentResponse
import io.grpc.stub.StreamObserver
import net.devh.boot.grpc.server.service.GrpcService
import org.slf4j.LoggerFactory
import reactor.core.publisher.Flux
import reactor.core.publisher.Mono

/**
 * gRPC entry point. Bridges synchronous StreamObserver callbacks into the
 * Reactor-based UserEnrichmentRepository.
 *
 * Both unary and batch calls share the same lookup path; the batch variant
 * just fans out requests in parallel and reassembles responses in input order.
 */
@GrpcService
class EnrichmentGrpcService(
    private val repository: UserEnrichmentRepository,
) : EnrichmentServiceGrpc.EnrichmentServiceImplBase() {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun getUserEnrichment(
        request: GetUserEnrichmentRequest,
        responseObserver: StreamObserver<GetUserEnrichmentResponse>,
    ) {
        repository.findByUserId(request.userId)
            .map { result ->
                GetUserEnrichmentResponse.newBuilder()
                    .setUserId(request.userId)
                    .setEnrichment(result.enrichment)
                    .setCacheHit(result.cacheHit)
                    .build()
            }
            .subscribe(
                { resp ->
                    responseObserver.onNext(resp)
                    responseObserver.onCompleted()
                },
                { err ->
                    log.error("Lookup failed for {}", request.userId, err)
                    responseObserver.onError(err)
                },
            )
    }

    override fun batchGetUserEnrichment(
        request: BatchGetUserEnrichmentRequest,
        responseObserver: StreamObserver<BatchGetUserEnrichmentResponse>,
    ) {
        val userIds = request.userIdsList
        if (userIds.isEmpty()) {
            responseObserver.onNext(BatchGetUserEnrichmentResponse.getDefaultInstance())
            responseObserver.onCompleted()
            return
        }

        Flux.fromIterable(userIds)
            .flatMapSequential { id ->
                repository.findByUserId(id)
                    .map { result ->
                        GetUserEnrichmentResponse.newBuilder()
                            .setUserId(id)
                            .setEnrichment(result.enrichment)
                            .setCacheHit(result.cacheHit)
                            .build()
                    }
            }
            .collectList()
            .map { results ->
                BatchGetUserEnrichmentResponse.newBuilder()
                    .addAllResults(results)
                    .build()
            }
            .subscribe(
                { resp ->
                    responseObserver.onNext(resp)
                    responseObserver.onCompleted()
                },
                { err ->
                    log.error("Batch lookup failed (size={})", userIds.size, err)
                    responseObserver.onError(err)
                },
            )
    }
}
