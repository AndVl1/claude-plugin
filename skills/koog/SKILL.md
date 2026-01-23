---
name: koog
description: JetBrains Koog AI Agent framework - use for building AI agents, LLM integration, tool calling, and AI-powered workflows in Kotlin
---

# Koog AI Agent Framework

Koog is a Kotlin-based framework for building AI agents with multiplatform support, offering an agent execution engine, multi-provider LLM abstraction, tool calling system, and features for observability, persistence, memory, and event handling.

## Project Configuration

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm") version "2.2.21"
    kotlin("plugin.spring") version "2.2.21"
    id("org.springframework.boot") version "3.5.7"
}

repositories {
    mavenCentral()
}

val koogVersion = "0.1.0"

dependencies {
    // Core Koog dependencies
    implementation("ai.koog:koog-agents:$koogVersion")
    implementation("ai.koog:koog-prompt:$koogVersion")

    // LLM Provider clients
    implementation("ai.koog:koog-llm-openai:$koogVersion")
    implementation("ai.koog:koog-llm-anthropic:$koogVersion")
    implementation("ai.koog:koog-llm-google:$koogVersion")

    // Spring Boot integration
    implementation("ai.koog:koog-spring-boot-starter:$koogVersion")

    // Observability (optional)
    implementation("ai.koog:koog-observability-opentelemetry:$koogVersion")

    // Vector storage for RAG (optional)
    implementation("ai.koog:koog-vector-storage:$koogVersion")
    implementation("ai.koog:koog-embeddings:$koogVersion")
}
```

## Core Concepts

### Key Components
- **`AIAgent<I, O>`** - Primary entry point for creating agents
- **`AIAgentGraphStrategy`** - Defines workflow as a directed graph
- **`PromptExecutor`** - Executes prompts against LLMs
- **`LLMClient`** - Provider-specific interface for LLM communication
- **`ToolRegistry`** - Builder for registering tools
- **`Tool<TArgs, TResult>`** - Core abstraction for tool functionality
- **`AIAgentFeature<TConfig>`** - Extends agent capabilities via pipeline interceptors

## Creating a Simple Agent

```kotlin
import ai.koog.agents.core.agent.AIAgent
import ai.koog.prompt.executor.llms.all.simpleOpenAIExecutor
import ai.koog.prompt.executor.clients.openai.OpenAIModels

// Minimal agent creation
val agent = AIAgent(
    promptExecutor = simpleOpenAIExecutor(System.getenv("OPENAI_API_KEY")),
    llmModel = OpenAIModels.Chat.GPT4o
)

suspend fun main() {
    val result = agent.run("Hello! How can you help me?")
    println(result)
}
```

## Prompt Building

```kotlin
import ai.koog.prompt.dsl.prompt

val prompt = prompt {
    system("You are a helpful AI assistant specialized in Kotlin development")
    user("Explain coroutines in simple terms")
}

// With context and examples
val contextualPrompt = prompt {
    system("""
        You are an expert code reviewer.
        Focus on: code quality, performance, security.
    """.trimIndent())

    // Few-shot examples
    assistant("I'll analyze the code for potential issues.")

    user("Review this function: ${codeSnippet}")
}
```

## Tool Definition

### Annotation-Based Tools

```kotlin
import ai.koog.agents.tools.annotations.Tool
import ai.koog.agents.tools.annotations.LLMDescription
import ai.koog.agents.tools.ToolSet

@LLMDescription("Mathematical operations toolkit")
class MathTools : ToolSet {

    @Tool
    @LLMDescription("Adds two numbers together")
    fun add(a: Int, b: Int): Int = a + b

    @Tool
    @LLMDescription("Multiplies two numbers")
    fun multiply(a: Int, b: Int): Int = a * b

    @Tool
    @LLMDescription("Calculates the factorial of a number")
    fun factorial(n: Int): Long {
        require(n >= 0) { "Number must be non-negative" }
        return if (n <= 1) 1 else n * factorial(n - 1)
    }
}
```

### Class-Based Tools

```kotlin
import ai.koog.agents.tools.Tool
import ai.koog.agents.tools.ToolDescriptor
import ai.koog.agents.tools.ToolResult

class WeatherTool : Tool<WeatherTool.Args, WeatherTool.Result> {

