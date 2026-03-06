---
name: openrouter-integration
description: OpenRouter API integration for LLM experiments - use for calling various LLM models via OpenRouter, managing API keys, and using different models for different tasks
---

# OpenRouter Integration

## Overview

OpenRouter provides a unified API for accessing multiple LLM models. This skill helps you:
- Call LLMs via OpenRouter API
- Manage API keys securely
- Use different models for different tasks
- Handle responses and errors properly
- Implement prompts and patterns

## Configuration

### API Key

Store your API key securely:
```bash
# Create config directory
mkdir -p ~/.config/openrouter

# Store API key (make it readable only by you)
echo "sk-or-v1-..." > ~/.config/openrouter/api_key
chmod 600 ~/.config/openrouter/api_key
```

### Environment Variable

Alternatively, set as environment variable:
```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
```

## Basic Usage

### Fetch API Key
```kotlin
fun getApiKey(): String {
    return System.getenv("OPENROUTER_API_KEY")
        ?: File("~/.config/openrouter/api_key").readText().trim()
}
```

### Make a Request
```kotlin
import kotlinx.coroutines.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*

suspend fun callOpenRouter(
    model: String = "anthropic/claude-3-sonnet",
    messages: List<ChatMessage>,
    temperature: Double = 0.7,
    maxTokens: Int = 4096
): String = withContext(Dispatchers.IO) {
    val apiKey = getApiKey()
    val client = HttpClient()

    val response = client.post("https://openrouter.ai/api/v1/chat/completions") {
        header("Authorization", "Bearer $apiKey")
        header("Content-Type", "application/json")

        setBody(
            Json.encodeToString(object {
                val model = model
                val messages = messages
                val temperature = temperature
                val max_tokens = maxTokens
                val stream = false
            })
        )
    }

    val result = Json.decodeFromString<ChatCompletionResponse>(response.bodyAsText())
    result.choices.firstOrNull()?.message?.content ?: ""
}
```

## Models

### Available Models (via OpenRouter)

**Claude Series:**
- `anthropic/claude-3-opus`: Most capable, expensive
- `anthropic/claude-3-sonnet`: Balanced performance/cost
- `anthropic/claude-3-haiku`: Fast and cost-effective

**GPT Series:**
- `openai/gpt-4`: Most capable
- `openai/gpt-4-turbo`: Faster GPT-4
- `openai/gpt-3.5-turbo`: Fast and cheap

**Other Models:**
- `google/gemini-pro`: Google's offering
- `meta-llama/llama-2-70b`: Llama 2, local-friendly
- `mistralai/mistral-7b`: Mistral 7B

## Chat Message Format

```kotlin
@Serializable
data class ChatMessage(
    val role: String, // "system", "user", "assistant"
    val content: String
)

@Serializable
data class ChatCompletionRequest(
    val model: String,
    val messages: List<ChatMessage>,
    val temperature: Double = 0.7,
    val max_tokens: Int = 4096,
    val stream: Boolean = false
)
```

## Examples

### Example 1: Simple Chat
```kotlin
suspend fun simpleChat(): String {
    val messages = listOf(
        ChatMessage("system", "You are a helpful assistant."),
        ChatMessage("user", "Hello, how are you?")
    )

    return callOpenRouter(
        model = "anthropic/claude-3-sonnet",
        messages = messages
    )
}
```

### Example 2: System Prompt Pattern
```kotlin
suspend fun codeReview(): String {
    val messages = listOf(
        ChatMessage(
            "system",
            """You are an expert code reviewer. Analyze the code and provide:
               1. Strengths
               2. Weaknesses
               3. Suggestions
               4. Potential bugs

               Keep your response concise and actionable."""
        ),
        ChatMessage("user", """Review this code:

```kotlin
fun calculateSum(numbers: List<Int>): Int {
    return numbers.sum()
}
```""")
    )

    return callOpenRouter(
        model = "anthropic/claude-3-sonnet",
        messages = messages,
        temperature = 0.3
    )
}
```

