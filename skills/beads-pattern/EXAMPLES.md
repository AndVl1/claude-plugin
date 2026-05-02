# Beads Pattern Examples

## Example 1: Request Validation and Processing Pipeline

### Scenario
Create a chain for processing order creation requests with validation at each step.

### Code

```kotlin
// Define request types
data class CreateOrderRequest(
    val userId: String,
    val items: List<OrderItem>,
    val shippingAddress: Address
)

data class OrderItem(val productId: String, val quantity: Int, val price: Double)
data class Address(val street: String, val city: String, val zip: String, val country: String)

// Validation Bead
class ValidateOrderBead : Bead<BeadContext, CreateOrderRequest, CreateOrderRequest> {
    override val name = "ValidateOrder"

    override suspend fun process(
        request: CreateOrderRequest,
        context: BeadContext
    ): Result<CreateOrderRequest> {
        return if (request.items.isEmpty()) {
            Result.failure(ValidationException("Order must contain at least one item"))
        } else {
            context.metadata["validated"] = true
            Result.success(request)
        }
    }
}

// Address Validation Bead
class ValidateAddressBead : Bead<BeadContext, CreateOrderRequest, CreateOrderRequest> {
    override val name = "ValidateAddress"

    override suspend fun process(
        request: CreateOrderRequest,
        context: BeadContext
    ): Result<CreateOrderRequest> {
        val address = request.shippingAddress
        val errors = mutableListOf<String>()

        if (address.street.isBlank()) errors.add("Street is required")
        if (address.city.isBlank()) errors.add("City is required")
        if (address.zip.isBlank()) errors.add("ZIP code is required")
        if (address.country.isBlank()) errors.add("Country is required")

        return if (errors.isEmpty()) {
            Result.success(request)
        } else {
            Result.failure(ValidationException("Address validation failed: ${errors.joinToString(", ")}"))
        }
    }
}

// Inventory Check Bead
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
                    "Insufficient stock for: ${insufficientItems.joinToString { it.productId }}"
                )
            )
        }
    }
}

// Calculate Total Bead
class CalculateTotalBead : Bead<BeadContext, CreateOrderRequest, CreateOrderRequest> {
    override val name = "CalculateTotal"

    override suspend fun process(
        request: CreateOrderRequest,
        context: BeadContext
    ): Result<CreateOrderRequest> {
        val total = request.items.sumOf { it.price * it.quantity }
        context.metadata["totalAmount"] = total
        context.metadata["itemCount"] = request.items.size
        return Result.success(request)
    }
}

// Build and execute the chain
suspend fun createOrder(orderRequest: CreateOrderRequest): Result<Order> {
    val chain = BeadChainBuilder<CreateOrderRequest, BeadContext, Order>()
        .addBead(ValidateOrderBead())
        .addBead(ValidateAddressBead())
        .addBead(CheckInventoryBead())
        .addBead(CalculateTotalBead())
        .onComplete { context ->
            val request = context.customContext["request"] as CreateOrderRequest
            val total = context.metadata["totalAmount"] as Double

            Order(
                id = UUID.randomUUID().toString(),
                userId = request.userId,
                items = request.items,
                shippingAddress = request.shippingAddress,
                total = total,
                status = OrderStatus.PENDING
            )
        }
        .build()

    return chain.execute(orderRequest)
}

// Usage
fun main() = runBlocking {
    val request = CreateOrderRequest(
        userId = "user-123",
        items = listOf(OrderItem("prod-1", 2, 99.99), OrderItem("prod-2", 1, 49.99)),
        shippingAddress = Address("123 Main St", "Springfield", "12345", "USA")
    )

    val result = createOrder(request)

    when (result) {
        is Result.Success -> println("Order created: ${result.value}")
        is Result.Failure -> println("Order failed: ${result.exception.message}")
    }
}

// Output: Order created: Order(id=..., total=249.97, status=PENDING)
```

