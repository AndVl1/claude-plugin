---
name: koog
description: JetBrains Koog AI Agent framework (Kotlin) - use for building AI agents with tool calling, LLM integration via OpenRouter/OpenAI/Anthropic/Google/DeepSeek, streaming, GOAP planning, MCP integration, and AI-powered workflows. Use when implementing AI agents, LLM calls, tool-calling patterns, or integrating LLM providers in Kotlin projects.
---

# Koog AI Agent Framework

Kotlin Multiplatform framework for AI agents. Published on Maven Central under `ai.koog` group.

**Current version: `0.7.3`**

## Dependencies

`koog-agents` is the umbrella module — it transitively includes all sub-modules (agents-core, agents-ext, all provider clients, tools, prompt DSL, etc.).

```kotlin
// build.gradle.kts — minimal setup (JVM project)
repositories { mavenCentral() }

val koogVersion = "0.7.3"

dependencies {
    implementation("ai.koog:koog-agents:$koogVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.1")
}
```

No need to add individual sub-modules like `prompt-executor-openrouter-client` — they come via `koog-agents`.

For Spring Boot, also add: `implementation("ai.koog:koog-ktor:$koogVersion")`

## Import Paths (verified from 0.7.3 JARs)

```
// Agent
ai.koog.agents.core.agent.AIAgent
ai.koog.agents.core.agent.config.AIAgentConfig
ai.koog.agents.core.agent.GraphAIAgent         // graph-based agent
ai.koog.agents.core.agent.FunctionalAIAgent    // functional agent
ai.koog.agents.planner.PlannerAIAgent           // GOAP planner agent

// Tools
ai.koog.agents.core.tools.ToolRegistry
ai.koog.agents.core.tools.annotations.Tool
ai.koog.agents.core.tools.annotations.LLMDescription
ai.koog.agents.core.tools.reflect.ToolSet       // interface for annotation-based tools
ai.koog.agents.core.tools.reflect.tools          // extension for ToolRegistry DSL

// Strategies (predefined)
ai.koog.agents.ext.agent.chatAgentStrategy       // chat agent with tool loop
ai.koog.agents.ext.agent.reActStrategy           // ReAct pattern
ai.koog.agents.core.agent.singleRunStrategy      // single LLM call + tools
ai.koog.agents.core.agent.ToolCalls              // enum: SEQUENTIAL, PARALLEL, SINGLE_RUN_SEQUENTIAL
ai.koog.agents.ext.agent.singleRunStrategyWithHistoryCompression  // with auto history compression
ai.koog.agents.ext.agent.HistoryCompressionConfig

// GOAP Planner Strategy
ai.koog.agents.planner.AIAgentPlannerStrategy
ai.koog.agents.planner.AIAgentPlannerStrategyBuilder
ai.koog.agents.planner.GOAPStrategyBuilder
ai.koog.agents.planner.goap.GoapAgentState

// Strategy DSL (custom strategies)
ai.koog.agents.core.dsl.builder.strategy
ai.koog.agents.core.dsl.builder.forwardTo
ai.koog.agents.core.dsl.extension.nodeLLMRequest
ai.koog.agents.core.dsl.extension.nodeLLMRequestMultiple      // multiple responses
ai.koog.agents.core.dsl.extension.nodeLLMRequestStreaming      // streaming
ai.koog.agents.core.dsl.extension.nodeExecuteTool
ai.koog.agents.core.dsl.extension.nodeExecuteMultipleTools     // parallel tool execution
ai.koog.agents.core.dsl.extension.nodeLLMSendToolResult
ai.koog.agents.core.dsl.extension.nodeLLMSendMultipleToolResults
ai.koog.agents.core.dsl.extension.nodeSetStructuredOutput
ai.koog.agents.core.dsl.extension.nodeLLMCompressHistory
ai.koog.agents.core.dsl.extension.onAssistantMessage
ai.koog.agents.core.dsl.extension.onMultipleAssistantMessages
ai.koog.agents.core.dsl.extension.onToolCall
ai.koog.agents.core.dsl.extension.onMultipleToolCalls
ai.koog.agents.core.dsl.extension.HistoryCompressionStrategy   // WholeHistory, FromLastNMessages, Chunked, etc.

// Prompt
ai.koog.prompt.dsl.Prompt
ai.koog.prompt.dsl.prompt

// Executor
ai.koog.prompt.executor.llms.SingleLLMPromptExecutor

// Providers — see references/providers.md for full list
ai.koog.prompt.executor.clients.openrouter.OpenRouterLLMClient
ai.koog.prompt.executor.clients.openrouter.OpenRouterModels
ai.koog.prompt.executor.clients.openrouter.OpenRouterParams
ai.koog.prompt.executor.clients.openai.OpenAILLMClient
ai.koog.prompt.executor.clients.openai.OpenAIModels
ai.koog.prompt.executor.llms.all.simpleOpenAIExecutor

// Structured Output — see references/structured-output.md for full reference
ai.koog.prompt.structure.StructuredRequest          // sealed: Manual, Native
ai.koog.prompt.structure.StructuredRequestConfig     // replaces old StructuredOutputConfig
ai.koog.prompt.structure.StructuredResponse
ai.koog.prompt.structure.Structure                   // base interface (was StructuredData)
ai.koog.prompt.structure.json.JsonStructure          // was JsonStructuredData
ai.koog.prompt.executor.model.StructureFixingParser  // MOVED from prompt.structure package
ai.koog.agents.ext.agent.structuredOutputWithToolsStrategy

// Streaming
ai.koog.prompt.streaming.StreamFrame                 // sealed: TextDelta, TextComplete, ReasoningDelta, ReasoningComplete, ToolCallDelta, ToolCallComplete, End

// LLModel (custom model definitions)
ai.koog.prompt.llm.LLModel
ai.koog.prompt.llm.LLMProvider       // subclasses: OpenRouter, OpenAI, Anthropic, Google, etc.
ai.koog.prompt.llm.LLMCapability     // singletons: Completion, Temperature, Tools, Schema.JSON.Basic, etc.

// Response Processing
ai.koog.prompt.processor.ResponseProcessor           // NEW: post-process LLM responses (extract tool calls from text)

// MCP Integration
ai.koog.agents.mcp.McpToolRegistryProvider           // fromClient, fromTransport, fromSseUrl
ai.koog.agents.mcp.metadata.McpServerInfo
```