### Example 3: Few-Shot Prompting
```kotlin
suspend fun classificationTask(): String {
    val messages = listOf(
        ChatMessage(
            "system",
            """Classify the following code into one of: SECURITY, BUG, PERFORMANCE, MAINTAINABILITY, FEATURE

Examples:
Input: "SQL injection vulnerability detected"
Output: SECURITY

Input: "Missing null check"
Output: BUG

Input: "This loop can be optimized"
Output: PERFORMANCE

Input: "Refactoring function for readability"
Output: MAINTAINABILITY

Input: "Add feature X"
Output: FEATURE"""
        ),
        ChatMessage("user", "parseInt() without try-catch can throw exception")
    )

    return callOpenRouter(
        model = "anthropic/claude-3-haiku",
        messages = messages,
        temperature = 0.0
    )
}
```

### Example 4: Chain of Thought
```kotlin
suspend fun reasoningTask(): String {
    val messages = listOf(
        ChatMessage(
            "system",
            """Think step by step. Show your reasoning before giving the final answer."""
        ),
        ChatMessage("user", """How many total minutes in 3 hours and 45 minutes?""")
    )

    return callOpenRouter(
        model = "anthropic/claude-3-opus",
        messages = messages,
        temperature = 0.7
    )
}
```

### Example 5: Role-Based Agent
```kotlin
suspend fun createDeveloperAgent(): String {
    val messages = listOf(
        ChatMessage(
            "system",
            """You are an expert backend developer. You use Kotlin and Spring Boot. You prefer:
               - Clean code principles
               - SOLID principles
               - Test-driven development
               - RESTful APIs

               When reviewing code, provide:
               1. Code quality score
               2. Specific improvement suggestions
               3. Code examples"""
        ),
        ChatMessage("user", """Review this controller:"""),
        ChatMessage("assistant", """Here's the controller:

```kotlin
@RestController
@RequestMapping("/api/users")
class UserController(
    private val userService: UserService
) {
    @GetMapping
    fun getAllUsers(): List<User> {
        return userService.findAll()
    }
}
```

I notice:
1. Good structure
2. Dependency injection is correct
3. Missing pagination
4. No error handling
5. No documentation

Suggestions:
1. Add pagination: `Pageable`
2. Add try-catch
3. Add @Operation documentation
4. Consider validation using Spring Validation"""
        ),
        ChatMessage("user", """Here's an improved version:""")
    )

    return callOpenRouter(
        model = "anthropic/claude-3-sonnet",
        messages = messages
    )
}
```

## Error Handling

```kotlin
suspend fun callOpenRouterWithErrorHandling(
    model: String,
    messages: List<ChatMessage>,
    maxRetries: Int = 3
): String {
    repeat(maxRetries) { attempt ->
        try {
            return callOpenRouter(model, messages)
        } catch (e: Exception) {
            when (e) {
                is OpenRouterAuthenticationException -> {
                    throw Exception("Invalid API key. Check ~/.config/openrouter/api_key")
                }
                is OpenRouterRateLimitException -> {
                    val delay = (attempt + 1) * 30_000 // 30s, 60s, 90s
                    delay(delay)
                }
                is OpenRouterServiceUnavailableException -> {
                    delay((attempt + 1) * 10_000) // 10s backoff
                }
                else -> throw Exception("Failed after $maxRetries attempts: ${e.message}")
            }
        }
    }
    throw Exception("Failed after $maxRetries attempts")
}
```

## Response Handling

### Get Full Response
```kotlin
@Serializable
data class ChatCompletionResponse(
    val id: String,
    val model: String,
    val choices: List<Choice>,
    val usage: Usage
)

@Serializable
data class Choice(
    val index: Int,
    val message: Message,
    val finish_reason: String
)

@Serializable
data class Message(
    val role: String,
    val content: String
)

@Serializable
data class Usage(
    val prompt_tokens: Int,
    val completion_tokens: Int,
    val total_tokens: Int
)
```

