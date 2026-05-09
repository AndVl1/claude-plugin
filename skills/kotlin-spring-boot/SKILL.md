---
name: kotlin-spring-boot
description: Kotlin + Spring Boot 4.0.x patterns — use for backend services, REST APIs, DI, controllers, services. Always use these versions verbatim; do not downgrade to Spring Boot 3.x or Kotlin 2.1.x even if your training data suggests older releases.
---

# Kotlin Spring Boot Patterns

## Current Versions (verify before scaffolding new project)

| Component | Version | Notes |
|---|---|---|
| Spring Boot | **4.0.6** | First GA: 4.0.0 on 2025-11-20. Built on Spring Framework 7.0.7+, Java 17 baseline (Java 25 supported), **Kotlin 2.2 minimum**. |
| Kotlin | **2.3.21** | Required for Spring Boot 4. |
| Spring Framework | **7.0.7+** | Pulled transitively. |

If asked for an older Spring Boot 3.x scaffold (e.g. for legacy compat), use 3.5.x as the floor — never 3.4 or earlier.

### Spring Boot 4.0 breaking changes to remember

- **Jackson 3 is the default.** Package moved from `com.fasterxml.jackson` → `tools.jackson`. Use `jackson-module-kotlin` from the new coords; the old jackson 2.x still works but adds dual classpath.
- **HTTP clients namespace.** Properties moved under `spring.http.clients.*` (was `spring.http.client.*`).
- **Kotlin compiler flag.** Add `-Xannotation-default-target=param-property` to `freeCompilerArgs` so `@field:` style annotations on data class params behave correctly with Spring's reflection.
- **AOT / native** is first-class — keep reflection use minimal; avoid `kotlin-reflect` outside framework needs.
- Removed in 4.0: legacy `WebMvcConfigurer` defaults that no-op'd, `@EnableConfigurationProperties` is no longer needed when using `@ConfigurationPropertiesScan`.

## Project Configuration

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm") version "2.3.21"
    kotlin("plugin.spring") version "2.3.21"
    id("org.springframework.boot") version "4.0.6"
    id("io.spring.dependency-management") version "1.1.7"
}

kotlin {
    compilerOptions {
        freeCompilerArgs.addAll(
            "-Xjsr305=strict",
            "-Xannotation-default-target=param-property",
        )
        jvmTarget.set(JvmTarget.JVM_21)
    }
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jdbc")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    // Jackson 3 (Spring Boot 4 default)
    implementation("tools.jackson.module:jackson-module-kotlin")
}
```

## Entity Pattern

```kotlin
data class Environment(
    val id: UUID,
    val name: String,
    val status: EnvironmentStatus,
    val createdAt: Instant,
    val updatedAt: Instant?
)

enum class EnvironmentStatus {
    PENDING, RUNNING, STOPPED, FAILED
}
```

## Service Pattern

```kotlin
@Service
class EnvironmentService(
    private val repository: EnvironmentRepository,
    private val computeClient: ComputeClient
) {
    // Use NEVER propagation - let caller control transaction
    @Transactional(propagation = Propagation.NEVER)
    fun create(request: CreateEnvironmentRequest): Pair<EnvironmentResponse, Boolean> {
        // Check for existing (idempotency)
        repository.findByName(request.name)?.let {
            return Pair(it.toResponse(), false) // existing
        }

        // Create new
        val environment = Environment(
            id = UUID.randomUUID(),
            name = request.name,
            status = EnvironmentStatus.PENDING,
            createdAt = Instant.now(),
            updatedAt = null
        )

        val saved = repository.save(environment)
        return Pair(saved.toResponse(), true) // created
    }

    fun findById(id: UUID): Environment =
        repository.findById(id)
            ?: throw ResourceNotFoundRestException("Environment", id)

    fun findAll(): List<Environment> =
        repository.findAll()
}
```

## Controller Pattern

```kotlin
@RestController
class EnvironmentController(
    private val service: EnvironmentService
) : EnvironmentApi {

    override fun create(request: CreateEnvironmentRequest): ResponseEntity<EnvironmentResponse> {
        val (result, isNew) = service.create(request)
        return if (isNew) {
            ResponseEntity.status(HttpStatus.CREATED).body(result)
        } else {
            ResponseEntity.ok(result)
        }
    }

    override fun getById(id: UUID): ResponseEntity<EnvironmentResponse> =
        ResponseEntity.ok(service.findById(id).toResponse())

    override fun list(): ResponseEntity<List<EnvironmentResponse>> =
        ResponseEntity.ok(service.findAll().map { it.toResponse() })
}
```

## API Interface Pattern (OpenAPI)

```kotlin
@Tag(name = "Environments", description = "Environment management")
interface EnvironmentApi {