## AIAgent Constructor

The simplest `String→String` overload:

```kotlin
AIAgent(
    promptExecutor: PromptExecutor,
    llmModel: LLModel,
    responseProcessor: ResponseProcessor? = null,     // NEW in 0.7.x: post-process LLM responses
    strategy: AIAgentGraphStrategy<String, String> = singleRunStrategy(),
    toolRegistry: ToolRegistry = ToolRegistry.EMPTY,
    id: String? = null,
    systemPrompt: String? = null,                     // CHANGED: now nullable
    temperature: Double? = null,                      // CHANGED: now nullable
    numberOfChoices: Int = 1,
    maxIterations: Int = 50,
    installFeatures: FeatureContext.() -> Unit = {}
): AIAgent<String, String>
```

AIAgentConfig-based overload:

```kotlin
AIAgent(
    promptExecutor: PromptExecutor,
    agentConfig: AIAgentConfig,
    strategy: AIAgentGraphStrategy<Input, Output>,
    toolRegistry: ToolRegistry = ToolRegistry.EMPTY,
    id: String? = null,
    clock: Clock = Clock.System,
    installFeatures: FeatureContext.() -> Unit = {},
): AIAgent<Input, Output>
```

AIAgentConfig constructor:

```kotlin
AIAgentConfig(
    prompt: Prompt,
    model: LLModel,
    maxAgentIterations: Int,
    missingToolsConversionStrategy: MissingToolsConversionStrategy = MissingToolsConversionStrategy.Missing(ToolCallDescriber.JSON),
    responseProcessor: ResponseProcessor? = null,
    serializer: JSONSerializer = KotlinxSerializer(),
)

// Convenience factory:
AIAgentConfig.withSystemPrompt(
    prompt = "You are a helpful assistant",
    llm = OpenAIModels.Chat.GPT4o,
    id = "koog-agents",
    maxAgentIterations = 3
)
```

### Agent Types