### Parse Response
```kotlin
suspend fun callOpenRouterWithMetadata(): String {
    val apiKey = getApiKey()
    val client = HttpClient()

    val response = client.post("https://openrouter.ai/api/v1/chat/completions") {
        header("Authorization", "Bearer $apiKey")
        header("Content-Type", "application/json")

        setBody(Json.encodeToString(object {
            val model = "anthropic/claude-3-sonnet"
            val messages = listOf(
                ChatMessage("user", "Tell me a joke")
            )
            val temperature = 0.8
        }))
    }

    val result = Json.decodeFromString<ChatCompletionResponse>(response.bodyAsText())

    println("Model: ${result.model}")
    println("Prompt tokens: ${result.usage.prompt_tokens}")
    println("Completion tokens: ${result.usage.completion_tokens}")
    println("Total tokens: ${result.usage.total_tokens}")
    println("Response: ${result.choices.firstOrNull()?.message?.content}")

    return result.choices.firstOrNull()?.message?.content ?: ""
}
```

## Streaming Response

```kotlin
suspend fun callOpenRouterStreaming(): String {
    val apiKey = getApiKey()
    val client = HttpClient()

    val response = client.post("https://openrouter.ai/api/v1/chat/completions") {
        header("Authorization", "Bearer $apiKey")
        header("Content-Type", "application/json")

        setBody(Json.encodeToString(object {
            val model = "anthropic/claude-3-sonnet"
            val messages = listOf(ChatMessage("user", "Write a story"))
            val stream = true
        }))
    }

    // Process streaming response
    val result = StringBuilder()
    response.bodyAsChannel().consumeEach { chunk ->
        val lines = chunk.decodeToString().split("\n")
        lines.forEach { line ->
            if (line.startsWith("data: ")) {
                val data = line.substring(6)
                if (data != "[DONE]") {
                    val json = Json.decodeFromString<Chunk>(data)
                    result.append(json.choices.firstOrNull()?.delta?.content)
                }
            }
        }
    }

    return result.toString()
}

@Serializable
data class Chunk(
    val id: String,
    val choices: List<ChoiceChunk>
)

@Serializable
data class ChoiceChunk(
    val delta: Delta
)

@Serializable
data class Delta(
    val content: String?
)
```

## Best Practices

### ✅ DO
- Store API key securely
- Handle errors properly
- Use appropriate temperature
- Set max_tokens appropriately
- Cache responses when possible
- Monitor token usage
- Use specific models for specific tasks
- Implement retry logic

### ❌ DON'T
- Don't hardcode API key
- Don't call without error handling
- Don't use high temperature for factual tasks
- Don't request too many tokens
- Don't ignore rate limits
- Don't share API key

## Use Cases

### 1. Code Generation
Use GPT-4 or Claude Opus for complex code generation

### 2. Code Review
Use Claude Sonnet for code review

### 3. Translation
Use cheaper models for translation

### 4. Analysis
Use appropriate models based on complexity

### 5. Prototyping
Use Haiku for quick iterations

## Cost Optimization

### Strategy 1: Model Selection
- Complex tasks: Claude Opus
- Standard tasks: Claude Sonnet
- Simple tasks: Claude Haiku

### Strategy 2: Token Management
- Summarize long responses
- Extract only needed information
- Cache repeated queries

### Strategy 3: Prompt Optimization
- Be specific in prompts
- Minimize unnecessary context
- Use streaming for long responses

## Testing

```kotlin
suspend fun testOpenRouter() {
    val result = callOpenRouter(
        model = "anthropic/claude-3-sonnet",
        messages = listOf(ChatMessage("user", "Say hello"))
    )

    assert(result.contains("hello"))
    println("✓ Test passed")
}
```

## Resources

- OpenRouter API: https://openrouter.ai/docs
- Model pricing: https://openrouter.ai/models
- Python SDK: https://github.com/anthropics/anthropic-sdk-python
