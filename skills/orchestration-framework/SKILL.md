---
name: orchestration-framework
description: "Apply a comprehensive orchestration framework combining Beads pattern, ReAct, Tree-of-Thoughts, and error recovery for complex multi-step workflows. Use this skill when the user asks to: (1) create orchestrations with chain of responsibility, (2) implement ReAct-style reasoning, (3) build self-correcting workflows with tree-of-thoughts, (4) handle errors gracefully with recovery, (5) orchestrate complex tasks across multiple skills, (6) implement dynamic skill pipelines, or (7) create robust, maintainable workflows."
---

# Orchestration Framework Skill

## Purpose

Implement a **comprehensive orchestration framework** that integrates multiple design patterns to create robust, maintainable, and scalable workflows for complex multi-step tasks.

## Overview

This framework combines:

### 1. **Beads Pattern** (Chain of Responsibility)
- Modular skill chains
- Context passing
- Request filtering
- Graceful error handling

### 2. **ReAct Pattern** (Reasoning + Acting)
- Thought process before action
- Action execution with observations
- Iterative refinement
- Explicit reasoning steps

### 3. **Tree-of-Thoughts** (Self-Correction)
- Exploring multiple paths
- Evaluating options
- Self-correction mechanisms
- Best path selection

### 4. **Error Recovery**
- Automatic retry logic
- Fallback strategies
- State preservation
- Error propagation

## When to Use

- **Complex Workflows** - Multi-step tasks requiring orchestration
- **Error Recovery** - Tasks that need graceful error handling
- **Reasoning-First** - Tasks that benefit from explicit thought process
- **Self-Correction** - Tasks that need to iterate and improve
- **Skill Orchestration** - Coordinating multiple skills
- **Dynamic Pipelines** - Pipelines built at runtime

## Core Components

### Beads (Chain of Responsibility)

```kotlin
/**
 * A bead in the chain of responsibility
 */
interface Bead<TContext, TRequest, TResponse> {
    suspend fun process(
        request: TRequest,
        context: TContext
    ): Result<TResponse>

    val name: String
}

/**
 * Shared context flowing through beads
 */
data class BeadContext(
    val requestId: String,
    val metadata: MutableMap<String, Any> = mutableMapOf(),
    val errors: MutableList<WorkflowError> = mutableListOf(),
    val startTime: Long = System.currentTimeMillis(),
    val customContext: MutableMap<String, Any> = mutableMapOf()
)

data class WorkflowError(
    val beadName: String,
    val message: String,
    val timestamp: Long = System.currentTimeMillis(),
    val cause: Throwable? = null
)
```

### ReAct Processor

```kotlin
/**
 * ReAct-style reasoning and action execution
 */
data class ReActThought(
    val thought: String,
    val action: String,
    val actionInput: String,
    val observation: String,
    val isFinal: Boolean = false
)

data class ReActStep(
    val reasoning: ReActThought,
    val result: Any?
)

suspend fun <TRequest, TResponse> executeReAct(
    request: TRequest,
    reasoner: suspend (TRequest, ReActThought?) -> ReActThought,
    executor: suspend (TRequest, ReActThought) -> Result<TResponse>,
    maxIterations: Int = 5,
    evaluation: suspend (ReActThought, TResponse?) -> Boolean = { _, _ -> true }
): Result<TResponse> {
    var currentThought: ReActThought? = null
    var result: Any? = null

    repeat(maxIterations) { iteration ->
        currentThought = reasoner(request, currentThought)
        val stepResult = executor(request, currentThought)

        if (stepResult.isSuccess) {
            result = stepResult.getOrNull()
            if (evaluation(currentThought, result)) {
                return stepResult
            }
        }
    }

    return Result.failure(Exception("Max iterations reached"))
}
```

### Tree-of-Thought Orchestrator