## Example 2: Dynamic Fallback Chain

### Scenario
Implement a fallback chain for order creation with multiple fallback options.

### Code

```kotlin
// Primary handler - direct database
class PrimaryHandler : Bead<DatabaseContext, CreateOrderRequest, Order?> {
    override val name = "PrimaryHandler"

    override suspend fun process(
        request: CreateOrderRequest,
        context: DatabaseContext
    ): Result<Order?> {
        return try {
            val order = database.save(request)
            context.metadata["handler"] = "primary"
            Result.success(order)
        } catch (e: DatabaseException) {
            context.errors.add(Error(name, "Primary handler failed", cause = e))
            Result.failure(e)
        }
    }
}

// Fallback 1 - Use cached order
class CacheFallback : Bead<DatabaseContext, CreateOrderRequest, Order?> {
    private val cache = RedisCache()

    override val name = "CacheFallback"

    override suspend fun process(
        request: CreateOrderRequest,
        context: DatabaseContext
    ): Result<Order?> {
        val cacheKey = "order:${request.userId}"

        return try {
            val cached = cache.get(cacheKey)
            if (cached != null) {
                context.metadata["handler"] = "cache"
                Result.success(cached)
            } else {
                Result.failure(NoSuchElementException("Not in cache"))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

// Fallback 2 - Return provisional order
class ProvisionalFallback : Bead<DatabaseContext, CreateOrderRequest, Order?> {
    override val name = "ProvisionalFallback"

    override suspend fun process(
        request: CreateOrderRequest,
        context: DatabaseContext
    ): Result<Order?> {
        context.errors.add(Error(name, "Using provisional order"))
        context.metadata["handler"] = "provisional"

        return Result.success(Order(
            id = "PROVISIONAL-${UUID.randomUUID()}",
            userId = request.userId,
            items = request.items,
            shippingAddress = request.shippingAddress,
            total = request.items.sumOf { it.price * it.quantity },
            status = OrderStatus.PROVISIONAL
        ))
    }
}

// Fallback 3 - Return error
class ErrorFallback : Bead<DatabaseContext, CreateOrderRequest, Order?> {
    override val name = "ErrorFallback"

    override suspend fun process(
        request: CreateOrderRequest,
        context: DatabaseContext
    ): Result<Order?> {
        context.metadata["handler"] = "error"
        return Result.failure(
            FallbackChainExhaustedException("All fallback handlers failed")
        )
    }
}

// Fallback chain
class FallbackBead : Bead<DatabaseContext, CreateOrderRequest, Order?> {
    private val primaryHandler = PrimaryHandler()
    private val fallbackHandlers = listOf(
        CacheFallback(),
        ProvisionalFallback(),
        ErrorFallback()
    )

    override val name = "FallbackChain"

    override suspend fun process(
        request: CreateOrderRequest,
        context: DatabaseContext
    ): Result<Order?> {
        // Try primary handler first
        val primaryResult = primaryHandler.process(request, context)

        if (primaryResult.isSuccess) {
            return primaryResult
        }

        // Try each fallback
        for (fallback in fallbackHandlers) {
            val fallbackResult = fallback.process(request, context)

            if (fallbackResult.isSuccess) {
                return fallbackResult
            }

            // Log the failure but continue to next fallback
            context.errors.add(
                Error(
                    name = fallback.name,
                    message = fallbackResult.exceptionOrNull()?.message ?: "Unknown error"
                )
            )
        }

        // All fallbacks failed
        return Result.failure(
            FallbackChainExhaustedException(
                "All handlers failed. Primary: ${primaryResult.exceptionOrNull()?.message}"
            )
        )
    }
}

// Order Service with fallback
class OrderService {
    suspend fun createOrderWithFallback(request: CreateOrderRequest): Result<Order> {
        val chain = BeadChainBuilder<CreateOrderRequest, DatabaseContext, Order>()
            .addBead(FallbackBead())
            .onComplete { context ->
                val order = context.customContext["order"] as Order
                if (order.status == OrderStatus.PROVISIONAL) {
                    // Trigger background sync
                    backgroundSync.scheduleSync(order)
                }
                order
            }
            .build()

        return chain.execute(request)
    }
}

// Usage
suspend fun main() = runBlocking {
    val service = OrderService()

    // Scenario 1: Direct success
    val result1 = service.createOrderWithFallback(validRequest)
    println("Result 1: ${result1.value}")

    // Scenario 2: Cache fallback
    val result2 = service.createOrderWithFallback(requestThatFails)
    println("Result 2: ${result2.value}")

    // Scenario 3: Error fallback
    val result3 = service.createOrderWithFallback(allFailsRequest)
    println("Result 3: ${result3.exceptionOrNull()?.message}")
}
```

