# Koog Structured Output Reference

## Table of Contents
- [Overview](#overview)
- [Import Paths](#import-paths)
- [JsonStructuredData](#jsonstructureddata)
- [StructuredOutputConfig](#structuredoutputconfig)
- [StructureFixingParser](#structurefixingparser)
- [structuredOutputWithToolsStrategy](#structuredoutputwithtoolsstrategy)
- [Direct Executor Usage](#direct-executor-usage)
- [Custom LLModel for Fixing](#custom-llmodel-for-fixing)
- [Patterns](#patterns)

---

## Overview

Koog provides native structured output support for parsing LLM responses into typed Kotlin data classes. Key components:

- **JsonStructuredData** — defines the schema (JSON Schema generation from `@Serializable` classes)
- **StructuredOutputConfig** — wraps structured output with optional per-provider overrides
- **StructureFixingParser** — auto-fixes malformed JSON using a secondary LLM model
- **structuredOutputWithToolsStrategy** — agent strategy that returns typed output instead of String
- **nodeLLMRequestStructured** — strategy DSL node for structured output in custom strategies

---

## Import Paths

```
// Structured output core
ai.koog.prompt.structure.StructuredOutput
ai.koog.prompt.structure.StructuredOutputConfig
ai.koog.prompt.structure.StructuredResponse
ai.koog.prompt.structure.StructureFixingParser

// JSON schema
ai.koog.prompt.structure.json.JsonStructuredData

// Strategy DSL nodes
ai.koog.agents.core.dsl.extension.nodeLLMRequestStructured  // node returning Result<StructuredResponse<T>>
ai.koog.agents.core.dsl.extension.requestLLMStructured       // extension on AIAgentFunctionalContext

// Pre-built strategy with structured output
ai.koog.agents.ext.agent.structuredOutputWithToolsStrategy

// LLModel for custom models
ai.koog.prompt.llm.LLModel
ai.koog.prompt.llm.LLMProvider
ai.koog.prompt.llm.LLMCapability
```

---

## JsonStructuredData

Creates a structured data definition from a `@Serializable` Kotlin data class. Generates JSON Schema automatically from the serializer.

### Creating from Serializer (explicit id)

```kotlin
import ai.koog.prompt.structure.json.JsonStructuredData
import kotlinx.serialization.json.Json

val structure = JsonStructuredData.createJsonStructure(
    id = "MyResponse",                          // required: schema identifier
    serializer = MyResponse.serializer(),        // required: kotlinx KSerializer
    json = Json { ignoreUnknownKeys = true },    // optional: custom Json config
    // All below are optional with defaults:
    // schemaGenerator = BasicJsonSchemaGenerator(),
    // descriptionOverrides = mapOf(),
    // excludedProperties = setOf(),
    // examples = listOf(),
    // definitionPrompt = defaultDefinitionPrompt
)
```

### Creating with Reified Type (no explicit id)

```kotlin
// Inline reified version — id is auto-derived from class name
val structure = JsonStructuredData.createJsonStructure<MyResponse>(
    json = Json { ignoreUnknownKeys = true },
    // examples = listOf(MyResponse(...)),    // few-shot examples (optional)
)
```

### Using @LLMDescription for Better Schema

Add `@LLMDescription` annotations to data classes for richer schema generation:

```kotlin
import ai.koog.agents.core.tools.annotations.LLMDescription
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
@SerialName("WeatherReport")
@LLMDescription("Weather report for a given location")
data class WeatherReport(
    @property:LLMDescription("City name")
    val city: String,
    @property:LLMDescription("Temperature in Celsius")
    val temperature: Double,
    @property:LLMDescription("Weather conditions (sunny, cloudy, rainy, etc.)")
    val conditions: String
)
```

---

## StructuredOutputConfig

Wraps a `StructuredOutput` with optional per-provider overrides and a fixing parser.

```kotlin
import ai.koog.prompt.structure.StructuredOutputConfig
import ai.koog.prompt.structure.StructuredOutput
import ai.koog.prompt.llm.LLMProvider

val config = StructuredOutputConfig<MyResponse>(
    default = myStructuredOutput,           // StructuredOutput<MyResponse>
    byProvider = mapOf(                     // optional: per-provider overrides
        LLMProvider.OpenAI to nativeOutput,
        LLMProvider.OpenRouter to basicOutput
    ),
    fixingParser = myFixingParser           // optional: StructureFixingParser
)
```

**Note:** `StructuredOutput` is an interface with a single `structure` property returning `StructuredData`. For JSON, it's backed by `JsonStructuredData`.

---

## StructureFixingParser

Auto-fixes malformed LLM responses using a secondary model. The parser:
1. First tries to parse the response directly via `StructuredData.parse()`
2. If parsing fails (throws `SerializationException`), sends the malformed response + error to the fixing model
3. Retries up to N times

### Constructor

```kotlin
import ai.koog.prompt.structure.StructureFixingParser

val fixingParser = StructureFixingParser(
    fixingModel = myLLModel,    // LLModel used to fix malformed responses
    retries = 3                 // max attempts (default: 3)
    // fixingPrompt = ...       // optional: custom Function4 for fixing prompt
)
```

### Standalone Usage (without agent strategy)

```kotlin
// Use after getting raw text from chatAgentStrategy or similar
val structure = JsonStructuredData.createJsonStructure(
    id = "MyResponse",
    serializer = MyResponse.serializer()
)

val fixingParser = StructureFixingParser(
    fixingModel = glmModel,
    retries = 3
)

// parse() tries direct parse first, then uses fixingModel if needed
val result: MyResponse = fixingParser.parse(executor, structure, rawLlmText)
```

### Custom Fixing Prompt

```kotlin
val fixingParser = StructureFixingParser(
    fixingModel = myModel,
    retries = 3,
    fixingPrompt = { promptBuilder, malformedContent, structure, error ->
        promptBuilder.apply {
            system("Fix this JSON to match the required schema.")
            user("Malformed JSON: $malformedContent")
            user("Parse error: ${error.message}")
        }
    }
)
```

---

## structuredOutputWithToolsStrategy

Agent strategy that combines tool calling with structured output. The agent can use tools to gather information, then returns a typed response.

**IMPORTANT:** This strategy uses a different tool calling format that may not work with all models via OpenRouter. Tested working with OpenAI models. DeepSeek via OpenRouter uses a different format and breaks tool calling.

### Basic Usage

```kotlin
import ai.koog.agents.ext.agent.structuredOutputWithToolsStrategy

val config = StructuredOutputConfig<MyResponse>(
    default = myStructuredOutput,
    fixingParser = fixingParser      // optional
)

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenRouterModels.GPT4o,
    strategy = structuredOutputWithToolsStrategy<MyResponse>(
        config = config,
        includeTools = true          // default: true, enable tool calling
    ),
    toolRegistry = toolRegistry,
    systemPrompt = "...",
    maxIterations = 10
)

// Returns MyResponse directly instead of String
val result: MyResponse = agent.run("user input")
```

### Function Signatures

```kotlin
// Simple overload (String input → typed Output)
fun <Output> structuredOutputWithToolsStrategy(
    config: StructuredOutputConfig<Output>,
    includeTools: Boolean = true
): AIAgentGraphStrategy<String, Output>

// With custom input transformer
fun <Input, Output> structuredOutputWithToolsStrategy(
    config: StructuredOutputConfig<Output>,
    includeTools: Boolean = true,
    buildPrompt: suspend (AIAgentGraphContextBase, Input) -> String
): AIAgentGraphStrategy<Input, Output>
```

---

## Direct Executor Usage

Use structured output without an agent — just prompt + executor:

```kotlin
import ai.koog.prompt.structure.executeStructured

val prompt = prompt("my-prompt") {
    system("Return a JSON weather report")
    user("Weather in Moscow?")
}

// With StructuredOutputConfig
val result: Result<StructuredResponse<WeatherReport>> =
    executor.executeStructured(prompt, model, outputConfig)

// With inline parameters (simpler)
val result: Result<StructuredResponse<WeatherReport>> =
    executor.executeStructured(
        prompt = prompt,
        model = model,
        serializer = WeatherReport.serializer(),
        examples = listOf(WeatherReport("Moscow", -5.0, "snowy")),
        fixingParser = fixingParser     // optional
    )
```

---

## Custom LLModel for Fixing

When predefined models (OpenRouterModels, OpenAIModels, etc.) don't include the model you need, create a custom `LLModel`:

```kotlin
import ai.koog.prompt.llm.LLModel
import ai.koog.prompt.llm.LLMProvider
import ai.koog.prompt.llm.LLMCapability

val customModel = LLModel(
    provider = LLMProvider.OpenRouter,
    id = "z-ai/glm-4.5-air",              // exact model ID from provider
    capabilities = listOf(
        LLMCapability.Completion,           // can generate text
        LLMCapability.Temperature,          // supports temperature param
        LLMCapability.Schema.JSON.Basic     // supports basic JSON schema
    ),
    contextLength = 128_000L,
    maxOutputTokens = 8_000L               // nullable, optional
)
```

### LLMCapability Types (all are singleton objects — no `()`)

| Capability | Description |
|-----------|-------------|
| `LLMCapability.Completion` | Text generation |
| `LLMCapability.Temperature` | Supports temperature parameter |
| `LLMCapability.Tools` | Supports tool/function calling |
| `LLMCapability.ToolChoice` | Supports forcing specific tool |
| `LLMCapability.Schema.JSON.Basic` | Basic JSON schema (response_format) |
| `LLMCapability.Schema.JSON.Standard` | Full JSON schema support |
| `LLMCapability.Vision.Image` | Image input support |
| `LLMCapability.Vision.Video` | Video input support |
| `LLMCapability.Audio` | Audio input support |
| `LLMCapability.Document` | Document input support |
| `LLMCapability.Embed` | Embedding generation |
| `LLMCapability.MultipleChoices` | Multiple response choices |
| `LLMCapability.PromptCaching` | Prompt caching support |
| `LLMCapability.Moderation` | Content moderation |
| `LLMCapability.Speculation` | Speculative decoding |

### LLMProvider Subclasses (all are singleton objects)

| Provider | Usage |
|---------|-------|
| `LLMProvider.OpenRouter` | OpenRouter API |
| `LLMProvider.OpenAI` | OpenAI API |
| `LLMProvider.Anthropic` | Anthropic API |
| `LLMProvider.Google` | Google AI API |
| `LLMProvider.DeepSeek` | DeepSeek API |
| `LLMProvider.Ollama` | Local Ollama |
| `LLMProvider.Bedrock` | AWS Bedrock |
| `LLMProvider.MistralAI` | Mistral AI API |
| `LLMProvider.Alibaba` | Alibaba Cloud |
| `LLMProvider.Meta` | Meta AI |

---

## Patterns

### Pattern 1: chatAgentStrategy + StructureFixingParser (recommended for OpenRouter)

Use `chatAgentStrategy` for tool calling (most compatible), then parse the result with `StructureFixingParser`. This works reliably with all models via OpenRouter.

```kotlin
val agent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenRouterModels.DeepSeekV30324,     // tools work well
    strategy = chatAgentStrategy(),                   // returns String
    toolRegistry = toolRegistry,
    systemPrompt = "... return JSON ...",
    maxIterations = 15
)

val rawResult: String = agent.run("user input")

// Parse with fixing
val structure = JsonStructuredData.createJsonStructure(
    id = "MyResponse",
    serializer = MyResponse.serializer()
)

val fixingParser = StructureFixingParser(
    fixingModel = customGlmModel,    // cheap model for fixing
    retries = 3
)

val typed: MyResponse = fixingParser.parse(executor, structure, rawResult)
```

### Pattern 2: structuredOutputWithToolsStrategy (native, but model-dependent)

Cleaner API but requires models that support the strategy's tool calling format.

```kotlin
val config = StructuredOutputConfig<MyResponse>(
    default = object : StructuredOutput<MyResponse> {
        override val structure = JsonStructuredData.createJsonStructure(
            id = "MyResponse",
            serializer = MyResponse.serializer()
        )
    },
    fixingParser = StructureFixingParser(fixingModel = gpt4oMini, retries = 2)
)

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenRouterModels.GPT4o,
    strategy = structuredOutputWithToolsStrategy(config),
    toolRegistry = toolRegistry,
    systemPrompt = "...",
    maxIterations = 10
)

val typed: MyResponse = agent.run("input")
```

### Pattern 3: nodeLLMRequestStructured in Custom Strategy (recommended)

Use structured output as a node within a custom strategy graph. This is the cleanest approach — tool calling loop followed by typed structured output.

```kotlin
import ai.koog.agents.core.dsl.builder.forwardTo
import ai.koog.agents.core.dsl.builder.strategy
import ai.koog.agents.core.dsl.extension.*

val myStrategy = strategy<String, MyResponse>("structured-agent") {
    val nodeLLM by nodeLLMRequest()
    val nodeExec by nodeExecuteTool()
    val nodeSend by nodeLLMSendToolResult()
    val nodeStructured by nodeLLMRequestStructured<MyResponse>(
        // examples = listOf(MyResponse(...)),    // optional: few-shot examples
        fixingParser = StructureFixingParser(fixingModel = glmModel, retries = 3)
    )

    // Tool calling loop
    edge(nodeStart forwardTo nodeLLM)
    edge(nodeLLM forwardTo nodeExec onToolCall { true })
    edge(nodeExec forwardTo nodeSend)
    edge(nodeSend forwardTo nodeExec onToolCall { true })

    // When LLM stops calling tools → get structured output
    edge(nodeLLM forwardTo nodeStructured onAssistantMessage { true })
    edge(nodeSend forwardTo nodeStructured onAssistantMessage { true })

    // Handle result
    edge(nodeStructured forwardTo nodeFinish onCondition { it.isSuccess }
        transformed { it.getOrThrow().structure })
}

// Use with AIAgent — returns MyResponse directly
val agent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenRouterModels.DeepSeekV30324,
    strategy = myStrategy,
    toolRegistry = toolRegistry,
    systemPrompt = "..."
)
val result: MyResponse = agent.run("input")
```

### Pattern 4: requestLLMStructured in writeSession

Use inside a custom node to call structured output mid-strategy:

```kotlin
val nodeGetData by node<String, MyResponse> { input ->
    val result = llm.writeSession {
        requestLLMStructured<MyResponse>(
            serializer = MyResponse.serializer(),
            examples = emptyList(),
            fixingParser = fixingParser
        )
    }
    result.getOrThrow().structure
}
```

Or via `AIAgentFunctionalContext` extension (available in strategy functional blocks):

```kotlin
// Extension function on AIAgentFunctionalContext
val result = requestLLMStructured<MyResponse>(
    message = "Generate the response",
    examples = listOf(...),
    fixingParser = fixingParser
)
result.getOrThrow().structure
```