    data class Args(val city: String, val units: String = "celsius")
    data class Result(val temperature: Double, val conditions: String)

    override val descriptor = ToolDescriptor(
        name = "get_weather",
        description = "Gets current weather for a city",
        parameters = mapOf(
            "city" to ToolDescriptor.Parameter(
                type = "string",
                description = "City name",
                required = true
            ),
            "units" to ToolDescriptor.Parameter(
                type = "string",
                description = "Temperature units: celsius or fahrenheit",
                required = false
            )
        )
    )

    override suspend fun execute(args: Args): ToolResult<Result> {
        // Call weather API
        val weather = weatherApiClient.getWeather(args.city, args.units)
        return ToolResult.success(Result(weather.temp, weather.conditions))
    }
}
```

### Lambda-Based Tools

```kotlin
import ai.koog.agents.tools.ToolRegistry

val toolRegistry = ToolRegistry {
    // Simple tool with lambda
    simpleTool(
        name = "get_current_time",
        description = "Returns current date and time"
    ) {
        java.time.LocalDateTime.now().toString()
    }

    // Tool with parameters
    simpleTool(
        name = "search_database",
        description = "Searches the database for records"
    ) { params ->
        val query = params["query"] as String
        database.search(query).joinToString("\n")
    }

    // Register tool instances
    tool(WeatherTool())

    // Register all tools from ToolSet
    tools(MathTools())
}
```

## Agent with Tools

```kotlin
import ai.koog.agents.core.agent.AIAgent
import ai.koog.agents.core.strategy.simpleStrategy

val agent = AIAgent(
    promptExecutor = simpleOpenAIExecutor(apiKey),
    llmModel = OpenAIModels.Chat.GPT4o,
    toolRegistry = toolRegistry,
    strategy = simpleStrategy {
        maxIterations = 10
        stopOnToolError = false
    }
)

suspend fun main() {
    val result = agent.run(
        "What's the weather in Tokyo and what's 25 factorial?"
    )
    println(result)
}
```

## LLM Providers

### OpenAI

```kotlin
import ai.koog.prompt.executor.llms.all.simpleOpenAIExecutor
import ai.koog.prompt.executor.clients.openai.OpenAIModels

val executor = simpleOpenAIExecutor(
    token = System.getenv("OPENAI_API_KEY"),
    baseUrl = "https://api.openai.com" // optional
)

// Available models
OpenAIModels.Chat.GPT4o
OpenAIModels.Chat.GPT4oMini
OpenAIModels.Chat.GPT4Turbo
```

### Anthropic

```kotlin
import ai.koog.prompt.executor.llms.all.simpleAnthropicExecutor
import ai.koog.prompt.executor.clients.anthropic.AnthropicModels

val executor = simpleAnthropicExecutor(
    token = System.getenv("ANTHROPIC_API_KEY")
)

// Available models
AnthropicModels.Claude3Opus
AnthropicModels.Claude3Sonnet
AnthropicModels.Claude35Sonnet
```

### Google AI

```kotlin
import ai.koog.prompt.executor.llms.all.simpleGoogleExecutor
import ai.koog.prompt.executor.clients.google.GoogleModels

val executor = simpleGoogleExecutor(
    token = System.getenv("GOOGLE_API_KEY")
)

// Available models
GoogleModels.GeminiPro
GoogleModels.Gemini15Pro
```

### Multi-Provider Orchestration

```kotlin
import ai.koog.prompt.executor.multi.DefaultMultiLLMPromptExecutor
import ai.koog.prompt.executor.multi.ProviderConfig

val multiExecutor = DefaultMultiLLMPromptExecutor(
    providers = listOf(
        ProviderConfig(
            name = "openai",
            executor = simpleOpenAIExecutor(openAiKey),
            priority = 1
        ),
        ProviderConfig(
            name = "anthropic",
            executor = simpleAnthropicExecutor(anthropicKey),
            priority = 2 // fallback
        )
    ),
    fallbackStrategy = FallbackStrategy.PRIORITY_ORDER
)
```

## Spring Boot Integration

### Configuration

```properties
# application.properties

# OpenAI
ai.koog.openai.enabled=true
ai.koog.openai.api-key=${OPENAI_API_KEY}
ai.koog.openai.base-url=https://api.openai.com