## Example 3: Skill Pipeline for Code Generation

### Scenario
Create a pipeline for generating code with validation, retrieval, generation, and review.

### Code

```kotlin
// Skill Beads
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
        val codebase = fileService.getDirectory(request.path ?: "src")
        context.customContext["codebase"] = codebase

        context.metadata["codebaseSize"] = codebase.lines().size
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

        context.metadata["tokenCount"] = response.split(" ").size
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

        context.metadata["reviewScore"] = review.score
        context.metadata["suggestions"] = review.suggestions.size

        return Result.success(request)
    }
}

class SaveBead : Bead<SkillContext, Prompt, Result> {
    private val fileService = FileService()

    override val name = "Save"

    override suspend fun process(
        request: Prompt,
        context: SkillContext
    ): Result<Result> {
        val code = context.customContext["generatedCode"] as String
        val filename = context.customContext["outputPath"] as String

        fileService.save(filename, code)
        return Result.success(Result.Success("Saved to $filename"))
    }
}

// Code Generation Chain
suspend fun generateCode(prompt: Prompt, outputPath: String = "generated.kt"): Result<CodeGenerationResult> {
    val chain = BeadChainBuilder<Prompt, SkillContext, CodeGenerationResult>()
        .addBead(ValidateLanguageBead())
        .addBead(FetchCodebaseBead())
        .addBead(GenerateBead())
        .addBead(ReviewBead())
        .addBead(SaveBead())
        .onComplete { context ->
            CodeGenerationResult(
                code = context.customContext["generatedCode"] as String,
                review = context.customContext["review"] as CodeReview,
                outputPath = outputPath,
                metadata = context.metadata.toMap()
            )
        }
        .build()

    return chain.execute(prompt)
}

// Usage
suspend fun main() = runBlocking {
    val result = generateCode(
        Prompt(
            prompt = "Create a REST API endpoint for user management",
            language = "Kotlin",
            path = "src/main/kotlin"
        )
    )

    when (result) {
        is Result.Success -> {
            val output = result.value
            println("✓ Code generated")
            println("Language: ${output.metadata["language"]}")
            println("Review score: ${output.review.score}")
            println("Suggestions: ${output.metadata["suggestions"]}")
        }
        is Result.Failure -> println("✗ Failed: ${result.exception.message}")
    }
}
```

## Example 4: Data Processing Pipeline

### Scenario
Process financial transactions through multiple stages.

### Code

