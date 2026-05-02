# Beads Pattern Skill

The Beads pattern (Chain of Responsibility) for skill orchestration, enabling flexible, composable skill chains.

## Overview

Beads pattern treats each skill as a "bead" in a chain that can:
- Pass context between skills automatically
- Filter requests at any point
- Handle errors gracefully with fallbacks
- Execute sequentially with clear boundaries
- Compose dynamically at runtime

## Key Features

✅ **Modular Skill Chains** - Chain multiple skills together with context passing
✅ **Flexible Fallbacks** - Graceful degradation when skills fail
✅ **Request Filtering** - Filter or transform requests at any stage
✅ **Type-Safe** - Leverages Kotlin's type system
✅ **Error Handling** - Built-in error handling and context preservation
✅ **Composable** - Build dynamic chains at runtime
✅ **Reusable Beads** - Each bead can be used in multiple chains

## Quick Start

### 1. Define a Bead

```kotlin
class LoggingBead<TRequest, TContext> : Bead<TContext, TRequest, TRequest> {
    override val name = "Logging"

    override suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TRequest> {
        logger.info { "Processing $name" }
        return Result.success(request)
    }
}
```

### 2. Build a Chain

```kotlin
val chain = BeadChainBuilder<Prompt, SkillContext, Result>()
    .addBead(ValidateBead())
    .addBead(ProcessingBead())
    .addBead(LoggingBead())
    .build()
```

### 3. Execute

```kotlin
val result = chain.execute(request)
```

## Bead Types

### Processing Bead
Transforms or processes the request.

```kotlin
class ProcessingBead<TRequest, TContext>(
    private val processor: (TRequest) -> Result<TRequest>
) : Bead<TContext, TRequest, TRequest>
```

### Filtering Bead
Filters out requests or adds conditions.

```kotlin
class FilteringBead<TRequest, TContext>(
    private val filter: (TRequest) -> Boolean,
    private val action: suspend (TRequest, TContext) -> TContext
) : Bead<TContext, TRequest, TContext>
```

### Transformation Bead
Transforms the request.

```kotlin
class TransformationBead<TRequest, TContext>(
    private val transformer: (TRequest) -> TRequest
) : Bead<TContext, TRequest, TRequest>
```

### Integration Bead
Integrates with external systems.

```kotlin
class DatabaseBead<TRequest, TContext>(
    private val repository: UserRepository
) : Bead<TContext, TRequest, User?>
```

### Error Handling Bead
Handles errors gracefully.

```kotlin
class ErrorHandlingBead<TRequest, TContext, TResponse>(
    private val handler: suspend (Error, TContext) -> Result<TContext>
) : Bead<TContext, TRequest, TResponse>
```

## Use Cases

### Request Validation Pipeline

```kotlin
val chain = BeadChainBuilder<CreateOrderRequest, BeadContext, Order>()
    .addBead(ValidateOrderBead())
    .addBead(ValidateAddressBead())
    .addBead(CheckInventoryBead())
    .build()
```

### Dynamic Fallback Chain

```kotlin
val chain = BeadChainBuilder<Prompt, SkillContext, Code>()
    .addBead(FallbackBead(primaryHandler, fallbackHandlers))
    .build()
```

### Skill Pipeline for Code Generation

```kotlin
val chain = BeadChainBuilder<Prompt, SkillContext, CodeGenerationResult>()
    .addBead(ValidateLanguageBead())
    .addBead(FetchCodebaseBead())
    .addBead(GenerateBead())
    .addBead(ReviewBead())
    .build()
```

### Data Processing Pipeline

```kotlin
val chain = BeadChainBuilder<String, PipelineContext, Unit>()
    .addBead(LoggingBead())
    .addBead(ParsingBead())
    .addBead(ValidationBead())
    .addBead(TransformationBead())
    .addBead(StorageBead())
    .build()
```

## Advanced Patterns

### Conditional Beads

Beads that run only if conditions are met.

```kotlin
class ConditionalBead<TRequest, TContext, TResponse>(
    private val condition: suspend (TRequest, TContext) -> Boolean,
    private val bead: Bead<TContext, TRequest, TResponse>
) : Bead<TContext, TRequest, TResponse>
```

### Parallel Beads

Execute multiple beads in parallel.

```kotlin
class ParallelBead<TRequest, TContext, TResponse>(
    private val beads: List<Bead<TContext, TRequest, TResponse>>,
    private val aggregator: suspend (List<Result<TResponse>>) -> TResponse
) : Bead<TContext, TRequest, TResponse>
```

### Retry Bead

Retries a bead multiple times on failure.

```kotlin
class RetryBead<TRequest, TContext, TResponse>(
    private val bead: Bead<TContext, TRequest, TResponse>,
    private val maxRetries: Int = 3,
    private val retryDelay: Duration = 1.seconds
) : Bead<TContext, TRequest, TResponse>
```

## Context Flow

```
Request → Bead 1 → Bead 2 → Bead 3 → ... → Response
        ↓        ↓        ↓
      Process  Process  Process
        ↓        ↓        ↓
       Context  Context  Context
```

Each bead can:
- **Pass through**: Continues to the next bead
- **Modify context**: Adds/updates context before passing
- **Stop**: Returns result (success or failure)

## Benefits

1. **Modularity**: Each bead has a single responsibility
2. **Flexibility**: Chains can be built dynamically at runtime
3. **Maintainability**: Clear separation of concerns
4. **Extensibility**: New bead types can be added without changing the chain
5. **Error Handling**: Errors can be handled at specific points

## Best Practices

✅ **Keep beads focused**: Each bead should do one thing well
✅ **Use clear names**: Name beads descriptively
✅ **Handle errors properly**: Return failures, don't throw unhandled exceptions
✅ **Add logging**: Log bead execution for debugging and monitoring
✅ **Make beads reusable**: Design beads that can be used in multiple chains

## Examples

See `SKILL.md` for comprehensive examples including:
- Request validation and processing pipeline
- Dynamic fallback chains
- Skill pipeline for code generation
- Data processing pipeline
- Conditional and parallel beads
- Retry mechanisms

## Resources

- [Chain of Responsibility Pattern](https://refactoring.guru/design-patterns/chain-of-responsibility)
- [Pipeline Pattern](https://en.wikipedia.org/wiki/Pipeline_(software))

---

*Version: 1.0.0 | Tags: chain-of-responsibility, orchestration, pipeline, middleware, fallback*