# Anthropic
ai.koog.anthropic.enabled=true
ai.koog.anthropic.api-key=${ANTHROPIC_API_KEY}

# Google AI
ai.koog.google.enabled=false
ai.koog.google.api-key=${GOOGLE_API_KEY}
```

### Service Integration

```kotlin
import ai.koog.prompt.executor.SingleLLMPromptExecutor
import ai.koog.prompt.dsl.prompt
import org.springframework.stereotype.Service

@Service
class AIService(
    private val openAIExecutor: SingleLLMPromptExecutor?,
    private val anthropicExecutor: SingleLLMPromptExecutor?
) {

    private val executor: SingleLLMPromptExecutor
        get() = openAIExecutor
            ?: anthropicExecutor
            ?: throw IllegalStateException("No LLM provider configured")

    suspend fun generateResponse(userInput: String): String {
        val prompt = prompt {
            system("You are a helpful AI assistant")
            user(userInput)
        }

        val result = executor.execute(prompt)
        return result.text
    }

    suspend fun analyzeCode(code: String): CodeAnalysis {
        val prompt = prompt {
            system("""
                You are a code analyzer. Analyze the provided code and return:
                - Summary of what the code does
                - Potential issues or bugs
                - Suggestions for improvement

                Respond in JSON format.
            """.trimIndent())
            user(code)
        }

        val result = executor.execute(prompt)
        return json.decodeFromString<CodeAnalysis>(result.text)
    }
}
```

### Controller with AI

```kotlin
import org.springframework.web.bind.annotation.*
import kotlinx.coroutines.runBlocking

@RestController
@RequestMapping("/api/v1/ai")
class AIController(
    private val aiService: AIService
) {

    @PostMapping("/chat")
    fun chat(@RequestBody request: ChatRequest): ChatResponse = runBlocking {
        val response = aiService.generateResponse(request.message)
        ChatResponse(response = response)
    }

    @PostMapping("/analyze")
    fun analyzeCode(@RequestBody request: AnalyzeRequest): CodeAnalysis = runBlocking {
        aiService.analyzeCode(request.code)
    }
}

data class ChatRequest(val message: String)
data class ChatResponse(val response: String)
data class AnalyzeRequest(val code: String)
```

## Streaming Responses

```kotlin
import ai.koog.prompt.executor.StreamingPromptExecutor
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.collect

val streamingExecutor: StreamingPromptExecutor = // configured executor

suspend fun streamResponse(prompt: Prompt): Flow<String> {
    return streamingExecutor.executeStreaming(prompt)
}

// Usage
suspend fun main() {
    val prompt = prompt {
        system("You are a storyteller")
        user("Tell me a story about a brave knight")
    }

    streamResponse(prompt).collect { chunk ->
        print(chunk) // Print each chunk as it arrives
    }
}
```

## Structured Output

```kotlin
import ai.koog.prompt.structured.StructuredOutput
import kotlinx.serialization.Serializable

@Serializable
data class TaskExtraction(
    val tasks: List<Task>,
    val priority: String,
    val deadline: String?
)

@Serializable
data class Task(
    val title: String,
    val description: String,
    val assignee: String?
)

suspend fun extractTasks(text: String): TaskExtraction {
    val prompt = prompt {
        system("Extract tasks from the given text. Return as structured JSON.")
        user(text)
    }

    return executor.executeStructured<TaskExtraction>(prompt)
}
```

## Memory System

```kotlin
import ai.koog.agents.memory.ConversationMemory
import ai.koog.agents.memory.SlidingWindowMemory

// Sliding window memory - keeps last N messages
val memory = SlidingWindowMemory(windowSize = 10)

// Conversation memory with summarization
val conversationMemory = ConversationMemory(
    executor = executor,
    maxMessages = 50,
    summarizeAfter = 30
)

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    memory = conversationMemory
)
```

## Event System

```kotlin
import ai.koog.agents.events.AgentEventListener
import ai.koog.agents.events.AgentEvent

class LoggingEventListener : AgentEventListener {

