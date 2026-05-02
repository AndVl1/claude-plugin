---
name: beads-pattern
description: "Apply the Beads pattern (Chain of Responsibility) for skill orchestration, allowing skills to chain together with passing context. Use this skill when the user asks to: (1) create sequential skill chains, (2) implement pipeline patterns, (3) build fallback mechanisms between skills, (4) distribute tasks across multiple skills, (5) implement request/response filtering, (6) create skill middleware, or (7) design scalable skill workflows. Trigger on phrases like \"Beads pattern\", \"Chain of Responsibility\", \"skill pipeline\", \"skill chain\", \"skill fallback\", \"skill middleware\", or \"skill orchestration\"."
---

# Beads Pattern Skill

## Purpose

Implement the **Beads pattern** (also known as Chain of Responsibility) for skill orchestration, enabling flexible, composable skill chains that can be dynamically assembled and executed.

## What is Beads Pattern?

**Beads pattern** treats each skill as a "bead" in a chain that can:
- **Pass context** between skills automatically
- **Filter requests** at any point
- **Handle errors** gracefully with fallbacks
- **Execute sequentially** with clear boundaries
- **Compose dynamically** at runtime

This creates modular, maintainable skill pipelines where each skill focuses on one responsibility.

## When to Use

- **Skill Orchestration** - Need to chain multiple skills together
- **Request Filtering** - Need to filter requests at multiple stages
- **Fallback Chains** - Need graceful degradation when one skill fails
- **Task Distribution** - Need to break down tasks across multiple skills
- **Middleware Pattern** - Need to intercept and transform requests/responses
- **Dynamic Pipelines** - Need to build pipelines at runtime based on conditions
- **Scalability** - Need to add/remove skills without changing core logic

## The Beads Pattern

### Core Concept

```
Request → Bead 1 → Bead 2 → Bead 3 → ... → Response
        ↓        ↓        ↓
      Process  Process  Process
        ↓        ↓        ↓
       Context  Context  Context
```

Each bead processes the request and either:
- **Passes through**: Continues to the next bead
- **Modifies context**: Adds/updates context before passing
- **Stops**: Returns result (either success or failure)

### Bead Interface

```kotlin
/**
 * A bead in the chain of responsibility
 */
interface Bead<TContext, TRequest, TResponse> {
    /**
     * Process the request with the given context
     * Returns the next bead to use, or null to stop
     */
    suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse>

    /**
     * Get the name of this bead
     */
    val name: String

    /**
     * Optional: Log the bead's execution
     */
    suspend fun onExecute(request: TRequest, context: TContext) {
        // Override for logging/monitoring
    }
}
```

### Context Type

```kotlin
/**
 * Shared context that flows through the beads
 */
data class BeadContext(
    val requestId: String,
    val metadata: MutableMap<String, Any> = mutableMapOf(),
    val errors: MutableList<Error> = mutableListOf(),
    val startTime: Long = System.currentTimeMillis(),
    val customContext: MutableMap<String, Any> = mutableMapOf()
)

data class Error(
    val beadName: String,
    val message: String,
    val timestamp: Long = System.currentTimeMillis(),
    val cause: Throwable? = null
)

/**
 * Context with additional skill-specific data
 */
class SkillContext(
    val request: Any,
    val context: BeadContext,
    val skillRegistry: SkillRegistry
) : BeadContext by context
```

---

## Bead Types

### 1. Processing Bead

Transforms or processes the request:

```kotlin
class ValidationBead<TRequest, TContext>(
    private val validator: (TRequest) -> Result<TRequest>
) : Bead<TContext, TRequest, TRequest> {
    override val name = "Validation"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TRequest> {
        val validation = validator(request)
        return when (validation) {
            is Result.Success -> {
                context.metadata["validated"] = true
                Result.success(request)
            }
            is Result.Failure -> {
                context.errors.add(Error(name, validation.message))
                Result.failure(validation.exception)
            }
        }
    }
}
```

### 2. Filtering Bead

Filters out requests or adds conditions:

```kotlin
class FilteringBead<TRequest, TContext>(
    private val filter: (TRequest) -> Boolean,
    private val action: suspend (TRequest, TContext) -> TContext
) : Bead<TContext, TRequest, TContext> {
    override val name = "Filter"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TContext> {
        return if (filter(request)) {
            val updatedContext = action(request, context)
            Result.success(updatedContext)
        } else {
            Result.failure(NoSuchElementException("Request filtered out"))
        }
    }
}
```

### 3. Transformation Bead

Transforms the request:

```kotlin
class TransformationBead<TRequest, TContext>(
    private val transformer: (TRequest) -> TRequest
) : Bead<TContext, TRequest, TRequest> {
    override val name = "Transformation"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TRequest> {
        val transformed = transformer(request)
        context.metadata["transformed"] = true
        return Result.success(transformed)
    }
}
```

### 4. Integration Bead

Integrates with external systems:

```kotlin
class DatabaseBead<TRequest, TContext>(
    private val repository: UserRepository
) : Bead<TContext, TRequest, User?> {
    override val name = "Database"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<User?> {
        return when (request) {
            is GetUserRequest -> {
                val user = repository.findById(request.userId)
                Result.success(user)
            }
            else -> Result.failure(NotImplementedError("Unknown request type"))
        }
    }
}
```

### 5. Logging Bead

Logs requests and responses:

```kotlin
class LoggingBead<TRequest, TContext>(
    private val logger: Logger = KLogger("BeadChain")
) : Bead<TContext, TRequest, TRequest> {
    override val name = "Logging"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TRequest> {
        logger.info { "[${context.requestId}] Processing $name" }
        return Result.success(request)
    }
}
```

### 6. Error Handling Bead

Handles errors gracefully:

```kotlin
class ErrorHandlingBead<TRequest, TContext, TResponse>(
    private val handler: suspend (Error, TContext) -> Result<TContext>
) : Bead<TContext, TRequest, TResponse> {
    override val name = "ErrorHandling"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse> {
        // If there are errors, handle them
        if (context.errors.isNotEmpty()) {
            val lastError = context.errors.last()
            return handler(lastError, context)
        }
        // Otherwise, pass through
        return Result.failure(NoSuchElementException("No errors to handle"))
    }
}
```

---

## Bead Chain Implementation

### BeadChain Class

```kotlin
/**
 * Executes beads in sequence, passing context between them
 */
class BeadChain<TRequest, TContext, TResponse>(
    private val beads: List<Bead<TContext, TRequest, TResponse>>,
    private val onComplete: suspend (TContext) -> TResponse = { ctx ->
        @Suppress("UNCHECKED_CAST")
        ctx.customContext["response"] as TResponse ?: throw NotImplementedError("No response set")
    }
) {
    suspend fun execute(request: TRequest, initialContext: TContext = BeadContext()): Result<TResponse> {
        var context = initialContext.apply {
            requestId = UUID.randomUUID().toString()
            customContext["request"] = request
        }

        for (bead in beads) {
            bead.onExecute(request, context)

            val result = bead.process(request, context)

            when (result) {
                is Result.Success -> {
                    // Pass the successful result as the new request
                    // This allows the next bead to see the transformed request
                    request = result.value
                }
                is Result.Failure -> {
                    // Handle the error - return immediately or continue
                    return Result.failure(result.exception)
                }
            }
        }

        val response = onComplete(context)
        return Result.success(response)
    }
}

/**
 * Builder for creating bead chains
 */
class BeadChainBuilder<TRequest, TContext, TResponse> {
    private val beads: MutableList<Bead<TContext, TRequest, TResponse>> = mutableListOf()
    private var onComplete: suspend (TContext) -> TResponse = { ctx ->
        @Suppress("UNCHECKED_CAST")
        ctx.customContext["response"] as TResponse ?: throw NotImplementedError("No response set")
    }

    fun addBead(bead: Bead<TContext, TRequest, TResponse>): BeadChainBuilder<TRequest, TContext, TResponse> {
        beads.add(bead)
        return this
    }

    fun onComplete(block: suspend (TContext) -> TResponse): BeadChainBuilder<TRequest, TContext, TResponse> {
        this.onComplete = block
        return this
    }

    fun build(): BeadChain<TRequest, TContext, TResponse> {
        return BeadChain(beads, onComplete)
    }
}
```

---

## Example Use Cases

### Example 1: Request Validation and Processing Pipeline