```kotlin
/**
 * Tree-of-thoughts exploration
 */
sealed class ThoughtNode {
    abstract val id: String
    abstract val parent: ThoughtNode?
    abstract val thoughts: List<ReActThought>
    abstract val result: Any?
    abstract val explored: Boolean = false
}

class ThoughtNodeImpl(
    override val id: String,
    override val parent: ThoughtNode?,
    override val thoughts: List<ReActThought>,
    override val result: Any?,
    override val explored: Boolean = false
) : ThoughtNode()

suspend fun <TRequest, TResponse> exploreTreeOfThoughts(
    request: TRequest,
    rootThought: ReActThought,
    branchingFactor: Int = 2,
    maxDepth: Int = 3,
    evaluator: suspend (ThoughtNode) -> Double,
    solver: suspend (ReActThought) -> ReActStep
): Result<TResponse> {
    val rootNode = ThoughtNodeImpl(
        id = "root",
        parent = null,
        thoughts = listOf(rootThought),
        result = null
    )

    var bestNode = rootNode
    var bestScore = evaluator(rootNode)

    val frontier = mutableListOf(rootNode)

    while (frontier.isNotEmpty() && frontier.size < Math.pow(branchingFactor, maxDepth).toInt()) {
        val currentNode = frontier.removeAt(0)
        currentNode.explored = true

        for (i in 1..branchingFactor) {
            val newThought = ReActThought(
                thought = "Exploring alternative path $i",
                action = "explore",
                actionInput = currentNode.thoughts.lastOrNull()?.actionInput ?: "",
                observation = "",
                isFinal = false
            )

            val (stepResult, step) = solver(newThought)
            val newNode = ThoughtNodeImpl(
                id = "${currentNode.id}-${i}",
                parent = currentNode,
                thoughts = currentNode.thoughts + newThought,
                result = step.result,
                explored = false
            )

            frontier.add(newNode)
            currentNode.children?.add(newNode)

            if (stepResult.isSuccess) {
                val score = evaluator(newNode)
                if (score > bestScore) {
                    bestScore = score
                    bestNode = newNode
                }
            }
        }
    }

    return if (bestNode.result != null) {
        Result.success(bestNode.result as TResponse)
    } else {
        Result.failure(Exception("No valid solution found"))
    }
}
```

### Error Recovery

```kotlin
/**
 * Error recovery configuration
 */
data class RecoveryConfig(
    val maxRetries: Int = 3,
    val retryDelayMs: Long = 1000,
    val onRetry: ((Int, Throwable) -> Unit)? = null,
    val fallbackStrategy: FallbackStrategy = FallbackStrategy.Retry,
    val recoverableErrors: Set<Exception> = setOf(
        IOException::class,
        TimeoutException::class
    )
)

enum class FallbackStrategy {
    RETRY,
    FALLBACK_BEAD,
    FALLBACK_SKILL,
    SKIP_BEAD,
    TERMINATE
}

suspend fun <T> executeWithRecovery(
    operation: suspend () -> Result<T>,
    config: RecoveryConfig = RecoveryConfig()
): Result<T> {
    var lastException: Throwable? = null

    repeat(config.maxRetries + 1) { attempt ->
        try {
            val result = operation()
            if (result.isSuccess) {
                return result
            } else {
                val exception = result.exceptionOrNull()
                lastException = exception

                if (attempt < config.maxRetries && exception in config.recoverableErrors) {
                    config.onRetry?.invoke(attempt + 1, exception)
                    delay(config.retryDelayMs)
                } else {
                    return result
                }
            }
        } catch (e: Exception) {
            lastException = e

            if (attempt < config.maxRetries && e in config.recoverableErrors) {
                config.onRetry?.invoke(attempt + 1, e)
                delay(config.retryDelayMs)
            } else {
                return Result.failure(e)
            }
        }
    }

    return Result.failure(lastException ?: Exception("Unknown error"))
}

suspend fun <TContext, TRequest, TResponse> executeBeadsWithRecovery(
    beads: List<Bead<TContext, TRequest, TResponse>>,
    request: TRequest,
    context: TContext,
    recoveryConfig: RecoveryConfig = RecoveryConfig()
): Result<TResponse> {
    var currentContext = context
    var lastError: WorkflowError? = null

    for (i in beads.indices) {
        val bead = beads[i]
        try {
            val result = executeWithRecovery(
                operation = { bead.process(request, currentContext) },
                config = recoveryConfig
            )

            if (result.isSuccess) {
                currentContext = context // Update context if needed
            } else {
                lastError = WorkflowError(
                    beadName = bead.name,
                    message = result.exceptionOrNull()?.message ?: "Unknown error",
                    cause = result.exceptionOrNull()
                )

                // Check fallback strategy
                when (recoveryConfig.fallbackStrategy) {
                    FallbackStrategy.FALLBACK_BEAD -> {
                        // Continue to next bead
                        continue
                    }
                    FallbackStrategy.TERMINATE -> {
                        return Result.failure(Exception("Failed at bead: ${bead.name}"))
                    }
                    else -> {
                        return result
                    }
                }
            }
        } catch (e: Exception) {
            lastError = WorkflowError(
                beadName = bead.name,
                message = e.message ?: "Unknown error",
                cause = e
            )

            when (recoveryConfig.fallbackStrategy) {
                FallbackStrategy.FALLBACK_BEAD -> continue
                FallbackStrategy.TERMINATE -> return Result.failure(e)
                else -> return Result.failure(e)
            }
        }
    }

    return Result.failure(Exception("No bead executed successfully"))
}
```