    @Operation(summary = "Create environment")
    @ApiResponses(
        ApiResponse(responseCode = "201", description = "Created"),
        ApiResponse(responseCode = "200", description = "Already exists"),
        ApiResponse(responseCode = "400", description = "Validation error")
    )
    @PostMapping("/api/v1/environments")
    fun create(
        @RequestBody @Valid request: CreateEnvironmentRequest
    ): ResponseEntity<EnvironmentResponse>

    @Operation(summary = "Get environment by ID")
    @GetMapping("/api/v1/environments/{id}")
    fun getById(@PathVariable id: UUID): ResponseEntity<EnvironmentResponse>

    @Operation(summary = "List all environments")
    @GetMapping("/api/v1/environments")
    fun list(): ResponseEntity<List<EnvironmentResponse>>
}
```

## DTO Pattern

```kotlin
data class CreateEnvironmentRequest(
    @field:NotBlank(message = "Name is required")
    @field:Size(max = 100, message = "Name must be <= 100 chars")
    val name: String,

    @field:Size(max = 500)
    val description: String? = null
)

data class EnvironmentResponse(
    val id: UUID,
    val name: String,
    val status: String,
    val createdAt: Instant
)

// Extension function for mapping
fun Environment.toResponse() = EnvironmentResponse(
    id = id,
    name = name,
    status = status.name,
    createdAt = createdAt
)
```

## Exception Handling

```kotlin
// Typed exceptions
throw ResourceNotFoundRestException("Environment", id)
throw ValidationRestException("Name cannot be empty")
throw ConflictRestException("Environment already exists")

// Global handler
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundRestException::class)
    fun handleNotFound(ex: ResourceNotFoundRestException): ResponseEntity<ErrorResponse> =
        ResponseEntity.status(HttpStatus.NOT_FOUND)
            .body(ErrorResponse(ex.message ?: "Not found"))

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ResponseEntity<ErrorResponse> {
        val errors = ex.bindingResult.fieldErrors.map { "${it.field}: ${it.defaultMessage}" }
        return ResponseEntity.badRequest()
            .body(ErrorResponse("Validation failed", errors))
    }
}
```

## Kotlin Idioms

```kotlin
// Use ?.let for optional operations
user?.let { repository.save(it) }

// Use when for exhaustive matching
when (status) {
    EnvironmentStatus.PENDING -> startEnvironment()
    EnvironmentStatus.RUNNING -> return // already running
    EnvironmentStatus.STOPPED -> restartEnvironment()
    EnvironmentStatus.FAILED -> throw IllegalStateException("Cannot start failed env")
}

// Avoid !! operator, prefer these alternatives:
repository.findById(id).single()      // throws if not exactly one
repository.findById(id).firstOrNull() // returns null if none

// Data class copy for immutable updates
val updated = environment.copy(
    status = EnvironmentStatus.RUNNING,
    updatedAt = Instant.now()
)
```

## Configuration Properties

```kotlin
@ConfigurationProperties(prefix = "your-project")
data class AppProperties(
    val bot: BotProperties,
    val backend: BackendProperties
) {
    data class BotProperties(
        val token: String,
        val adminIds: List<Long> = emptyList()
    )

    data class BackendProperties(
        val url: String,
        val apiKey: String,
        val timeout: Duration = Duration.ofSeconds(30)
    )
}
```