    override fun onEvent(event: AgentEvent) {
        when (event) {
            is AgentEvent.PromptSent -> {
                logger.info("Prompt sent: ${event.prompt}")
            }
            is AgentEvent.ResponseReceived -> {
                logger.info("Response: ${event.response}")
            }
            is AgentEvent.ToolCalled -> {
                logger.info("Tool called: ${event.toolName} with ${event.args}")
            }
            is AgentEvent.ToolResult -> {
                logger.info("Tool result: ${event.result}")
            }
            is AgentEvent.Error -> {
                logger.error("Error: ${event.error}")
            }
        }
    }
}

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    eventListeners = listOf(LoggingEventListener())
)
```

## Observability with OpenTelemetry

```kotlin
import ai.koog.observability.opentelemetry.OpenTelemetryFeature

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    features = listOf(
        OpenTelemetryFeature(
            serviceName = "my-ai-service",
            exporterEndpoint = "http://localhost:4317"
        )
    )
)
```

## Error Handling

```kotlin
import ai.koog.agents.core.AgentException
import ai.koog.prompt.executor.LLMException

suspend fun safeAgentRun(input: String): Result<String> {
    return try {
        Result.success(agent.run(input))
    } catch (e: LLMException.RateLimitExceeded) {
        // Handle rate limiting
        delay(e.retryAfter ?: 60_000)
        safeAgentRun(input) // Retry
    } catch (e: LLMException.InvalidApiKey) {
        Result.failure(IllegalStateException("Invalid API key configured"))
    } catch (e: AgentException.MaxIterationsExceeded) {
        Result.failure(IllegalStateException("Agent couldn't complete task in time"))
    } catch (e: Exception) {
        Result.failure(e)
    }
}
```

## Testing

```kotlin
import ai.koog.testing.MockLLMBuilder
import ai.koog.testing.MockToolRegistry

class AgentTest {

    @Test
    fun `agent should use weather tool`() = runTest {
        val mockExecutor = MockLLMBuilder()
            .onPromptContaining("weather")
            .respondWith("I'll check the weather for you.")
            .withToolCall("get_weather", mapOf("city" to "Tokyo"))
            .build()

        val mockTools = MockToolRegistry {
            mockTool("get_weather") { args ->
                """{"temperature": 22, "conditions": "sunny"}"""
            }
        }

        val agent = AIAgent(
            promptExecutor = mockExecutor,
            llmModel = TestModels.Mock,
            toolRegistry = mockTools
        )

        val result = agent.run("What's the weather in Tokyo?")

        assertThat(result).contains("22")
        assertThat(result).contains("sunny")
    }
}
```

## Content Moderation Patterns

### Basic Content Moderation Service

```kotlin
import ai.koog.prompt.dsl.prompt
import kotlinx.serialization.Serializable

@Serializable
data class ModerationResult(
    val isAllowed: Boolean,
    val category: String?,        // spam, hate, nsfw, violence, etc.
    val confidence: Double,       // 0.0 - 1.0
    val reason: String?
)

@Service
class ContentModerationService(
    private val executor: SingleLLMPromptExecutor
) {

    suspend fun moderateMessage(text: String): ModerationResult {
        val prompt = prompt {
            system("""
                You are a content moderation assistant. Analyze the message and determine if it should be allowed.

                Categories to check:
                - spam: Promotional content, repetitive messages
                - hate: Hate speech, discrimination
                - nsfw: Adult or explicit content
                - violence: Threats, violent content
                - scam: Phishing, fraud attempts

                Respond in JSON format:
                {
                    "isAllowed": true/false,
                    "category": "category if blocked, null if allowed",
                    "confidence": 0.0-1.0,
                    "reason": "brief explanation"
                }
            """.trimIndent())
            user(text)
        }

        val result = executor.execute(prompt)
        return json.decodeFromString<ModerationResult>(result.text)
    }
}
```

### Integration with Telegram Bot

```kotlin
// handlers/ModerationHandlers.kt
suspend fun BehaviourContext.setupModeration(
    moderationService: ContentModerationService,
    adminIds: List<Long>
) {
    onText { message ->
        val text = message.content.text
        val userId = message.from?.id?.chatId ?: return@onText

        // Skip admin messages
        if (userId in adminIds) return@onText

        val result = moderationService.moderateMessage(text)

        if (!result.isAllowed) {
            // Delete the message
            deleteMessage(message)

            // Notify user (optional)
            send(message.chat.id, buildEntities {
                +"⚠️ " + bold("Message removed") + "\n"
                +"Reason: ${result.reason}"
            })

            // Log for review
            logger.warn(
                "Moderated message",
                "userId" to userId,
                "category" to result.category,
                "confidence" to result.confidence
            )
        }
    }
}
```

### Cached Moderation (Performance Optimization)

```kotlin
@Service
class CachedModerationService(
    private val moderationService: ContentModerationService,
    private val cacheManager: CacheManager
) {
    private val cache = cacheManager.getCache("moderation")

    suspend fun moderate(text: String): ModerationResult {
        val hash = text.hashCode().toString()

        // Check cache first
        cache?.get(hash, ModerationResult::class.java)?.let { return it }

        // Call AI moderation
        val result = moderationService.moderateMessage(text)

        // Cache result (don't cache low confidence)
        if (result.confidence > 0.8) {
            cache?.put(hash, result)
        }

        return result
    }
}
```

### Multi-Step Moderation with Tools

```kotlin
// Advanced moderation with tools for context gathering
class ModerationTools : ToolSet {

