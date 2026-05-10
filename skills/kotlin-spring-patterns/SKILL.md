---
name: kotlin-patterns
description: Kotlin + Spring Boot 4.x patterns for backend services — use when implementing backend features, writing services, repositories, or controllers. Pair with the `kotlin-spring-boot` skill for current versions and Spring Boot 4 migration notes.
---

# Kotlin Patterns for Backend Services

> **Versions** for Spring Boot, Kotlin, Jackson 3, etc. — see the `kotlin-spring-boot` skill. Always defer to that skill's version table; do not encode versions inline here.

## Entity Pattern

```kotlin
data class EntityName(
    val id: UUID,
    val name: String,
    val createdAt: Instant,
    val updatedAt: Instant?
)
```

## Service Pattern

Default propagation rule:
- Write methods → `@Transactional` (REQUIRED). Atomicity required; partial writes corrupt state.
- Read-only methods → `@Transactional(readOnly = true)` or no annotation if single-query.
- `Propagation.NEVER` → ONLY for orchestrators that MUST run outside any tx (e.g., outbox publisher delegating to `REQUIRES_NEW` worker, or method that triggers `@Async`/external IO and must not hold tx context). Wrong default for write services — silent breakage if caller wraps you in tx.

```kotlin
@Service
class EntityNameService(
    private val repository: EntityNameRepository,
    private val relatedService: RelatedService
) {
    @Transactional
    fun create(request: CreateRequest): Pair<EntityResponse, Boolean> {
        // Write path — REQUIRED tx. Atomic insert + related writes.
        // Return Pair for idempotent operations.
    }

    @Transactional(readOnly = true)
    fun findById(id: UUID): EntityName? =
        repository.findById(id)

    @Transactional(readOnly = true)
    fun findAll(): List<EntityName> =
        repository.findAll()

    // Rare: orchestrator that must NOT participate in caller's tx.
    @Transactional(propagation = Propagation.NEVER)
    fun publishOutbox(id: UUID) {
        outboxWorker.flushOne(id) // worker uses REQUIRES_NEW internally
    }
}
```

## Side effects after commit

Email, audit logs, cascade events, webhook dispatch — run AFTER commit, not inside tx.

Why:
- `@Async` invoked inside tx leaks tx context to executor thread (or sees uncommitted state via separate connection — race).
- Side-effect failure inside tx rolls back the business write. Email server flake should not erase the order.
- `@TransactionalEventListener(phase = AFTER_COMMIT)` fires only on successful commit. `@Async` on listener moves work off request thread.

```kotlin
data class EntityCreated(val id: UUID, val name: String)

@Service
class EntityNameService(
    private val repository: EntityNameRepository,
    private val publisher: ApplicationEventPublisher
) {
    @Transactional
    fun create(request: CreateRequest): EntityResponse {
        val entity = repository.save(request.toEntity())
        publisher.publishEvent(EntityCreated(entity.id, entity.name))
        return entity.toResponse()
    }
}

@Component
class EntityNotificationListener(
    private val mailer: Mailer
) {
    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    fun onCreated(event: EntityCreated) {
        mailer.sendWelcome(event.id) // failure here cannot rollback the entity
    }
}
```

Enable async: `@EnableAsync` on a `@Configuration` class. Define a named `TaskExecutor` bean for production (default `SimpleAsyncTaskExecutor` spawns unbounded threads).

## Repository Pattern (JOOQ)

```kotlin
@Repository
class EntityNameRepository(
    private val dsl: DSLContext
) {
    fun findById(id: UUID): EntityName? =
        dsl.selectFrom(ENTITY_NAME)
            .where(ENTITY_NAME.ID.eq(id))
            .fetchOne()
            ?.toEntity()

    fun findAll(): List<EntityName> =
        dsl.selectFrom(ENTITY_NAME)
            .fetch()
            .map { it.toEntity() }

    fun save(entity: EntityName): EntityName =
        dsl.insertInto(ENTITY_NAME)
            .set(ENTITY_NAME.ID, entity.id)
            .set(ENTITY_NAME.NAME, entity.name)
            .set(ENTITY_NAME.CREATED_AT, entity.createdAt)
            .returning()
            .fetchOne()!!
            .toEntity()

    private fun EntityNameRecord.toEntity() = EntityName(
        id = id,
        name = name,
        createdAt = createdAt,
        updatedAt = updatedAt
    )
}
```

## Controller Pattern

```kotlin
@RestController
class EntityNameController(
    private val service: EntityNameService
) : EntityNameApi {

    override fun create(request: CreateRequest): ResponseEntity<EntityResponse> {
        val (result, isNew) = service.create(request)
        return if (isNew) ResponseEntity.status(201).body(result)
        else ResponseEntity.ok(result)
    }

    override fun getById(id: UUID): ResponseEntity<EntityResponse> {
        val entity = service.findById(id)
            ?: throw ResourceNotFoundRestException("EntityName", id)
        return ResponseEntity.ok(entity.toResponse())
    }
}
```

## API Interface Pattern

```kotlin
@Tag(name = "Entity Name")
interface EntityNameApi {

    @Operation(summary = "Create entity")
    @PostMapping("/api/v1/entities")
    fun create(@RequestBody @Valid request: CreateRequest): ResponseEntity<EntityResponse>

    @Operation(summary = "Get entity by ID")
    @GetMapping("/api/v1/entities/{id}")
    fun getById(@PathVariable id: UUID): ResponseEntity<EntityResponse>
}
```

## DTO Pattern

```kotlin
data class CreateRequest(
    @field:NotBlank
    val name: String,

    @field:Size(max = 255)
    val description: String?
)

data class EntityResponse(
    val id: UUID,
    val name: String,
    val description: String?,
    val createdAt: Instant
)
```

## Exception Pattern

Typed hierarchy at service layer; `@ControllerAdvice` translates to RFC 7807 `ProblemDetail` (Spring 6+ / Boot 4 canonical shape, `application/problem+json`).

```kotlin
// Throw typed exceptions from services / controllers
throw ResourceNotFoundRestException("EntityName", id)
throw ValidationRestException("Name cannot be empty")
throw ConflictRestException("Entity already exists")
```

```kotlin
@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(ResourceNotFoundRestException::class)
    fun handleNotFound(ex: ResourceNotFoundRestException): ResponseEntity<ProblemDetail> {
        val pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.message)
        pd.title = "Resource not found"
        pd.setProperty("resource", ex.resource)
        pd.setProperty("id", ex.id)
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(pd)
    }

    @ExceptionHandler(ValidationRestException::class)
    fun handleValidation(ex: ValidationRestException): ResponseEntity<ProblemDetail> {
        val pd = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, ex.message)
        pd.title = "Validation failed"
        return ResponseEntity.badRequest().body(pd)
    }

    @ExceptionHandler(ConflictRestException::class)
    fun handleConflict(ex: ConflictRestException): ResponseEntity<ProblemDetail> {
        val pd = ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, ex.message)
        pd.title = "Conflict"
        return ResponseEntity.status(HttpStatus.CONFLICT).body(pd)
    }
}
```

`ProblemDetail` auto-serializes to `application/problem+json`. Use `setProperty` for extension fields. Do NOT hand-roll `ErrorResponse` DTOs.

## Null Safety Guidelines

- Use `?.let{}` for optional operations
- Use `when` for exhaustive matching
- Instead of not-null assertion, use `.single()` or `.firstOrNull()`
- Return `Pair<Result, Boolean>` for idempotent operations
