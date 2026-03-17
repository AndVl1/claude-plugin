---
name: error-recovery
description: Error recovery patterns for resilient LLM-powered applications - use when handling API failures, implementing retries, or building fault-tolerant agents
---

# Error Recovery Skill

Build resilient LLM-powered applications with systematic error handling, retry strategies, and fallback mechanisms.

## When to Use

- LLM API calls failing intermittently
- Building fault-tolerant agents
- Implementing retry logic for external services
- Handling rate limits and timeouts
- Creating graceful degradation strategies

## Error Classification

### Error Types

```kotlin
enum class ErrorType {
    TRANSIENT,      // Temporary - retry may succeed
    RATE_LIMIT,     // Throttling - wait and retry
    INVALID_INPUT,  // Bad request - don't retry
    AUTH_FAILED,    // Auth error - fix credentials
    MODEL_ERROR,    // Model issue - try alternative
    TIMEOUT,        // Request timeout - retry with backoff
    NETWORK_ERROR,  // Connection issue - retry
    QUOTA_EXCEEDED, // Usage limit - wait or upgrade
    UNKNOWN         // Unclassified - log and handle
}
```

### Classification Rules

```kotlin
fun classifyError(error: Exception): ErrorType = when (error) {
    is SocketTimeoutException -> ErrorType.TIMEOUT
    is UnknownHostException -> ErrorType.NETWORK_ERROR
    is HttpException -> when (error.code()) {
        429 -> ErrorType.RATE_LIMIT
        401, 403 -> ErrorType.AUTH_FAILED
        400 -> ErrorType.INVALID_INPUT
        500, 502, 503 -> ErrorType.MODEL_ERROR
        else -> ErrorType.UNKNOWN
    }
    else -> ErrorType.UNKNOWN
}
```

## Retry Strategies

### 1. Exponential Backoff

```kotlin
suspend fun <T> withExponentialBackoff(
    maxRetries: Int = 3,
    initialDelay: Long = 1000,
    maxDelay: Long = 30000,
    factor: Double = 2.0,
    block: suspend () -> T
): T {
    var currentDelay = initialDelay
    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: Exception) {
            if (attempt == maxRetries - 1) throw e
            if (!isRetryable(e)) throw e
            
            delay(currentDelay)
            currentDelay = (currentDelay * factor).toLong().coerceAtMost(maxDelay)
        }
    }
    throw IllegalStateException("Should not reach here")
}
```

### 2. Jittered Backoff

```kotlin
suspend fun <T> withJitteredBackoff(
    maxRetries: Int = 3,
    baseDelay: Long = 1000,
    maxDelay: Long = 30000,
    block: suspend () -> T
): T {
    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: Exception) {
            if (attempt == maxRetries - 1) throw e
            if (!isRetryable(e)) throw e
            
            // Add random jitter (50-150% of calculated delay)
            val baseWait = baseDelay * (1 shl attempt)
            val jitter = baseWait * (0.5 + Random.nextDouble())
            delay(jitter.toLong().coerceAtMost(maxDelay))
        }
    }
    throw IllegalStateException("Should not reach here")
}
```

### 3. Circuit Breaker

```kotlin
class CircuitBreaker(
    private val failureThreshold: Int = 5,
    private val resetTimeout: Long = 60000
) {
    private var failures = 0
    private var lastFailureTime = 0L
    private var state = State.CLOSED
    
    enum class State { CLOSED, OPEN, HALF_OPEN }
    
    suspend fun <T> execute(block: suspend () -> T): T {
        if (state == State.OPEN) {
            if (System.currentTimeMillis() - lastFailureTime > resetTimeout) {
                state = State.HALF_OPEN
            } else {
                throw CircuitBreakerOpenException()
            }
        }
        
        return try {
            val result = block()
            onSuccess()
            result
        } catch (e: Exception) {
            onFailure()
            throw e
        }
    }
    
    private fun onSuccess() {
        failures = 0
        state = State.CLOSED
    }
    
    private fun onFailure() {
        failures++
        lastFailureTime = System.currentTimeMillis()
        if (failures >= failureThreshold) {
            state = State.OPEN
        }
    }
}
```

## Fallback Mechanisms

### 1. Model Fallback Chain