| Type | Strategy | Use case |
|------|----------|----------|
| `GraphAIAgent<I, O>` | `AIAgentGraphStrategy` | Custom strategy graphs (most common) |
| `FunctionalAIAgent<I, O>` | `AIAgentFunctionalStrategy` | Simple functional agents |
| `PlannerAIAgent<I, O>` | `AIAgentPlannerStrategy` (GOAP) | Goal-oriented planning |

### Java Builder API

```java
AIAgent<String, String> agent = AIAgent.builder()
    .promptExecutor(executor)
    .systemPrompt("You are a helpful assistant.")
    .llmModel(OpenAIModels.Chat.GPT4o)
    .toolRegistry(toolRegistry)
    .build();
```

## Annotation-Based Tools

```kotlin
import ai.koog.agents.core.tools.annotations.LLMDescription
import ai.koog.agents.core.tools.annotations.Tool
import ai.koog.agents.core.tools.reflect.ToolSet

@LLMDescription("Tools for file operations")
class FileTools : ToolSet {

    @Tool
    @LLMDescription("Read file contents")
    fun readFile(
        @LLMDescription("Path to file") path: String
    ): String {
        return java.io.File(path).readText()
    }

    @Tool
    @LLMDescription("List files in directory")
    fun listFiles(
        @LLMDescription("Directory path") dir: String
    ): String {
        return java.io.File(dir).listFiles()?.joinToString("\n") { it.name } ?: "empty"
    }
}
```

Register in ToolRegistry:

```kotlin
import ai.koog.agents.core.tools.ToolRegistry
import ai.koog.agents.core.tools.reflect.tools

val toolRegistry = ToolRegistry {
    tools(FileTools())         // register all @Tool methods from ToolSet
    tools(AnotherToolSet())    // can register multiple
}
```

## Predefined Strategies

| Strategy | Import | Use case |
|----------|--------|----------|
| `chatAgentStrategy()` | `ai.koog.agents.ext.agent` | Chat with tool calling loop (most common) |
| `reActStrategy(reasoningInterval, name)` | `ai.koog.agents.ext.agent` | ReAct: reason→act→observe loop |
| `singleRunStrategy(runMode)` | `ai.koog.agents.core.agent` | Single LLM request + tool execution |
| `singleRunStrategyWithHistoryCompression(config)` | `ai.koog.agents.ext.agent` | Single run with auto history compression |

### singleRunStrategy run modes

```kotlin
import ai.koog.agents.core.agent.ToolCalls

singleRunStrategy(ToolCalls.SEQUENTIAL)          // multiple tools per call, executed sequentially (default)
singleRunStrategy(ToolCalls.PARALLEL)             // multiple tools per call, executed in parallel
singleRunStrategy(ToolCalls.SINGLE_RUN_SEQUENTIAL)  // one tool per LLM call
```

### History Compression Strategy

```kotlin
import ai.koog.agents.ext.agent.singleRunStrategyWithHistoryCompression
import ai.koog.agents.ext.agent.HistoryCompressionConfig
import ai.koog.agents.core.dsl.extension.HistoryCompressionStrategy

val strategy = singleRunStrategyWithHistoryCompression(
    config = HistoryCompressionConfig(
        isHistoryTooBig = { prompt -> prompt.messages.size > 50 },
        compressionStrategy = HistoryCompressionStrategy.WholeHistory,
        retrievalModel = null  // uses agent's model by default
    ),
    runMode = ToolCalls.SEQUENTIAL
)
```

Available compression strategies:
- `HistoryCompressionStrategy.NoCompression` — no-op
- `HistoryCompressionStrategy.WholeHistory` — TL;DR of entire history
- `HistoryCompressionStrategy.WholeHistoryMultipleSystemMessages` — handles multiple system messages
- `HistoryCompressionStrategy.FromLastNMessages(n)` — keep last N messages, summarize rest
- `HistoryCompressionStrategy.FromTimestamp(instant)` — keep messages after timestamp
- `HistoryCompressionStrategy.Chunked(chunkSize)` — chunk and summarize

## Complete Example: Agent with OpenRouter

