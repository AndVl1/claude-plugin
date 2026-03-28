---
name: mcp-patterns
description: "Model Context Protocol (MCP) patterns for AI agent context management, external resource access, and tool integration. Use this skill when the user asks to: (1) implement MCP servers, (2) create MCP clients, (3) integrate external resources with agents, (4) manage context across multiple sessions, (5) implement tool chaining with MCP, (6) design context-aware workflows, or (7) understand MCP patterns for agent orchestration. Trigger on phrases like \"MCP patterns\", \"Model Context Protocol\", \"context management\", \"external resources\", \"tool integration\", \"MCP server\", \"MCP client\", or \"agent context\"."
---

# MCP Patterns (Model Context Protocol)

Model Context Protocol (MCP) is a standard for enabling AI agents to access and work with external contexts, tools, and resources in a structured, portable way.

## Core Concepts

### What is MCP?

MCP defines a set of patterns for:
- **Context sharing**: Exchange structured data between agents
- **Resource access**: Provide read/write access to external data sources
- **Tool integration**: Expose tools as MCP operations
- **Context management**: Maintain session continuity and history

### MCP vs Traditional Patterns

| Aspect | MCP | Traditional Context |
|--------|-----|---------------------|
| Format | Structured JSON/Protocol Buffers | Free text, logs |
| Transport | HTTP/WebSocket, stdio | File system, memory |
| Queryable | Yes (structured queries) | No (text search only) |
| Type-safe | Yes (schemas) | No |
| Reusable | Yes (portable) | No ( tied to session) |
| Collaboration | Yes (shared) | No (isolated) |

---

## MCP Pattern: Context Provider

### Purpose

Provide a structured way to share context between agents and sessions.

### Implementation

```kotlin
// Server-side Context Provider
class McpContextProvider(
    private val repository: TrainingRepository
) {
    suspend fun getContextForSession(sessionId: String): ContextBundle {
        return ContextBundle(
            sessionId = sessionId,
            trainingHistory = repository.getRecentWorkouts(sessionId),
            performanceMetrics = repository.getMetrics(sessionId),
            preferences = repository.getPreferences(sessionId),
            lastAnalysis = repository.getLastAnalysis(sessionId)
        )
    }

    suspend fun updateContext(
        sessionId: String,
        update: ContextUpdate
    ) {
        when (update.type) {
            is ContextUpdate.AddWorkout -> repository.addWorkout(sessionId, update.workout)
            is ContextUpdate.UpdateMetrics -> repository.updateMetrics(sessionId, update.metrics)
        }
    }
}

data class ContextBundle(
    val sessionId: String,
    val trainingHistory: List<TrainingLog>,
    val performanceMetrics: PerformanceMetrics,
    val preferences: UserPreferences,
    val lastAnalysis: AnalysisResult?,
    val timestamp: Long
)

data class ContextUpdate(
    val type: UpdateType,
    val sessionId: String
)

sealed class ContextUpdate {
    data class AddWorkout(
        val sessionId: String,
        val workout: TrainingLog
    ) : ContextUpdate()

    data class UpdateMetrics(
        val sessionId: String,
        val metrics: PerformanceMetrics
    ) : ContextUpdate()
}
```

### Client Integration

```kotlin
// Client-side Context Consumer
class McpContextClient(
    private val serverUrl: String,
    private val sessionId: String
) {
    suspend fun loadContext(): ContextBundle {
        val response = httpClient.get("$serverUrl/context/$sessionId")
        return response.body()
    }

    suspend fun updateContext(update: ContextUpdate) {
        val response = httpClient.post("$serverUrl/context/update") {
            body = update
        }
        return response.body()
    }
}
```

---

## MCP Pattern: Resource Access

### Purpose

Provide structured access to external resources (files, APIs, databases) through MCP.

### Implementation

```kotlin
// Resource Server
class McpResourceServer(
    private val resourceManager: ResourceManager
) {
    suspend fun getResource(type: ResourceType, id: String): ResourceContent {
        return when (type) {
            ResourceType.TrainingLog -> {
                val log = resourceManager.getTrainingLog(id)
                ResourceContent(
                    type = ResourceType.TrainingLog,
                    id = id,
                    content = log.toJson(),
                    metadata = mapOf(
                        "date" to log.date.toString(),
                        "duration" to log.duration.toString()
                    )
                )
            }
            ResourceType.UserPreferences -> {
                val prefs = resourceManager.getPreferences(id)
                ResourceContent(
                    type = ResourceType.UserPreferences,
                    id = id,
                    content = prefs.toJson(),
                    metadata = prefs.toMap()
                )
            }
        }
    }

    suspend fun createResource(
        type: ResourceType,
        content: String,
        metadata: Map<String, Any>
    ): String {
        val resourceId = UUID.randomUUID().toString()
        val resource = MappedResource(
            id = resourceId,
            type = type,
            content = content,
            metadata = metadata,
            createdAt = System.currentTimeMillis()
        )
        resourceManager.saveResource(resource)
        return resourceId
    }
}

enum class ResourceType {
    TrainingLog,
    UserPreferences,
    AnalysisResult,
    PerformanceMetrics
}

data class ResourceContent(
    val type: ResourceType,
    val id: String,
    val content: String,
    val metadata: Map<String, Any>
)
```