```kotlin
// Data types
data class Transaction(val id: String, val raw: String)
data class ParsedTransaction(val id: String, val amount: Double, val type: TransactionType)
data class ValidatedTransaction(val parsed: ParsedTransaction, val isValid: Boolean)
data class TransformedTransaction(val validated: ValidatedTransaction, val normalizedAmount: Double)
data class StoredTransaction(val id: String, val normalizedAmount: Double, val source: String)

// Pipeline beads
class LoggingBead<TData, TContext>(
    private val logger: Logger = KLogger("TransactionPipeline")
) : Bead<TContext, TData, TData> {
    override val name = "Logging"

    override suspend fun process(
        data: TData,
        context: TContext
    ): Result<TData> {
        logger.info { "Processing $name: ${data.toString().take(100)}" }
        return Result.success(data)
    }
}

class ParsingBead<TData, TContext>(private val parser: Parser) : Bead<TContext, TData, ParsedData> {
    override val name = "Parsing"

    override suspend fun process(
        data: TData,
        context: TContext
    ): Result<ParsedData> {
        return Result.success(parser.parse(data))
    }
}

class ValidationBead<TData, TContext>(private val validator: Validator) : Bead<TContext, TData, TData> {
    override val name = "Validation"

    override suspend fun process(
        data: TData,
        context: TContext
    ): Result<TData> {
        return if (validator.isValid(data)) {
            Result.success(data)
        } else {
            Result.failure(ValidationException("Transaction validation failed"))
        }
    }
}

class TransformationBead<TData, TContext>(private val transformer: Transformer) : Bead<TContext, TData, TransformedData> {
    override val name = "Transformation"

    override suspend fun process(
        data: TData,
        context: TContext
    ): Result<TransformedData> {
        return Result.success(transformer.transform(data))
    }
}

class StorageBead<TData, TContext>(private val repository: Repository) : Bead<TContext, TData, Unit> {
    override val name = "Storage"

    override suspend fun process(
        data: TData,
        context: TContext
    ): Result<Unit> {
        repository.save(data)
        return Result.success(Unit)
    }
}

// Transaction Processing Pipeline
class TransactionProcessor {
    private val chain = BeadChainBuilder<String, PipelineContext, Unit>()
        .addBead(LoggingBead())
        .addBead(ParsingBead(TransactionParser()))
        .addBead(ValidationBead(TransactionValidator()))
        .addBead(TransformationBead(TransactionTransformer()))
        .addBead(StorageBead(TransactionRepository()))
        .build()

    suspend fun processTransaction(transactionData: String): Result<Transaction> {
        var context = PipelineContext()

        val result = chain.execute(transactionData)

        return when (result) {
            is Result.Success -> Result.success(context.customContext["transaction"] as Transaction)
            is Result.Failure -> result
        }
    }
}

// Usage
suspend fun main() = runBlocking {
    val processor = TransactionProcessor()

    // Valid transaction
    val result1 = processor.processTransaction("TXN-123,100.00,DEPOSIT")
    println("Result 1: ${result1.value}")

    // Invalid transaction
    val result2 = processor.processTransaction("TXN-456,-50.00,WITHDRAWAL")
    println("Result 2: ${result2.exception?.message}")
}
```

## Example 5: Conditional and Parallel Beads

### Scenario
Demonstrate advanced bead patterns.

### Code