```kotlin
import ai.koog.agents.core.agent.AIAgent
import ai.koog.agents.core.tools.ToolRegistry
import ai.koog.agents.core.tools.annotations.LLMDescription
import ai.koog.agents.core.tools.annotations.Tool
import ai.koog.agents.core.tools.reflect.ToolSet
import ai.koog.agents.core.tools.reflect.tools
import ai.koog.agents.ext.agent.chatAgentStrategy
import ai.koog.prompt.executor.clients.openrouter.OpenRouterLLMClient
import ai.koog.prompt.executor.clients.openrouter.OpenRouterModels
import ai.koog.prompt.executor.llms.SingleLLMPromptExecutor
import kotlinx.coroutines.runBlocking

@LLMDescription("Math tools")
class MathTools : ToolSet {
    @Tool
    @LLMDescription("Add two numbers")
    fun add(@LLMDescription("First number") a: Int, @LLMDescription("Second number") b: Int): String {
        return "Result: ${a + b}"
    }
}

fun main() = runBlocking {
    val client = OpenRouterLLMClient(apiKey = System.getenv("OPENROUTER_API_KEY"))
    val executor = SingleLLMPromptExecutor(client)

    val agent = AIAgent(
        promptExecutor = executor,
        llmModel = OpenRouterModels.DeepSeekV30324,
        strategy = chatAgentStrategy(),
        toolRegistry = ToolRegistry { tools(MathTools()) },
        systemPrompt = "You are a helpful assistant. Use tools when needed.",
        temperature = 0.7,
        maxIterations = 10
    )

    val result = agent.run("What is 42 + 58?")
    println(result)
}
```

## Streaming Example

```kotlin
import ai.koog.agents.core.dsl.extension.nodeLLMRequestStreaming
import ai.koog.prompt.streaming.StreamFrame
import kotlinx.coroutines.flow.Flow

val streamingStrategy = strategy<String, Flow<StreamFrame>>("streaming") {
    val nodeStream by nodeLLMRequestStreaming()
    edge(nodeStart forwardTo nodeStream)
    edge(nodeStream forwardTo nodeFinish)
}

// In event handler — capture streaming frames
val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    strategy = chatAgentStrategy(),
    toolRegistry = ToolRegistry.EMPTY,
    systemPrompt = "You are a helpful assistant."
) {
    handleEvents {
        onLLMStreamingFrameReceived { ctx ->
            when (val frame = ctx.streamFrame) {
                is StreamFrame.TextDelta -> print(frame.text)
                is StreamFrame.ReasoningDelta -> { /* reasoning text */ }
                is StreamFrame.ToolCallComplete -> { /* tool call received */ }
                is StreamFrame.End -> println("\n[Done: ${frame.finishReason}]")
                else -> {}
            }
        }
    }
}
```

## Prompt DSL (without agent)

```kotlin
import ai.koog.prompt.dsl.prompt
import ai.koog.prompt.executor.llms.SingleLLMPromptExecutor

val prompt = prompt("my-prompt") {
    system("You are a helpful assistant")
    user("Explain coroutines")
}

// Direct execution without agent
val response = executor.execute(prompt, model)
```

## Structured Output

For full reference, see [references/structured-output.md](references/structured-output.md).

### Quick Start: StructureFixingParser (standalone, most compatible)

Parse LLM text into typed data class, with auto-fix via a secondary model:

```kotlin
import ai.koog.prompt.executor.model.StructureFixingParser  // NOTE: moved in 0.7.x
import ai.koog.prompt.structure.json.JsonStructure           // NOTE: renamed from JsonStructuredData

// 1. Define structure from @Serializable class
val structure = JsonStructure.create<MyResponse>()
// or explicit:
val structure = JsonStructure.create(
    id = "MyResponse",
    serializer = MyResponse.serializer()
)

// 2. Create fixing parser with a cheap model
val fixingParser = StructureFixingParser(
    fixingModel = myModel,  // any LLModel
    retries = 3
)

// 3. Parse raw text (tries direct parse first, then fixes with LLM)
val result: MyResponse = fixingParser.parse(executor, structure, rawText)
```

### Custom LLModel (models not in predefined catalogs)

```kotlin
import ai.koog.prompt.llm.LLModel
import ai.koog.prompt.llm.LLMProvider
import ai.koog.prompt.llm.LLMCapability

val customModel = LLModel(
    provider = LLMProvider.OpenRouter,       // singleton objects
    id = "z-ai/glm-4.5-air",                // exact model ID from provider
    capabilities = listOf(
        LLMCapability.Completion,            // ALL are singletons — no ()
        LLMCapability.Temperature,
        LLMCapability.Schema.JSON.Basic
    ),
    contextLength = 128_000L,
    maxOutputTokens = 8_000L                 // nullable
)
```

