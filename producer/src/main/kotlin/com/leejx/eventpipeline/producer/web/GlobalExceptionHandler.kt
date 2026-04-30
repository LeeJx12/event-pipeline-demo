package com.leejx.eventpipeline.producer.web

import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.bind.support.WebExchangeBindException
import org.springframework.web.server.ServerWebInputException
import java.time.Instant

/**
 * Centralized error responses. Keeps the contract consistent so clients
 * (and load-test scripts) can rely on a single error shape.
 */
@RestControllerAdvice
class GlobalExceptionHandler {

    private val log = LoggerFactory.getLogger(javaClass)

    /**
     * Bean validation failures (e.g., @NotBlank on IncomingEvent fields).
     * Returns 400 with field-level details.
     */
    @ExceptionHandler(WebExchangeBindException::class)
    fun handleValidation(ex: WebExchangeBindException): ResponseEntity<ApiError> {
        val fieldErrors = ex.bindingResult.fieldErrors.map {
            FieldErrorDetail(field = it.field, message = it.defaultMessage ?: "invalid")
        }
        val body = ApiError(
            status = 400,
            error = "validation_failed",
            message = "Request body failed validation",
            details = fieldErrors,
        )
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body)
    }

    /**
     * Malformed JSON, missing required fields at deserialization, etc.
     */
    @ExceptionHandler(ServerWebInputException::class)
    fun handleBadInput(ex: ServerWebInputException): ResponseEntity<ApiError> {
        val body = ApiError(
            status = 400,
            error = "bad_request",
            message = ex.reason ?: "Malformed request",
        )
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body)
    }

    /**
     * Catch-all. Logs the original exception (so we can debug) but returns
     * a generic message to the client (no internal leakage).
     */
    @ExceptionHandler(Exception::class)
    fun handleGeneric(ex: Exception): ResponseEntity<ApiError> {
        log.error("Unhandled exception while processing request", ex)
        val body = ApiError(
            status = 500,
            error = "internal_error",
            message = "Something went wrong",
        )
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(body)
    }
}

data class ApiError(
    val timestamp: Instant = Instant.now(),
    val status: Int,
    val error: String,
    val message: String,
    val details: List<FieldErrorDetail> = emptyList(),
)

data class FieldErrorDetail(
    val field: String,
    val message: String,
)