### Complete Orchestrator

```kotlin
/**
 * Main orchestration framework
 */
class Orchestrator<TContext, TRequest, TResponse>(
    private val beads: List<Bead<TContext, TRequest, TResponse>>,
    private val useReAct: Boolean = true,
    private val useTreeOfThoughts: Boolean = false,
    private val recoveryConfig: RecoveryConfig = RecoveryConfig()
) {
    suspend fun orchestrate(
        request: TRequest,
        context: TContext = createDefaultContext(request)
    ): Result<TResponse> {
        if (useReAct) {
            return executeReActWithBeads(request, context)
        } else {
            return executeBeadsWithRecovery(request, context)
        }
    }

    private suspend fun <T> executeReActWithBeads(
        request: TRequest,
        context: TContext
    ): Result<TResponse> {
        // Reasoner implementation
        val reasoner: suspend (TRequest, ReActThought?) -> ReActThought = { req, lastThought ->
            ReActThought(
                thought = generateThought(req, lastThought),
                action = generateAction(req, lastThought),
                actionInput = generateActionInput(req, lastThought),
                observation = "",
                isFinal = false
            )
        }

        // Executor that uses beads
        val executor: suspend (TRequest, ReActThought) -> Result<TResponse> = { req, thought ->
            val beadIndex = thought.action.toIntOrNull()?.coerceIn(0, beads.size - 1)
                ?: return Result.failure(Exception("Invalid bead index"))

            val bead = beads[beadIndex]
            executeWithRecovery(
                operation = { bead.process(req, context as TContext) },
                config = recoveryConfig
            )
        }

        // Evaluator
        val evaluator: suspend (ReActThought, TResponse?) -> Boolean = { _, _ -> true }

        return executeReAct(request, reasoner, executor, maxIterations = 5, evaluator)
    }

    private fun createDefaultContext(request: TRequest): TContext {
        // Create default context based on request type
        return context as TContext // This is a simplified version
    }
}
```

## Usage Examples

### Example 1: Skill Chain with Error Recovery

```kotlin
// Define beads
val beads = listOf(
    Bead<String, String, String> {
        name = "ValidationBead"

        suspend fun process(request: String, context: BeadContext): Result<String> {
            if (request.isBlank()) {
                return Result.failure(IllegalArgumentException("Request cannot be blank"))
            }
            return Result.success("Valid: $request")
        }
    },
    Bead<String, String, String> {
        name = "ProcessingBead"

        suspend fun process(request: String, context: BeadContext): Result<String> {
            // Simulate processing
            if (request == "error") {
                throw IOException("Processing failed")
            }
            return Result.success("Processed: $request")
        }
    },
    Bead<String, String, String> {
        name = "FormattingBead"

        suspend fun process(request: String, context: BeadContext): Result<String> {
            return Result.success(request.uppercase())
        }
    }
)

// Create orchestrator
val orchestrator = Orchestrator(
    beads = beads,
    useReAct = true,
    recoveryConfig = RecoveryConfig(
        maxRetries = 3,
        fallbackStrategy = FallbackStrategy.FALLBACK_BEAD
    )
)

// Execute
val result = orchestrator.orchestrate("hello")
result.fold(
    onSuccess = { println("Success: $it") },
    onFailure = { println("Error: $it") }
)
```