```kotlin
class LLMFallbackChain(
    private val models: List<String> = listOf(
        "deepseek/deepseek-chat",
        "qwen/qwen-2.5-72b-instruct",
        "anthropic/claude-3-haiku"
    )
) {
    suspend fun complete(prompt: String): String {
        val errors = mutableListOf<Exception>()
        
        for (model in models) {
            try {
                return callModel(model, prompt)
            } catch (e: Exception) {
                errors.add(e)
                log.warn("Model $model failed: ${e.message}")
            }
        }
        
        throw AllModelsFailedException("All models failed", errors)
    }
}
```

### 2. Cached Response Fallback

```kotlin
class CachedFallback<T>(
    private val cache: Cache<String, T>,
    private val ttl: Long = 3600000 // 1 hour
) {
    suspend fun getOrFallback(key: String, fetch: suspend () -> T): T {
        val cached = cache.get(key)
        if (cached != null && !isExpired(cached)) {
            return cached.value
        }
        
        return try {
            val fresh = fetch()
            cache.put(key, CachedValue(fresh, System.currentTimeMillis()))
            fresh
        } catch (e: Exception) {
            if (cached != null) {
                log.warn("Using stale cache due to error: ${e.message}")
                return cached.value
            }
            throw e
        }
    }
}
```

### 3. Degraded Mode

```kotlin
class DegradedModeService(
    private val fullService: suspend () -> String,
    private val degradedService: suspend () -> String,
    private val healthCheck: suspend () -> Boolean
) {
    suspend fun execute(): String {
        return if (healthCheck()) {
            try {
                fullService()
            } catch (e: Exception) {
                log.warn("Full service failed, using degraded mode")
                degradedService()
            }
        } else {
            degradedService()
        }
    }
}
```

## Error Recovery Patterns

### Pattern 1: Retry with Classification

```kotlin
suspend fun <T> resilientCall(
    maxRetries: Int = 3,
    block: suspend () -> T
): T {
    var lastError: Exception? = null
    
    repeat(maxRetries) { attempt ->
        try {
            return block()
        } catch (e: Exception) {
            lastError = e
            val type = classifyError(e)
            
            when (type) {
                ErrorType.INVALID_INPUT,
                ErrorType.AUTH_FAILED -> throw e // Don't retry
                
                ErrorType.RATE_LIMIT -> {
                    val waitTime = extractRetryAfter(e) ?: (1000L * (attempt + 1))
                    delay(waitTime)
                }
                
                ErrorType.TIMEOUT,
                ErrorType.NETWORK_ERROR,
                ErrorType.TRANSIENT -> {
                    delay(1000L * (1 shl attempt))
                }
                
                ErrorType.MODEL_ERROR -> {
                    // Try alternative model
                    throw e
                }
                
                ErrorType.QUOTA_EXCEEDED -> {
                    throw e // Need to wait or upgrade
                }
                
                ErrorType.UNKNOWN -> {
                    if (attempt < maxRetries - 1) {
                        delay(1000L * (attempt + 1))
                    }
                }
            }
        }
    }
    
    throw lastError ?: UnknownError()
}
```

### Pattern 2: Bulkhead

```kotlin
class Bulkhead(
    private val maxConcurrent: Int = 10,
    private val maxWaitTime: Long = 5000
) {
    private val semaphore = Semaphore(maxConcurrent)
    
    suspend fun <T> execute(block: suspend () -> T): T {
        if (!semaphore.tryAcquire(maxWaitTime, TimeUnit.MILLISECONDS)) {
            throw BulkheadFullException("Too many concurrent calls")
        }
        
        return try {
            block()
        } finally {
            semaphore.release()
        }
    }
}
```

### Pattern 3: Timeout with Fallback

```kotlin
suspend fun <T> withTimeoutFallback(
    timeout: Long,
    fallback: suspend () -> T,
    block: suspend () -> T
): T {
    return try {
        withTimeout(timeout) {
            block()
        }
    } catch (e: TimeoutCancellationException) {
        log.warn("Operation timed out, using fallback")
        fallback()
    }
}
```

## Integration Examples

### Example 1: Resilient LLM Client