### structuredOutputWithToolsStrategy (native, model-dependent)

Returns typed output directly from agent. **Caveat:** not all models support this via OpenRouter (DeepSeek breaks tool calling format).

```kotlin
import ai.koog.agents.ext.agent.structuredOutputWithToolsStrategy
import ai.koog.prompt.structure.StructuredRequestConfig       // NOTE: was StructuredOutputConfig
import ai.koog.prompt.structure.StructuredRequest

val config = StructuredRequestConfig<MyResponse>(
    default = StructuredRequest.Manual(structure),     // prompt-based (most compatible)
    byProvider = mapOf(
        LLMProvider.OpenAI to StructuredRequest.Native(structure)  // use native response_format
    )
)

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenRouterModels.GPT4o,
    strategy = structuredOutputWithToolsStrategy(
        config = config,
        fixingParser = fixingParser,      // optional
        parallelTools = false             // parallel tool execution
    ),
    toolRegistry = toolRegistry,
    systemPrompt = "..."
)

val typed: MyResponse = agent.run("input")
```

## Provider Quick Reference

For detailed provider configuration, see [references/providers.md](references/providers.md).

| Provider | Client class | Models object | Key env var |
|----------|-------------|---------------|-------------|
| OpenRouter | `OpenRouterLLMClient` | `OpenRouterModels` | `OPENROUTER_API_KEY` |
| OpenAI | `OpenAILLMClient` | `OpenAIModels.Chat` | `OPENAI_API_KEY` |
| Anthropic | `AnthropicLLMClient` | `AnthropicModels` | `ANTHROPIC_API_KEY` |
| Google | `GoogleLLMClient` | `GoogleModels` | `GOOGLE_API_KEY` |
| DeepSeek | `DeepSeekLLMClient` | `DeepSeekModels` | `DEEPSEEK_API_KEY` |
| AWS Bedrock | `BedrockLLMClient` | — | AWS credentials |
| Mistral AI | `MistralAILLMClient` | — | `MISTRAL_API_KEY` |
| DashScope | `DashscopeLLMClient` | — | `DASHSCOPE_API_KEY` |
| Ollama | `OllamaLLMClient` | — | — |

Note: `AbstractOpenAILLMClient` is the base for OpenAI, DeepSeek, OpenRouter, MistralAI, DashScope. Anthropic, Google, Ollama implement `LLMClient` directly. Bedrock uses AWS Converse API (JVM only).

## Custom Strategy DSL

For when predefined strategies aren't enough. Full reference: [references/strategies.md](references/strategies.md).

```kotlin
import ai.koog.agents.core.dsl.builder.forwardTo
import ai.koog.agents.core.dsl.builder.strategy
import ai.koog.agents.core.dsl.extension.*

val myStrategy = strategy<String, String>("my-agent") {
    val nodeLLM by nodeLLMRequest()
    val nodeExec by nodeExecuteTool()
    val nodeSend by nodeLLMSendToolResult()

    edge(nodeStart forwardTo nodeLLM)
    edge(nodeLLM forwardTo nodeFinish onAssistantMessage { true })
    edge(nodeLLM forwardTo nodeExec onToolCall { true })
    edge(nodeExec forwardTo nodeSend)
    edge(nodeSend forwardTo nodeFinish onAssistantMessage { true })
    edge(nodeSend forwardTo nodeExec onToolCall { true })
}
```

Key concepts (details in strategies.md):
- **Nodes**: `nodeLLMRequest`, `nodeLLMRequestMultiple`, `nodeLLMRequestStreaming`, `nodeExecuteTool`, `nodeExecuteMultipleTools`, `nodeLLMSendToolResult`, `nodeLLMSendMultipleToolResults`, `nodeSetStructuredOutput`, `nodeLLMCompressHistory`, custom `node<In, Out>`
- **Edges**: `forwardTo` + conditions (`onAssistantMessage`, `onMultipleAssistantMessages`, `onToolCall`, `onMultipleToolCalls`, `onCondition`) + `transformed`
- **Subgraphs**: isolated sections with own tools/model — `subgraph`, `subgraphWithTask`, `subgraphWithVerification`, `subgraphWithRetry`
- **Parallel**: `parallel(nodeA, nodeB, nodeC) { selectByMax { it } }`
- **Sequential**: `nodeStart then subgraphA then subgraphB then nodeFinish`
- **Structured output**: `nodeLLMRequestStructured<MyDataClass>(examples = [...])` or `nodeLLMRequestStructured(config = structuredRequestConfig)`
- **Streaming**: `nodeLLMRequestStreaming()` returns `Flow<StreamFrame>`