### Example 2: Tree-of-Thoughts Problem Solving

```kotlin
// Define solver for tree exploration
val solver: suspend (ReActThought) -> Pair<Result<Any>, ReActStep> = { thought ->
    val action = thought.action
    val actionInput = thought.actionInput

    val (stepResult, step) = when (action) {
        "search" -> {
            val results = performSearch(actionInput)
            Pair(Result.success(results), ReActStep(thought, results))
        }
        "evaluate" -> {
            val score = evaluateSolution(actionInput)
            Pair(Result.success(score), ReActStep(thought, score))
        }
        else -> Pair(Result.failure(Exception("Unknown action")), ReActStep(thought, null))
    }

    Pair(stepResult, step)
}

// Explore tree of thoughts
val result = exploreTreeOfThoughts(
    request = "Find best solution",
    rootThought = ReActThought(
        thought = "Start by searching for solutions",
        action = "search",
        actionInput = "",
        observation = "",
        isFinal = false
    ),
    branchingFactor = 2,
    maxDepth = 3,
    evaluator = { node ->
        node.thoughts.lastOrNull()?.action?.let { calculateScore(it) } ?: 0.0
    },
    solver = solver
)

result.fold(
    onSuccess = { println("Solution: $it") },
    onFailure = { println("No solution found") }
)
```

### Example 3: ReAct Reasoning

```kotlin
suspend fun solveComplexProblem(): Result<String> {
    return executeReAct(
        request = "Solve the equation x² + 5x + 6 = 0",
        reasoner = { req, _ ->
            ReActThought(
                thought = "I need to solve a quadratic equation. Let me factor it.",
                action = "analyze",
                actionInput = "quadratic equation",
                observation = "",
                isFinal = false
            )
        },
        executor = { req, thought ->
            // Factor the quadratic
            val solution = factorQuadratic(thought.actionInput)
            Result.success(solution)
        },
        maxIterations = 5,
        evaluation = { _, result ->
            result.toString().contains("x =") || result.toString().contains("roots")
        }
    )
}
```

## Best Practices

1. **Keep Beads Focused** - Each bead should have a single responsibility
2. **Design Context Carefully** - Ensure context carries necessary information
3. **Set Appropriate Retry Limits** - Prevent infinite loops
4. **Use Meaningful Error Messages** - Help users and developers debug
5. **Log Execution Flow** - Aid in monitoring and debugging
6. **Test Recovery Paths** - Ensure fallback strategies work
7. **Document Edge Cases** - What happens in corner cases?

## Performance Considerations

- **Bead Chain Overhead**: Minimal when beads are lightweight
- **ReAct Overhead**: Depends on reasoning quality and iterations
- **Tree-of-Thoughts Overhead**: Exponential with depth and branching factor
- **Memory Usage**: Depends on context size and exploration depth

## Integration with Skills

This framework can be integrated with other skills:

```kotlin
val orchestrator = Orchestrator(
    beads = listOf(
        SkillBead(validationSkill),
        SkillBead(codeAnalysisSkill),
        SkillBead(testGenerationSkill)
    ),
    useReAct = true
)
```

## Dependencies

None - pure Kotlin implementation

## References

- [Chain of Responsibility Pattern](https://en.wikipedia.org/wiki/Chain-of-responsibility_pattern)
- [ReAct: Language Agents with Verbal Reasoning](https://arxiv.org/abs/2210.03629)
- [Tree-of-Thoughts](https://arxiv.org/abs/2308.09687)
- [Skill Orchestration](https://refactoring.guru/design-patterns/chain-of-responsibility)
