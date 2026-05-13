# Orchestration Framework

A comprehensive orchestration framework combining Beads pattern, ReAct, Tree-of-Thoughts, and error recovery for complex multi-step workflows.

## Overview

This framework provides a unified approach to orchestrating complex workflows by integrating multiple design patterns:

- **Beads Pattern** (Chain of Responsibility) - Modular skill chains with context passing
- **ReAct Pattern** (Reasoning + Acting) - Explicit reasoning before action
- **Tree-of-Thoughts** - Self-correcting exploration of multiple paths
- **Error Recovery** - Automatic retry and fallback mechanisms

## Features

### 1. Beads Pattern Implementation
- Modular skill chains
- Context passing between beads
- Request filtering
- Graceful error handling

### 2. ReAct Pattern Integration
- Explicit thought process
- Action execution with observations
- Iterative refinement
- Reasoning quality evaluation

### 3. Tree-of-Thoughts Exploration
- Multi-path exploration
- Automatic best path selection
- Depth and branching control
- Evaluation metrics

### 4. Error Recovery
- Configurable retry logic
- Multiple fallback strategies
- State preservation
- Error propagation

## Quick Start

### Basic Skill Chain

```kotlin
val beads = listOf(
    Bead<String, String, String> {
        name = "Validation"

        suspend fun process(request: String, context: BeadContext): Result<String> {
            if (request.isBlank()) {
                return Result.failure(IllegalArgumentException("Blank request"))
            }
            return Result.success("Valid: $request")
        }
    },
    Bead<String, String, String> {
        name = "Processing"

        suspend fun process(request: String, context: BeadContext): Result<String> {
            return Result.success("Processed: $request")
        }
    }
)

val orchestrator = Orchestrator(beads, useReAct = true)
val result = orchestrator.orchestrate("hello")
```

### ReAct Reasoning

```kotlin
val result = executeReAct(
    request = "Solve the equation",
    reasoner = { _, _ ->
        ReActThought(
            thought = "Analyze the problem",
            action = "analyze",
            actionInput = "equation",
            observation = "",
            isFinal = false
        )
    },
    executor = { _, thought ->
        Result.success("Solution: x = 2")
    }
)
```

### Tree-of-Thoughts

```kotlin
val result = exploreTreeOfThoughts(
    request = "Find solution",
    rootThought = ReActThought(
        thought = "Start exploration",
        action = "search",
        actionInput = "",
        observation = "",
        isFinal = false
    ),
    branchingFactor = 2,
    maxDepth = 3
)
```

## Usage Scenarios

### Scenario 1: API Request Pipeline

```kotlin
val apiOrchestrator = Orchestrator(
    beads = listOf(
        AuthenticationBead(),
        ValidationBead(),
        RequestProcessingBead(),
        ResponseFormattingBead()
    ),
    recoveryConfig = RecoveryConfig(
        maxRetries = 3,
        fallbackStrategy = FallbackStrategy.FALLBACK_BEAD
    )
)
```

### Scenario 2: Code Generation Pipeline

```kotlin
val codeOrchestrator = Orchestrator(
    beads = listOf(
        RequirementAnalysisBead(),
        CodeDraftingBead(),
        CodeReviewBead(),
        TestGenerationBead()
    ),
    useReAct = true
)
```

### Scenario 3: Data Processing Pipeline

```kotlin
val dataOrchestrator = Orchestrator(
    beads = listOf(
        DataValidationBead(),
        DataTransformationBead(),
        DataEnrichmentBead(),
        DataExportBead()
    ),
    useReAct = false
)
```

## API Reference

### Bead Interface

```kotlin
interface Bead<TContext, TRequest, TResponse> {
    suspend fun process(request: TRequest, context: TContext): Result<TResponse>
    val name: String
}
```

### Orchestrator

```kotlin
class Orchestrator<TContext, TRequest, TResponse>(
    private val beads: List<Bead<TContext, TRequest, TResponse>>,
    private val useReAct: Boolean = true,
    private val useTreeOfThoughts: Boolean = false,
    private val recoveryConfig: RecoveryConfig = RecoveryConfig()
) {
    suspend fun orchestrate(request: TRequest, context: TContext): Result<TResponse>
}
```

### ReAct Functions

```kotlin
suspend fun <TRequest, TResponse> executeReAct(
    request: TRequest,
    reasoner: suspend (TRequest, ReActThought?) -> ReActThought,
    executor: suspend (TRequest, ReActThought) -> Result<TResponse>,
    maxIterations: Int = 5,
    evaluation: suspend (ReActThought, TResponse?) -> Boolean = { _, _ -> true }
): Result<TResponse>

suspend fun <TRequest, TResponse> exploreTreeOfThoughts(
    request: TRequest,
    rootThought: ReActThought,
    branchingFactor: Int = 2,
    maxDepth: Int = 3,
    evaluator: suspend (ThoughtNode) -> Double,
    solver: suspend (ReActThought) -> ReActStep
): Result<TResponse>
```

## Configuration

### RecoveryConfig

```kotlin
data class RecoveryConfig(
    val maxRetries: Int = 3,
    val retryDelayMs: Long = 1000,
    val onRetry: ((Int, Throwable) -> Unit)? = null,
    val fallbackStrategy: FallbackStrategy = FallbackStrategy.Retry,
    val recoverableErrors: Set<Exception> = setOf(IOException::class, TimeoutException::class)
)

enum class FallbackStrategy {
    RETRY,        // Retry the same operation
    FALLBACK_BEAD, // Continue to next bead
    FALLBACK_SKILL, // Use alternative skill
    SKIP_BEAD,     // Skip current bead
    TERMINATE      // Stop execution
}
```

## Best Practices

1. **Single Responsibility** - Each bead should have one clear purpose
2. **Minimal Context** - Pass only necessary data through context
3. **Error Handling** - Define recoverable and non-recoverable errors
4. **Testing** - Test both success and failure paths
5. **Logging** - Log thoughts, actions, and results for debugging
6. **Monitoring** - Track metrics like retry count, error rate, execution time

## Performance Tips

- Use `useReAct = false` for simple linear workflows
- Limit `branchingFactor` and `maxDepth` for tree-of-thoughts
- Set appropriate `maxRetries` based on expected error rates
- Use lightweight beads for high-performance scenarios
- Cache expensive operations within beads

## Examples

See the `examples/` directory for detailed examples:
- `example-basic-orchestration.md` - Basic usage
- `example-react-reasoning.md` - ReAct pattern
- `example-tree-of-thoughts.md` - Tree-of-thoughts
- `example-error-recovery.md` - Error handling

## Integration

### With Skills

```kotlin
val skillOrchestrator = Orchestrator(
    beads = listOf(
        SkillBead(validationSkill),
        SkillBead(processingSkill),
        SkillBead(outputSkill)
    )
)
```

### With External Services

```kotlin
val serviceOrchestrator = Orchestrator(
    beads = listOf(
        AuthBead(),
        ValidationBead(),
        ServiceBead(),
        LoggingBead()
    )
)
```

## Dependencies

None - pure Kotlin implementation

## License

MIT License

## Contributing

Contributions welcome! Please:
1. Follow the existing code style
2. Add tests for new features
3. Update documentation
4. Add usage examples

## Authors

- Klavdii R&D Team

## Version History

- **1.0.0** - Initial release
  - Beads pattern implementation
  - ReAct pattern integration
  - Tree-of-thoughts exploration
  - Error recovery mechanisms
  - Comprehensive documentation