```kotlin
// Define request types
data class CreateOrderRequest(
    val userId: String,
    val items: List<OrderItem>,
    val shippingAddress: Address
)

data class OrderItem(val productId: String, val quantity: Int)
data class Address(val street: String, val city: String, val zip: String)

// Define beads
class ValidateOrderBead : Bead<BeadContext, CreateOrderRequest, CreateOrderRequest> {
    override val name = "ValidateOrder"

    override suspend fun process(
        request: CreateOrderRequest,
        context: BeadContext
    ): Result<CreateOrderRequest> {
        return if (request.items.isEmpty()) {
            Result.failure(ValidationException("Order must contain at least one item"))
        } else {
            Result.success(request)
        }
    }
}

class ValidateAddressBead : Bead<BeadContext, CreateOrderRequest, CreateOrderRequest> {
    override val name = "ValidateAddress"

    override suspend fun process(
        request: CreateOrderRequest,
        context: BeadContext
    ): Result<CreateOrderRequest> {
        return if (request.shippingAddress.zip.isBlank()) {
            Result.failure(ValidationException("Shipping address ZIP code is required"))
        } else {
            Result.success(request)
        }
    }
}

class CheckInventoryBead : Bead<BeadContext, CreateOrderRequest, CreateOrderRequest> {
    private val inventoryService = InventoryService()

    override val name = "CheckInventory"

    override suspend fun process(
        request: CreateOrderRequest,
        context: BeadContext
    ): Result<CreateOrderRequest> {
        val insufficientItems = request.items.filter { item ->
            inventoryService.getStock(item.productId) < item.quantity
        }

        return if (insufficientItems.isEmpty()) {
            Result.success(request)
        } else {
            Result.failure(
                InventoryException(
                    "Insufficient stock: ${insufficientItems.joinToString { it.productId }}"
                )
            )
        }
    }
}

// Build and execute the chain
suspend fun createOrder(orderRequest: CreateOrderRequest): Result<Order> {
    val chain = BeadChainBuilder<CreateOrderRequest, BeadContext, Order>()
        .addBead(ValidateOrderBead())
        .addBead(ValidateAddressBead())
        .addBead(CheckInventoryBead())
        .onComplete { context ->
            // Final processing after all beads pass
            val request = context.customContext["request"] as CreateOrderRequest
            // Create and save order
            Order(request.items, request.shippingAddress, OrderStatus.PENDING)
        }
        .build()

    return chain.execute(orderRequest)
}
```

### Example 2: Dynamic Fallback Chain

```kotlin
class FallbackBead<TRequest, TContext, TResponse>(
    private val primaryHandler: suspend (TRequest, TContext) -> Result<TResponse>,
    private val fallbackHandlers: List<suspend (TRequest, TContext) -> Result<TResponse>>
) : Bead<TContext, TRequest, TResponse> {
    override val name = "FallbackChain"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse> {
        return primaryHandler(request, context)
            ?: fallbackHandlers.firstOrNull()?.invoke(request, context)
            ?: Result.failure(NoFallbackAvailableException("No handlers available"))
    }
}

// Usage with caching fallback
class OrderService {
    suspend fun createOrder(orderRequest: CreateOrderRequest): Result<Order> {
        val chain = BeadChainBuilder<CreateOrderRequest, BeadContext, Order>()
            .addBead(
                FallbackBead(
                    primaryHandler = { req, ctx ->
                        try {
                            val order = database.save(req)
                            Result.success(order)
                        } catch (e: DatabaseException) {
                            ctx.errors.add(Error("Database", "Primary handler failed", cause = e))
                            Result.failure(e)
                        }
                    },
                    fallbackHandlers = listOf(
                        // Fallback 1: Use cache
                        { req, ctx ->
                            val cached = cache.get(req.userId)
                            if (cached != null) {
                                Result.success(cached)
                            } else {
                                Result.failure(NoSuchElementException("Not in cache"))
                            }
                        },
                        // Fallback 2: Return provisional order
                        { req, ctx ->
                            ctx.errors.add(Error("Database", "Using provisional order"))
                            Result.success(Order(req.items, req.shippingAddress, OrderStatus.PROVISIONAL))
                        }
                    )
                )
            )
            .build()

        return chain.execute(orderRequest)
    }
}
```

### Example 3: Skill Pipeline for Code Generation