### Usage Pattern

```kotlin
// Agent consuming resources
class McpAgent(
    private val resourceServer: McpResourceServer
) {
    suspend fun analyzeTraining(id: String): AnalysisResult {
        // Load training data as resource
        val resource = resourceServer.getResource(ResourceType.TrainingLog, id)

        // Parse structured content
        val log = Json.decodeFromString<TrainingLog>(resource.content)

        // Perform analysis
        return performAnalysis(log)
    }
}
```

---

## MCP Pattern: Tool Integration

### Purpose

Expose agent tools as MCP operations for cross-agent interoperability.

### Implementation

```kotlin
// Tool Server
class McpToolServer(
    private val toolRegistry: ToolRegistry
) {
    suspend fun executeTool(
        toolName: String,
        parameters: Map<String, Any>
    ): ToolResult {
        val tool = toolRegistry.getTool(toolName)
            ?: return ToolResult.Error("Tool not found: $toolName")

        return try {
            val result = tool.execute(parameters)
            ToolResult.Success(
                name = toolName,
                output = result.toJson(),
                executionTime = result.executionTime
            )
        } catch (e: Exception) {
            ToolResult.Error(
                name = toolName,
                error = e.message ?: "Unknown error",
                details = e.stackTraceToString()
            )
        }
    }
}

interface Tool {
    suspend fun execute(params: Map<String, Any>): ToolExecutionResult
}

data class ToolExecutionResult(
    val data: Any,
    val executionTime: Long
)

data class ToolResult(
    val name: String,
    val success: Boolean,
    val output: String? = null,
    val error: String? = null,
    val details: String? = null,
    val executionTime: Long? = null
) {
    companion object {
        fun success(name: String, data: Any): ToolResult {
            return ToolResult(
                name = name,
                success = true,
                output = data.toJson(),
                executionTime = System.currentTimeMillis()
            )
        }

        fun error(name: String, message: String, details: String? = null): ToolResult {
            return ToolResult(
                name = name,
                success = false,
                error = message,
                details = details
            )
        }
    }
}
```

---

## MCP Pattern: Context-aware Workflow

### Purpose

Create workflows that automatically load and manage MCP context.

### Implementation

```kotlin
// Context-aware workflow manager
class McpWorkflowManager(
    private val contextProvider: McpContextProvider,
    private val resourceServer: McpResourceServer,
    private val toolServer: McpToolServer
) {
    suspend fun executeWorkflow(
        workflowId: String,
        sessionId: String,
        params: Map<String, Any>
    ): WorkflowResult {
        // Load context
        val context = contextProvider.getContextForSession(sessionId)

        // Load required resources
        val resources = loadRequiredResources(workflowId, context)

        // Execute tool operations
        val toolResults = executeWorkflowTools(workflowId, resources)

        // Update context
        updateContext(sessionId, context, toolResults)

        return WorkflowResult(
            workflowId = workflowId,
            sessionId = sessionId,
            resources = resources,
            toolResults = toolResults,
            timestamp = System.currentTimeMillis()
        )
    }

    private suspend fun loadRequiredResources(
        workflowId: String,
        context: ContextBundle
    ): Map<String, String> {
        return when (workflowId) {
            "analyze-training" -> mapOf(
                "trainingLog" to context.trainingHistory.firstOrNull()?.toJson() ?: ""
            )
            "generate-insights" -> mapOf(
                "performance" to context.performanceMetrics.toJson(),
                "recentWorkouts" to context.trainingHistory.take(5).joinToString("\n") { it.toJson() }
            )
            else -> emptyMap()
        }
    }
}

data class WorkflowResult(
    val workflowId: String,
    val sessionId: String,
    val resources: Map<String, String>,
    val toolResults: List<ToolResult>,
    val timestamp: Long
)
```

---

## MCP Pattern: Context Chain

### Purpose

Chain multiple MCP operations in a sequence with automatic context propagation.

### Implementation