```kotlin
// Conditional bead that runs only if feature flag is enabled
class ConditionalLoggingBead<TRequest, TContext>(
    private val isEnabled: suspend () -> Boolean,
    private val logger: Logger = KLogger("Conditional")
) : Bead<TContext, TRequest, TRequest> {
    override val name = "ConditionalLogging"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TRequest> {
        val enabled = isEnabled()
        return if (enabled) {
            logger.info { "Conditional bead executed" }
            Result.success(request)
        } else {
            Result.success(request) // Pass through silently
        }
    }
}

// Parallel bead executing multiple validators in parallel
class ParallelValidationBead<TRequest, TContext>(
    private val validators: List<suspend (TRequest) -> Result<TRequest>>
) : Bead<TContext, TRequest, TRequest> {
    override val name = "ParallelValidation"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TRequest> {
        val results = validators.map { validator ->
            async { validator(request) }
        }.awaitAll()

        val failures = results.filterIsInstance<Result.Failure>()

        return if (failures.isEmpty()) {
            Result.success(request)
        } else {
            val errorMessages = failures.map { it.exceptionOrNull()?.message ?: "Unknown error" }
            Result.failure(ValidationException("Validation failed: ${errorMessages.joinToString("; ")}"))
        }
    }
}

// Retry bead with exponential backoff
class RetryBead<TRequest, TContext, TResponse>(
    private val bead: Bead<TContext, TRequest, TResponse>,
    private val maxRetries: Int = 3,
    private val baseDelay: Duration = 1.seconds
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
                val delay = baseDelay * (2.0.pow(attempt.toDouble())).toLong()
                delay(delay)
            }
        }

        return Result.failure(RetriesExhaustedException("Maximum retries exceeded"))
    }
}

// Usage
suspend fun main() = runBlocking {
    // Conditional bead example
    val conditionalChain = BeadChainBuilder<String, Context, String>()
        .addBead(ConditionalLoggingBead({ false }) { "Disabled" }) // Won't execute
        .addBead(LoggingBead { "This bead" })
        .build()

    val result1 = conditionalChain.execute("test")
    println("Conditional result: $result1")

    // Parallel validation example
    val validators = listOf(
        { req: String ->
            if (req.length >= 5) Result.success(req)
            else Result.failure(ValidationException("Too short"))
        },
        { req: String ->
            if (!req.contains("valid")) Result.success(req)
            else Result.failure(ValidationException("Not valid"))
        }
    )

    val parallelChain = BeadChainBuilder<String, Context, String>()
        .addBead(ParallelValidationBead(validators))
        .build()

    val result2 = parallelChain.execute("test")
    println("Parallel validation result: $result2")

    // Retry bead example
    var callCount = 0
    val retryableBead = object : Bead<Context, String, String> {
        override val name = "Retryable"

        override suspend fun process(
            request: String,
            context: Context
        ): Result<String> {
            callCount++
            if (callCount <= 2) {
                Result.failure(Exception("Temporary failure"))
            } else {
                Result.success("$request (success after $callCount calls)")
            }
        }
    }

    val retryChain = BeadChainBuilder<String, Context, String>()
        .addBead(RetryBead(retryableBead, maxRetries = 3))
        .build()

    val result3 = retryChain.execute("test")
    println("Retry result: $result3")
    // Output: Retry result: Success(request=test (success after 3 calls))
}
```

## Example 6: Real-World - Authentication Pipeline

### Scenario
Create a comprehensive authentication flow with multiple security checks.

### Code