```kotlin
// Skill beads for code generation
class ValidateLanguageBead : Bead<SkillContext, Prompt, Prompt> {
    override val name = "ValidateLanguage"

    override suspend fun process(
        request: Prompt,
        context: SkillContext
    ): Result<Prompt> {
        val validLanguages = listOf("Kotlin", "Java", "JavaScript", "Python")
        return if (request.language in validLanguages) {
            Result.success(request)
        } else {
            Result.failure(ValidationException("Invalid language: ${request.language}"))
        }
    }
}

class FetchCodebaseBead : Bead<SkillContext, Prompt, Prompt> {
    private val fileService = FileService()

    override val name = "FetchCodebase"

    override suspend fun process(
        request: Prompt,
        context: SkillContext
    ): Result<Prompt> {
        val codebase = fileService.getDirectory(request.path)
        context.customContext["codebase"] = codebase
        return Result.success(request)
    }
}

class GenerateBead : Bead<SkillContext, Prompt, Prompt> {
    private val llm = DeepSeekLLM()

    override val name = "Generate"

    override suspend fun process(
        request: Prompt,
        context: SkillContext
    ): Result<Prompt> {
        val codebase = context.customContext["codebase"] as String
        val prompt = request.prompt + "\n\nContext:\n$codebase"

        val response = llm.generate(prompt)

        context.customContext["generatedCode"] = response
        return Result.success(request)
    }
}

class ReviewBead : Bead<SkillContext, Prompt, Prompt> {
    private val codeReviewService = CodeReviewService()

    override val name = "Review"

    override suspend fun process(
        request: Prompt,
        context: SkillContext
    ): Result<Prompt> {
        val code = context.customContext["generatedCode"] as String
        val review = codeReviewService.analyze(code)

        context.customContext["review"] = review
        return Result.success(request)
    }
}

// Build the skill chain
suspend fun generateCode(prompt: Prompt): Result<CodeGenerationResult> {
    val chain = BeadChainBuilder<Prompt, SkillContext, CodeGenerationResult>()
        .addBead(ValidateLanguageBead())
        .addBead(FetchCodebaseBead())
        .addBead(GenerateBead())
        .addBead(ReviewBead())
        .onComplete { context ->
            CodeGenerationResult(
                code = context.customContext["generatedCode"] as String,
                review = context.customContext["review"] as CodeReview,
                language = prompt.language
            )
        }
        .build()

    return chain.execute(prompt)
}
```

### Example 4: Data Processing Pipeline

```kotlin
// Data processing pipeline
class LoggingBead<TData, TContext>(
    private val logger: Logger = KLogger("Pipeline")
) : Bead<TContext, TData, TData> {
    override val name = "Logging"

    override suspend fun process(data: TData, context: TContext): Result<TData> {
        logger.info { "Processing $name: ${data.toString().take(100)}" }
        return Result.success(data)
    }
}

class ParsingBead<TData, TContext>(private val parser: Parser) : Bead<TContext, TData, ParsedData> {
    override val name = "Parsing"

    override suspend fun process(data: TData, context: TContext): Result<ParsedData> {
        return Result.success(parser.parse(data))
    }
}

class ValidationBead<TData, TContext>(private val validator: Validator) : Bead<TContext, TData, TData> {
    override val name = "Validation"

    override suspend fun process(data: TData, context: TContext): Result<TData> {
        return if (validator.isValid(data)) {
            Result.success(data)
        } else {
            Result.failure(ValidationException("Data validation failed"))
        }
    }
}

class TransformationBead<TData, TContext>(private val transformer: Transformer) : Bead<TContext, TData, TransformedData> {
    override val name = "Transformation"

    override suspend fun process(data: TData, context: TContext): Result<TransformedData> {
        return Result.success(transformer.transform(data))
    }
}

class StorageBead<TData, TContext>(private val repository: Repository) : Bead<TContext, TData, Unit> {
    override val name = "Storage"

    override suspend fun process(data: TData, context: TContext): Result<Unit> {
        repository.save(data)
        return Result.success(Unit)
    }
}

// Build the data pipeline
suspend fun processTransaction(transactionData: String): Result<Unit> {
    val chain = BeadChainBuilder<String, PipelineContext, Unit>()
        .addBead(LoggingBead())
        .addBead(ParsingBead(RegexParser()))
        .addBead(ValidationBead(TransactionValidator()))
        .addBead(TransformationBead(TransactionTransformer()))
        .addBead(StorageBead(TransactionRepository()))
        .build()

    return chain.execute(transactionData)
}
```

---

## Advanced Bead Patterns

### 1. Conditional Beads

Beads that run only if conditions are met:

```kotlin
class ConditionalBead<TRequest, TContext, TResponse>(
    private val condition: suspend (TRequest, TContext) -> Boolean,
    private val bead: Bead<TContext, TRequest, TResponse>
) : Bead<TContext, TRequest, TResponse> {
    override val name = "${bead.name} (Conditional)"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse> {
        return if (condition(request, context)) {
            bead.process(request, context)
        } else {
            Result.success(request) // Pass through
        }
    }
}
```

### 2. Parallel Beads

Execute multiple beads in parallel:

```kotlin
class ParallelBead<TRequest, TContext, TResponse>(
    private val beads: List<Bead<TContext, TRequest, TResponse>>,
    private val aggregator: suspend (List<Result<TResponse>>) -> TResponse
) : Bead<TContext, TRequest, TResponse> {
    override val name = "ParallelExecution"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse> {
        val results = beads.map { bead ->
            async {
                bead.process(request, context)
            }
        }.awaitAll()

        return Result.success(aggregator(results))
    }
}
```

### 3. Retry Bead

Retries a bead multiple times on failure:

```kotlin
class RetryBead<TRequest, TContext, TResponse>(
    private val bead: Bead<TContext, TRequest, TResponse>,
    private val maxRetries: Int = 3,
    private val retryDelay: Duration = 1.seconds
) : Bead<TContext, TRequest, TResponse> {
    override val name = "${bead.name} (Retry)"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse> {
        repeat(maxRetries) { attempt ->
            val result = bead.process(request, context)
            if (result.isSuccess) return result

            if (attempt < maxRetries - 1) {
                delay(retryDelay)
            }
        }
        return Result.failure(RetriesExhaustedException("Maximum retries exceeded"))
    }
}
```

---

## Benefits

### 1. Modularity
- Each bead has a single responsibility
- Easy to add/remove beads without affecting others
- Beads can be reused in different chains

### 2. Flexibility
- Chains can be built dynamically at runtime
- Different chains for different scenarios
- Beads can be combined in various orders

### 3. Maintainability
- Clear separation of concerns
- Easy to test individual beads
- Simple to debug issues

### 4. Extensibility
- New bead types can be added without changing the chain
- Existing beads can be enhanced
- Beads can be composed to create new patterns

### 5. Error Handling
- Errors can be handled at specific points
- Fallback chains can provide alternatives
- Error context is preserved throughout the chain

---

## Best Practices

### ✅ Do

- **Keep beads focused**: Each bead should do one thing well
- **Use clear names**: Name beads descriptively
- **Document context flow**: Explain what context is passed between beads
- **Handle errors properly**: Return failures, don't throw unhandled exceptions
- **Use type safety**: Leverage Kotlin's type system to ensure type safety
- **Add logging**: Log bead execution for debugging and monitoring
- **Make beads reusable**: Design beads that can be used in multiple chains

### ❌ Don't

- **Mix concerns**: Don't let beads handle multiple responsibilities
- **Share mutable state**: Pass context explicitly, don't modify it globally
- **Skip error handling**: Always handle failures gracefully
- **Create too many beads**: Over-engineering a simple task
- **Ignore context flow**: Always document what context is passed
- **Make chains too long**: Keep chains focused and manageable

---

## Performance Considerations

### 1. Context Overhead
- Keep context minimal, only passing what's needed
- Use immutable context when possible
- Cache context data when reused

### 2. Async Execution
- Use suspend functions for all operations
- Use coroutines for parallel execution
- Consider backpressure for high-volume chains

### 3. Memory Management
- Clear context after chain completion
- Reuse context objects when possible
- Avoid memory leaks from long-lived chains

---

## Testing Strategy

```kotlin
@Test
fun `BeadChain executes in order`() = runTest {
    val beads = listOf(
        ProcessingBead<TContext, Int, Int>({ Result.success(it + 1) }, "First"),
        ProcessingBead<TContext, Int, Int>({ Result.success(it + 1) }, "Second"),
        ProcessingBead<TContext, Int, Int>({ Result.success(it + 1) }, "Third")
    )

    val chain = BeadChain(beads) { ctx ->
        @Suppress("UNCHECKED_CAST")
        ctx.customContext["finalValue"] as Int
    }

    val result = chain.execute(0)
    assertEquals(Result.success(3), result)
}

@Test
fun `BeadChain handles errors gracefully`() = runTest {
    val beads = listOf(
        ProcessingBead<TContext, Int, Int>(
            { Result.failure(Exception("Error at bead 1")) },
            "First"
        ),
        ProcessingBead<TContext, Int, Int>(
            { Result.success(it + 1) },
            "Second"
        )
    )

    val chain = BeadChain(beads) { ctx -> @Suppress("UNCHECKED_CAST") ctx.customContext["value"] as Int }
    val result = chain.execute(0)

    assertEquals(Result.failure<Exception> { it is Exception }, result)
}
```

---

## Related Skills

- **tool-orchestration**: Tool chaining patterns
- **state-machine-workflow**: State machine workflows
- **rag-memory**: Memory retrieval and processing
- **react-pattern**: Reasoning and acting patterns
- **iterative-refinement**: Iterative improvement patterns

---

## Resources

- [Chain of Responsibility Pattern](https://refactoring.guru/design-patterns/chain-of-responsibility)
- [Decorator Pattern](https://refactoring.guru/design-patterns/decorator)
- [Pipeline Pattern](https://en.wikipedia.org/wiki/Pipeline_(software))
- [Middleware Pattern](https://en.wikipedia.org/wiki/Middleware)

---

*Version: 1.0.0 | Category: skill-patterns | Tags: chain-of-responsibility, orchestration, pipeline, middleware, fallback*