```kotlin
// Context chain executor
class McpContextChain(
    private val chainDefinition: List<McpChainStep>
) {
    suspend fun executeChain(
        sessionId: String,
        initialInput: String
    ): ChainResult {
        var currentInput = initialInput
        val outputs = mutableListOf<String>()
        val intermediateContext = mutableMapOf<String, Any>()

        for (step in chainDefinition) {
            val result = when (step.type) {
                ChainStepType.LoadResource -> loadResource(step, sessionId)
                ChainStepType.CallTool -> callTool(step, intermediateContext)
                ChainStepType.Process -> processContext(step, currentInput, intermediateContext)
                ChainStepType.StoreContext -> storeContext(step, sessionId, intermediateContext)
            }

            outputs.add(result)
            currentInput = result
        }

        return ChainResult(
            sessionId = sessionId,
            inputs = listOf(initialInput) + outputs.dropLast(1),
            outputs = outputs,
            context = intermediateContext,
            timestamp = System.currentTimeMillis()
        )
    }

    private suspend fun loadResource(
        step: McpChainStep,
        sessionId: String
    ): String {
        val resourceServer = McpResourceServer(...) // injected
        val content = resourceServer.getResource(step.resourceType, step.resourceId).content
        return content
    }

    private suspend fun callTool(
        step: McpChainStep,
        context: MutableMap<String, Any>
    ): String {
        val toolServer = McpToolServer(...) // injected
        val params = step.parameters ?: mapOf()
        val result = toolServer.executeTool(step.toolName, params)
        return result.output ?: "No output"
    }

    private suspend fun processContext(
        step: McpChainStep,
        input: String,
        context: MutableMap<String, Any>
    ): String {
        // Process context and update
        context["processedInput"] = input
        return "Processed: ${input.length} characters"
    }

    private suspend fun storeContext(
        step: McpChainStep,
        sessionId: String,
        context: MutableMap<String, Any>
    ) {
        val contextProvider = McpContextProvider(...) // injected
        contextProvider.updateContext(sessionId, ContextUpdate.UpdateContext(context))
    }
}

data class ChainResult(
    val sessionId: String,
    val inputs: List<String>,
    val outputs: List<String>,
    val context: Map<String, Any>,
    val timestamp: Long
)

enum class ChainStepType {
    LoadResource,
    CallTool,
    Process,
    StoreContext
}

data class McpChainStep(
    val id: String,
    val type: ChainStepType,
    val resourceId: String? = null,
    val resourceType: ResourceType? = null,
    val toolName: String? = null,
    val parameters: Map<String, Any>? = null
)
```

---

## MCP Pattern: Dynamic Context Loading

### Purpose

Load only relevant context based on current task requirements.

### Implementation

```kotlin
// Dynamic context loader
class DynamicContextLoader(
    private val contextProvider: McpContextProvider,
    private val taskAnalyzer: TaskAnalyzer
) {
    suspend fun loadContextForTask(
        sessionId: String,
        taskDescription: String
    ): ContextBundle {
        // Analyze task to determine required context
        val requiredContext = taskAnalyzer.analyzeRequirements(taskDescription)

        // Load only required parts
        return when (requiredContext.priority) {
            ContextPriority.High -> {
                // Load full context
                contextProvider.getContextForSession(sessionId)
            }
            ContextPriority.Medium -> {
                // Load recent training history + metrics
                val context = contextProvider.getContextForSession(sessionId)
                context.copy(
                    trainingHistory = context.trainingHistory.take(10),
                    performanceMetrics = context.performanceMetrics
                )
            }
            ContextPriority.Low -> {
                // Load minimal context
                val context = contextProvider.getContextForSession(sessionId)
                context.copy(
                    trainingHistory = emptyList(),
                    preferences = context.preferences,
                    lastAnalysis = null
                )
            }
        }
    }
}

data class ContextPriority(
    val level: Int // High=1, Medium=2, Low=3
) {
    companion object {
        val High = ContextPriority(1)
        val Medium = ContextPriority(2)
        val Low = ContextPriority(3)
    }
}

class TaskAnalyzer {
    fun analyzeRequirements(task: String): ContextPriority {
        val taskLower = task.lowercase()

        return when {
            taskLower.contains("comprehensive") ||
            taskLower.contains("complete analysis") ||
            taskLower.contains("all") -> ContextPriority.High

            taskLower.contains("recent") ||
            taskLower.contains("last") ||
            taskLower.contains("summary") -> ContextPriority.Medium

            taskLower.contains("quick") ||
            taskLower.contains("brief") ||
            taskLower.contains("estimate") -> ContextPriority.Low

            else -> ContextPriority.Medium
        }
    }
}
```

