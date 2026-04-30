package com.leejx.eventpipeline.producer.web

import com.leejx.eventpipeline.producer.domain.IncomingEvent
import com.leejx.eventpipeline.producer.domain.PipelineEvent
import com.leejx.eventpipeline.producer.service.EventPublisher
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import reactor.core.publisher.Mono

@RestController
@RequestMapping("/v1/events")
class EventController(
    private val publisher: EventPublisher,
) {

    /**
     * Accept a single event. Returns 202 Accepted with the assigned event id once
     * the message has been successfully published to Kafka.
     */
    @PostMapping
    fun ingest(@Valid @RequestBody body: IncomingEvent): Mono<ResponseEntity<EventAccepted>> =
        publisher.publish(body)
            .map { event -> ResponseEntity.status(HttpStatus.ACCEPTED).body(EventAccepted.from(event)) }
}

data class EventAccepted(val id: String, val ingestedAt: String) {
    companion object {
        fun from(event: PipelineEvent): EventAccepted =
            EventAccepted(id = event.id, ingestedAt = event.ingestedAt.toString())
    }
}