    @Tool
    @LLMDescription("Check if user has previous violations")
    suspend fun getUserViolations(userId: Long): String {
        val violations = violationRepository.findByUserId(userId)
        return if (violations.isEmpty()) {
            "No previous violations"
        } else {
            "Previous violations: ${violations.size}. Categories: ${violations.map { it.category }.distinct()}"
        }
    }

    @Tool
    @LLMDescription("Check if message contains known spam patterns")
    fun checkSpamPatterns(text: String): String {
        val patterns = listOf(
            Regex("(?i)free.*money"),
            Regex("(?i)click.*link"),
            Regex("(?i)t\\.me/[a-z]+", RegexOption.IGNORE_CASE)
        )
        val matches = patterns.filter { it.containsMatchIn(text) }
        return if (matches.isEmpty()) "No spam patterns detected"
        else "Spam patterns found: ${matches.size}"
    }
}

val moderationAgent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenAIModels.Chat.GPT4oMini,
    toolRegistry = ToolRegistry { tools(ModerationTools()) },
    strategy = simpleStrategy { maxIterations = 3 }
)
```

### Application-Specific Moderation

```kotlin
// Service for application content moderation
@Service
class AppModerationService(
    private val executor: SingleLLMPromptExecutor,
    private val userService: UserService
) {

    suspend fun moderateWithContext(
        message: CommonMessage<*>,
        chatHistory: List<String> = emptyList()
    ): ModerationResult {
        val user = userService.findByTelegramId(message.from?.id?.chatId ?: 0)
        val isNewUser = user?.let {
            Duration.between(it.createdAt, Instant.now()).toDays() < 7
        } ?: true

        val prompt = prompt {
            system("""
                Content moderation for Telegram bot.

                User context:
                - New user (< 7 days): $isNewUser
                - Previous messages in chat: ${chatHistory.size}

                Be more strict with new users.
                Consider chat context for better accuracy.

                Respond with JSON: { "isAllowed": bool, "category": string|null, "confidence": number, "reason": string }
            """.trimIndent())

            if (chatHistory.isNotEmpty()) {
                assistant("Recent context: ${chatHistory.takeLast(5).joinToString(" | ")}")
            }

            user((message.content as? TextContent)?.text ?: "[non-text content]")
        }

        val result = executor.execute(prompt)
        return json.decodeFromString<ModerationResult>(result.text)
    }
}
```

### User Interaction Enhancement

```kotlin
// AI-powered user interaction
@Service
class UserInteractionService(
    private val executor: SingleLLMPromptExecutor
) {

    suspend fun generateWelcomeMessage(user: User): String {
        val prompt = prompt {
            system("""
                Generate a personalized welcome message for a Telegram bot user.
                Be friendly but professional. Keep it brief (2-3 sentences).
                Language: Russian
            """.trimIndent())
            user("User name: ${user.name}, joined: ${user.createdAt}")
        }

        return executor.execute(prompt).text
    }

    suspend fun suggestReply(context: String, lastMessages: List<String>): String {
        val prompt = prompt {
            system("""
                Suggest a helpful reply for the user's question.
                Context: $context
                Be concise and helpful.
            """.trimIndent())

            lastMessages.forEach { msg ->
                user(msg)
            }
        }

        return executor.execute(prompt).text
    }
}