---

## MCP Pattern: Context Synchronization

### Purpose

Keep context in sync across multiple agents and sessions.

### Implementation

```kotlin
// Context synchronization service
class McpContextSyncService(
    private val primaryContext: McpContextProvider,
    private val secondaryContexts: List<McpContextProvider>
) {
    suspend fun syncContext(sessionId: String) {
        val primaryContext = primaryContext.getContextForSession(sessionId)

        for (secondary in secondaryContexts) {
            // Send delta updates only
            val delta = calculateDelta(
                primary = primaryContext,
                secondary = secondary.getContextForSession(sessionId)
            )
            secondary.updateContext(sessionId, delta)
        }
    }

    private suspend fun calculateDelta(
        primary: ContextBundle,
        secondary: ContextBundle
    ): ContextUpdate {
        val changes = mutableListOf<ContextUpdate>()

        // Check training history
        val newWorkouts = primary.trainingHistory.filterNot {
            secondary.trainingHistory.any { it.id == it.id }
        }
        if (newWorkouts.isNotEmpty()) {
            changes.add(ContextUpdate.AddWorkout(
                sessionId = primary.sessionId,
                workout = newWorkouts.first()
            ))
        }

        // Check metrics
        if (primary.performanceMetrics != secondary.performanceMetrics) {
            changes.add(ContextUpdate.UpdateMetrics(
                sessionId = primary.sessionId,
                metrics = primary.performanceMetrics
            ))
        }

        return ContextUpdate.Batch(changes)
    }
}
```

---

## Integration with Existing Skills

### Combine with RAG Memory

```kotlin
class EnhancedRagMcpAgent(
    private val ragSystem: RAGMemorySystem,
    private val mcpProvider: McpContextProvider
) {
    suspend fun analyzeWithMcpContext(query: String): AnalysisResult {
        // Load MCP context first
        val context = mcpProvider.getContextForSession(currentSessionId)

        // Combine RAG retrieval with MCP context
        val retrievedDocs = ragSystem.retrieve(query)
        val combinedContext = context.trainingHistory.joinToString("\n") {
            it.description
        } + "\n\n" + retrievedDocs.joinToString("\n")

        // Generate analysis using combined context
        return analyzeWithDeepSeek(combinedContext)
    }
}
```

### Combine with ReAct Pattern

```kotlin
class McpReActAgent(
    private val mcpProvider: McpContextProvider,
    private val reActPattern: ReActWorkflow
) {
    suspend fun executeTask(task: String): String {
        // Load MCP context before starting ReAct loop
        val context = mcpProvider.getContextForSession(sessionId)

        // Start ReAct with context-aware prompts
        return reActPattern.execute(
            prompt = task,
            context = context
        )
    }
}
```

---

## Best Practices

### 1. Schema-First Design

Define clear JSON schemas for all MCP data structures:

```kotlin
// Schema definitions
object McpSchemas {
    val ContextBundle = Json {
        encodeDefaults = true
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    val ResourceContent = Json {
        encodeDefaults = true
        ignoreUnknownKeys = true
        coerceInputValues = true
    }

    val ToolResult = Json {
        encodeDefaults = true
        ignoreUnknownKeys = true
        coerceInputValues = true
    }
}
```

### 2. Error Handling

Implement robust error handling for all MCP operations:

```kotlin
sealed class McpError : Exception() {
    data class ResourceNotFound(val type: ResourceType, val id: String) : McpError()
    data class ToolExecutionFailed(
        val toolName: String,
        val error: String,
        val details: String?
    ) : McpError()
    data class ContextNotAvailable(val sessionId: String) : McpError()
    data class InvalidParameters(val paramName: String) : McpError()
}

suspend fun safeMcpOperation(
    operation: suspend () -> ToolResult
): Result<ToolResult> {
    return try {
        Result.success(operation())
    } catch (e: McpError) {
        Result.failure(e)
    } catch (e: Exception) {
        Result.failure(McpError.ToolExecutionFailed("unknown", e.message ?: "", null))
    }
}
```

### 3. Performance Optimization

Cache MCP responses and implement lazy loading:

```kotlin
class CachedMcpContextProvider(
    private val delegate: McpContextProvider,
    private val cache: CacheManager
) : McpContextProvider by delegate {
    override suspend fun getContextForSession(sessionId: String): ContextBundle {
        val cacheKey = "context:$sessionId"

        return cache.get(cacheKey) {
            delegate.getContextForSession(sessionId)
        }
    }

    override suspend fun updateContext(
        sessionId: String,
        update: ContextUpdate
    ) {
        delegate.updateContext(sessionId, update)
        cache.invalidate("context:$sessionId")
    }
}
```