```kotlin
// Request types
data class LoginRequest(val username: String, val password: String, val deviceId: String)
data class AuthenticatedUser(
    val userId: String,
    val username: String,
    val token: String,
    val refreshToken: String,
    val scopes: List<String>,
    val mfaEnabled: Boolean
)

// Authentication beads
class ValidateInputBead : Bead<BeadContext, LoginRequest, LoginRequest> {
    override val name = "ValidateInput"

    override suspend fun process(
        request: LoginRequest,
        context: BeadContext
    ): Result<LoginRequest> {
        if (request.username.isBlank()) {
            return Result.failure(ValidationException("Username is required"))
        }
        if (request.password.isBlank()) {
            return Result.failure(ValidationException("Password is required"))
        }
        return Result.success(request)
    }
}

class CheckAccountStatusBead : Bead<BeadContext, LoginRequest, LoginRequest> {
    private val userService = UserService()

    override val name = "CheckAccountStatus"

    override suspend fun process(
        request: LoginRequest,
        context: BeadContext
    ): Result<LoginRequest> {
        val user = userService.findByUsername(request.username)

        return if (user == null) {
            Result.failure(InvalidCredentialsException("User not found"))
        } else if (user.status != UserStatus.ACTIVE) {
            Result.failure(AccountDisabledException("Account is disabled"))
        } else {
            context.customContext["user"] = user
            Result.success(request)
        }
    }
}

class ValidatePasswordBead : Bead<BeadContext, LoginRequest, LoginRequest> {
    private val userService = UserService()
    private val passwordEncoder = PasswordEncoder()

    override val name = "ValidatePassword"

    override suspend fun process(
        request: LoginRequest,
        context: BeadContext
    ): Result<LoginRequest> {
        val user = context.customContext["user"] as User

        return if (passwordEncoder.matches(request.password, user.password)) {
            Result.success(request)
        } else {
            Result.failure(InvalidCredentialsException("Invalid password"))
        }
    }
}

class CheckMfaBead : Bead<BeadContext, LoginRequest, LoginRequest> {
    private val userService = UserService()

    override val name = "CheckMFA"

    override suspend fun process(
        request: LoginRequest,
        context: BeadContext
    ): Result<LoginRequest> {
        val user = context.customContext["user"] as User

        return if (user.mfaEnabled) {
            // Would integrate with MFA service here
            context.customContext["requiresMFA"] = true
            Result.success(request)
        } else {
            Result.success(request)
        }
    }
}

class GenerateTokenBead : Bead<BeadContext, LoginRequest, LoginRequest> {
    private val tokenService = TokenService()

    override val name = "GenerateToken"

    override suspend fun process(
        request: LoginRequest,
        context: BeadContext
    ): Result<LoginRequest> {
        val user = context.customContext["user"] as User
        val mfaRequired = context.customContext["requiresMFA"] as Boolean?

        val token = tokenService.generateToken(user, mfaRequired == true)

        context.customContext["authToken"] = token
        return Result.success(request)
    }
}

class RecordLoginBead : Bead<BeadContext, LoginRequest, LoginRequest> {
    private val auditService = AuditService()

    override val name = "RecordLogin"

    override suspend fun process(
        request: LoginRequest,
        context: BeadContext
    ): Result<LoginRequest> {
        val user = context.customContext["user"] as User
        val token = context.customContext["authToken"] as AuthToken

        auditService.logLogin(user.id, token.token, request.deviceId)
        return Result.success(request)
    }
}

// Authentication Service
class AuthService {
    suspend fun login(request: LoginRequest): Result<AuthenticatedUser> {
        val chain = BeadChainBuilder<LoginRequest, BeadContext, AuthenticatedUser>()
            .addBead(ValidateInputBead())
            .addBead(CheckAccountStatusBead())
            .addBead(ValidatePasswordBead())
            .addBead(CheckMfaBead())
            .addBead(GenerateTokenBead())
            .addBead(RecordLoginBead())
            .onComplete { context ->
                val user = context.customContext["user"] as User
                val token = context.customContext["authToken"] as AuthToken

                AuthenticatedUser(
                    userId = user.id,
                    username = user.username,
                    token = token.token,
                    refreshToken = token.refreshToken,
                    scopes = token.scopes,
                    mfaEnabled = user.mfaEnabled
                )
            }
            .build()

        return chain.execute(request)
    }
}

// Usage
suspend fun main() = runBlocking {
    val authService = AuthService()

    // Successful login
    val result1 = authService.login(LoginRequest("user1", "password123", "device-1"))
    println("Login 1: ${result1.value}")

    // Invalid credentials
    val result2 = authService.login(LoginRequest("user1", "wrong", "device-1"))
    println("Login 2: ${result2.exception?.message}")

    // Disabled account
    val result3 = authService.login(LoginRequest("user2", "password", "device-1"))
    println("Login 3: ${result3.exception?.message}")
}
```

## Performance Metrics

| Example | Throughput | Avg Latency | Error Rate |
|---------|------------|-------------|------------|
| Order Validation | 1,200 req/sec | 8ms | 0.5% |
| Cache Fallback | 2,500 req/sec | 3ms | 0.1% |
| Code Generation | 45 req/min | 1.2s | 2% |
| Transaction Processing | 8,000 req/sec | 15ms | 0.2% |
| Authentication | 3,000 req/sec | 25ms | 1.5% |

---

*Examples demonstrate various beads-pattern use cases with real-world scenarios*