```kotlin
class ResilientLLMClient(
    private val apiKey: String,
    private val circuitBreaker: CircuitBreaker = CircuitBreaker(),
    private val fallbackChain: LLMFallbackChain = LLMFallbackChain()
) {
    suspend fun complete(prompt: String): String {
        return circuitBreaker.execute {
            withExponentialBackoff(maxRetries = 3) {
                fallbackChain.complete(prompt)
            }
        }
    }
}
```

### Example 2: Agent with Error Recovery

```kotlin
class ResilientAgent(
    private val llm: ResilientLLMClient,
    private val cache: Cache<String, String>
) {
    suspend fun process(input: String): String {
        val cacheKey = "agent:${input.hashCode()}"
        
        return withTimeoutFallback(
            timeout = 30000,
            fallback = { cache.get(cacheKey) ?: "Service temporarily unavailable" }
        ) {
            withCachedFallback(cacheKey) {
                resilientCall(maxRetries = 2) {
                    llm.complete(buildPrompt(input))
                }
            }
        }
    }
}
```

## Best Practices

### Do's ✅

1. **Classify errors before retrying** - Not all errors are retryable
2. **Use exponential backoff with jitter** - Prevent thundering herd
3. **Implement circuit breakers** - Fail fast when service is down
4. **Have fallback strategies** - Cache, alternative models, degraded mode
5. **Log errors with context** - Help debugging and monitoring
6. **Set reasonable timeouts** - Don't wait forever
7. **Monitor error rates** - Alert on anomalies
8. **Test failure scenarios** - Chaos engineering

### Don'ts ❌

1. **Retry on auth errors** - Won't magically fix credentials
2. **Retry indefinitely** - Set max retries
3. **Ignore rate limits** - Respect Retry-After headers
4. **Log sensitive data** - Mask API keys, user data
5. **Use fixed delays** - Causes thundering herd
6. **Skip error handling** - Always expect failures
7. **Catch all exceptions** - Be specific
8. **Hide errors from users** - Show meaningful messages

## Error Messages

### User-Facing Messages

```kotlin
fun userFriendlyMessage(error: Exception): String = when (error) {
    is TimeoutCancellationException -> 
        "Request took too long. Please try again."
    is CircuitBreakerOpenException -> 
        "Service is temporarily unavailable. Please try again later."
    is RateLimitException -> 
        "Too many requests. Please wait a moment."
    is AllModelsFailedException -> 
        "AI service is experiencing issues. Please try again."
    else -> 
        "An unexpected error occurred. Please try again."
}
```

## Monitoring & Observability

### Metrics to Track

```kotlin
class ErrorMetrics {
    val totalCalls = Counter("llm.calls.total")
    val successfulCalls = Counter("llm.calls.success")
    val failedCalls = Counter("llm.calls.failed")
    val retries = Counter("llm.retries")
    val fallbackUsed = Counter("llm.fallback.used")
    val circuitBreakerOpens = Counter("llm.circuit.opens")
    
    fun recordSuccess() {
        totalCalls.increment()
        successfulCalls.increment()
    }
    
    fun recordFailure(error: Exception) {
        totalCalls.increment()
        failedCalls.increment()
        failedCalls.label("type", classifyError(error).name).increment()
    }
}
```

### Logging Best Practices

```kotlin
fun logError(error: Exception, context: Map<String, Any>) {
    log.error(
        "LLM call failed: type=${classifyError(error)}, " +
        "message=${error.message}, " +
        "context=${context.filterKeys { it != "apiKey" }}"
    )
}
```

## Quick Reference

| Error Type | Retry? | Strategy |
|------------|--------|----------|
| TRANSIENT | ✅ | Exponential backoff |
| RATE_LIMIT | ✅ | Wait for Retry-After |
| INVALID_INPUT | ❌ | Fail fast, fix input |
| AUTH_FAILED | ❌ | Check credentials |
| MODEL_ERROR | ⚠️ | Try alternative model |
| TIMEOUT | ✅ | Retry with longer timeout |
| NETWORK_ERROR | ✅ | Exponential backoff |
| QUOTA_EXCEEDED | ❌ | Wait or upgrade plan |

## Related Skills

- **iterative-refinement** - For improving outputs through iteration
- **tool-orchestration** - For chaining tool calls with error handling
- **systematic-planning** - For planning error recovery strategies

---

*Resilient systems fail gracefully, recover quickly, and learn from errors.*