### 4. Testing Strategy

Test MCP patterns independently:

```kotlin
@Test
fun `McpContextProvider returns correct context for session`() {
    val provider = McpContextProvider(mockRepository)
    val context = provider.getContextForSession("session-123")

    assertEquals("session-123", context.sessionId)
    assertNotNull(context.trainingHistory)
    assertNotNull(context.performanceMetrics)
}

@Test
fun `McpContextChain executes steps in order`() = runTest {
    val chain = McpContextChain(listOf(
        McpChainStep("1", ChainStepType.CallTool, toolName = "tool1"),
        McpChainStep("2", ChainStepType.Process),
        McpChainStep("3", ChainStepType.CallTool, toolName = "tool2")
    ))

    val result = chain.executeChain("session", "input")

    assertEquals(3, result.outputs.size)
    assertEquals("tool2", result.outputs.last())
}
```

---

## Common Use Cases

### Use Case 1: Training Analytics Agent

```kotlin
class TrainingAnalyticsAgent(
    private val mcpProvider: McpContextProvider,
    private val ragSystem: RAGMemorySystem
) {
    suspend fun generateWeeklyReport(sessionId: String): Report {
        val context = mcpProvider.getContextForSession(sessionId)

        return Report(
            sessionId = sessionId,
            dateRange = "last week",
            trainingVolume = context.trainingHistory
                .filter { isInLastWeek(it.date) }
                .sumOf { it.duration },
            performanceTrend = analyzeTrend(context.trainingHistory),
            insights = generateInsights(context.trainingHistory)
        )
    }
}
```

### Use Case 2: Personalized Recommendations

```kotlin
class RecommendationAgent(
    private val mcpProvider: McpContextProvider
) {
    suspend fun generateRecommendations(sessionId: String): List<Recommendation> {
        val context = mcpProvider.getContextForSession(sessionId)

        return context.trainingHistory
            .take(30)
            .map { workout ->
                Recommendation(
                    workoutId = workout.id,
                    type = detectPattern(workout),
                    priority = calculatePriority(workout, context.performanceMetrics)
                )
            }
            .sortedByDescending { it.priority }
    }

    private fun detectPattern(workout: TrainingLog): RecommendationType {
        // Logic to detect workout patterns
    }

    private fun calculatePriority(
        workout: TrainingLog,
        metrics: PerformanceMetrics
    ): Int {
        // Logic to calculate recommendation priority
    }
}
```

### Use Case 3: Multi-Agent Collaboration

```kotlin
class MultiAgentMcpSystem(
    private val agent1: McpAgent,
    private val agent2: McpAgent,
    private val mcpSync: McpContextSyncService
) {
    suspend fun collaborateOnTask(
        taskId: String,
        taskDescription: String
    ): CollaborationResult {
        // Load shared context
        val context = mcpSync.syncContext(taskId)

        // Distribute work
        val part1 = agent1.process(taskDescription, context.trainingHistory)
        val part2 = agent2.process(taskDescription, context.performanceMetrics)

        // Merge results
        return CollaborationResult(
            taskId = taskId,
            agent1Output = part1,
            agent2Output = part2,
            merged = mergeResults(part1, part2)
        )
    }
}
```

---

## Migration Guide

### From Traditional Context to MCP

#### Before

```kotlin
// Poor context management
fun analyzeWorkout(workout: Workout) {
    val history = readAllWorkoutHistory() // Loads everything
    val metrics = calculateMetrics(history) // Slow!
    val insights = generateInsights(metrics) // Limited context
}
```

#### After (MCP)

```kotlin
// Efficient context management
class McpTrainingAnalyzer(
    private val mcpProvider: McpContextProvider
) {
    suspend fun analyzeWorkout(workoutId: String) {
        // Load only relevant context
        val context = mcpProvider.getContextForSession(sessionId)
            .copy(trainingHistory = context.trainingHistory.take(10))

        // Process with focused context
        val insights = generateInsights(context)
    }
}
```

---

## Related Skills

- **rag-memory**: Advanced memory retrieval patterns (RAG)
- **react-pattern**: ReAct reasoning patterns
- **state-machine-workflow**: State machine workflows
- **tool-orchestration**: Tool chaining patterns
- **iterative-refinement**: Iterative improvement patterns

---

## Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io)
- [Agent Orchestration Patterns](https://docs.anthropic.com/claude/docs/agent-workflows)
- [Context Management](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Context)

---

*Version: 1.0.0 | Category: agent-patterns | Tags: mcp, context, resources, tools, orchestration*