## GOAP Planner Strategy

Goal-Oriented Action Planning — agent decomposes tasks into action sequences:

```kotlin
import ai.koog.agents.planner.AIAgentPlannerStrategy
import ai.koog.agents.planner.goap.GoapAgentState

abstract class MyState(input: String, output: String?) : GoapAgentState<String, String>(input, output) {
    // define state properties and goals
}

val strategy = AIAgentPlannerStrategy.goap<String, String, MyState>(
    name = "my-goap",
    initializeState = { input -> MyInitialState(input) }
) {
    // define actions and goals
}

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    strategy = strategy,
    toolRegistry = toolRegistry,
    systemPrompt = "..."
)
```

## Agent Features & Built-in Tools

Features are installed in the AIAgent constructor's trailing lambda. Each has a dedicated reference:

- **[Structured Output](references/structured-output.md)** — typed responses via `StructuredRequestConfig`, `StructureFixingParser`, `JsonStructure`, custom `LLModel` creation, `structuredOutputWithToolsStrategy`
- **[EventHandler](references/event-handler.md)** — lifecycle callbacks (`onAgentStarting`, `onToolCallCompleted`, `onLLMCallCompleted`, streaming events), custom `AIAgentFeature` with pipeline interceptors
- **[Memory](references/memory.md)** — store/retrieve facts across conversations (Concept, Fact, MemoryScope, encrypted storage, memory nodes for strategy DSL)
- **[Tracing & Persistence](references/tracing-persistence.md)** — trace events to log/file/remote; checkpoint/restore agent state with rollback strategies
- **[Built-in Tools](references/built-in-tools.md)** — `AskUser`, `SayToUser`, `ExitTool`, `ReadFileTool`, `WriteFileTool`, `EditFileTool`, `ListDirectoryTool`, `ExecuteShellCommandTool`, `SimpleTool` class

```kotlin
val agent = AIAgent(...) {
    handleEvents {
        onAgentStarting { ctx -> println("Starting: ${ctx.agent.id}") }
        onToolCallCompleted { ctx -> println("Tool done") }
    }
    install(Tracing) { addMessageProcessor(TraceFeatureMessageLogWriter(logger)) }
    install(AgentMemory) { memoryProvider = LocalFileMemoryProvider(...) }
}

val registry = ToolRegistry {
    tool(AskUser)                                          // ai.koog.agents.ext.tool
    tool(SayToUser)
    tool(ReadFileTool(JVMFileSystemProvider.ReadOnly))      // ai.koog.agents.ext.tool.file
    tool(ExecuteShellCommandTool(BraveModeConfirmationHandler)) // ai.koog.agents.ext.tool.shell
    tools(MyToolSet())
}
```

## MCP Integration

```kotlin
import ai.koog.agents.mcp.McpToolRegistryProvider
import ai.koog.agents.mcp.metadata.McpServerInfo

// From SSE URL (simplest)
val toolRegistry = McpToolRegistryProvider.fromSseUrl("http://localhost:8931/sse")

// From existing MCP client
val toolRegistry = McpToolRegistryProvider.fromClient(
    mcpClient = existingMcpClient,
    serverInfo = McpServerInfo(url = "http://localhost:8931")
)

// From custom transport (stdio, SSE)
val transport = McpToolRegistryProvider.defaultSseTransport("http://localhost:8931/sse")
val toolRegistry = McpToolRegistryProvider.fromTransport(
    transport = transport,
    serverInfo = McpServerInfo(url = "http://localhost:8931")
)

// Use with agent
val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    strategy = singleRunStrategy(),
    toolRegistry = toolRegistry  // MCP tools work like any other tools
)
```
