# Quick Start Guide

This guide will help you get started with the Orchestration Framework in 5 minutes.

## Prerequisites

- Basic Kotlin knowledge
- Understanding of chain of responsibility pattern
- Familiarity with async/await

## Step 1: Define Your Beads

```kotlin
// Bead 1: Validation
val validationBead = Bead<String, String, String> {
    name = "Validation"

    suspend fun process(request: String, context: BeadContext): Result<String> {
        if (request.isBlank()) {
            return Result.failure(IllegalArgumentException("Request cannot be blank"))
        }
        return Result.success("Valid: $request")
    }
}

// Bead 2: Processing
val processingBead = Bead<String, String, String> {
    name = "Processing"

    suspend fun process(request: String, context: BeadContext): Result<String> {
        return Result.success("Processed: $request")
    }
}
```

## Step 2: Create the Orchestrator

```kotlin
val beads = listOf(validationBead, processingBead)

val orchestrator = Orchestrator(
    beads = beads,
    useReAct = false,  // Simple linear execution
    recoveryConfig = RecoveryConfig(
        maxRetries = 3,
        fallbackStrategy = FallbackStrategy.FALLBACK_BEAD
    )
)
```

## Step 3: Execute a Request

```kotlin
suspend fun main() {
    val result = orchestrator.orchestrate("Hello, World!")

    result.fold(
        onSuccess = { println("Success: $it") },
        onFailure = { println("Error: $it") }
    )
}
```

## Expected Output

```
Success: Valid: Hello, World!
Success: Processed: Valid: Hello, World!
```

## Step 4: Handle Errors

```kotlin
val errorResult = orchestrator.orchestrate("")

errorResult.fold(
    onSuccess = { println("Success: $it") },
    onFailure = { error ->
        println("Error: ${error.message}")
        println("Error occurred at bead: validation")
    }
)
```

## Expected Output

```
Error: Request cannot be blank
Error occurred at bead: Validation
```

## Next Steps

Now that you're familiar with the basics:

1. **Read** `example-basic-orchestration.md` for more details
2. **Try** adding more beads to your chain
3. **Experiment** with different configurations
4. **Explore** ReAct pattern for reasoning workflows
5. **Build** your own complete workflows

## Common Patterns

### Pattern 1: Logging Bead

```kotlin
val loggingBead = Bead<String, String, String> {
    name = "Logging"

    suspend fun process(request: String, context: BeadContext): Result<String> {
        println("[${context.metadata["timestamp"]}] Processing: $request")
        return Result.success(request)
    }
}
```

### Pattern 2: Caching Bead

```kotlin
val cachingBead = Bead<String, String, String> {
    name = "Caching"

    private val cache = mutableMapOf<String, String>()

    suspend fun process(request: String, context: BeadContext): Result<String> {
        if (request in cache) {
            println("Cache hit: $request")
            return Result.success(cache[request]!!)
        }

        val result = processRequest(request)
        cache[request] = result
        return Result.success(result)
    }

    private suspend fun processRequest(request: String): String {
        return "Processed: $request" // Simulated processing
    }
}
```

### Pattern 3: Transformation Bead

```kotlin
val transformationBead = Bead<String, String, String> {
    name = "Transformation"

    suspend fun process(request: String, context: BeadContext): Result<String> {
        return Result.success(request.uppercase())
    }
}
```

## Tips

- Keep beads focused on one responsibility
- Use meaningful names for beads
- Handle errors gracefully
- Log important events
- Test edge cases

## Need Help?

See the full documentation in:
- SKILL.md - Complete API reference
- README.md - Overview and usage patterns
