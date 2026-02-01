# Koog LLM Providers Reference

## Table of Contents
- [OpenRouter](#openrouter)
- [OpenAI](#openai)
- [Anthropic](#anthropic)
- [Google](#google)
- [DeepSeek](#deepseek)
- [Ollama](#ollama)

---

## OpenRouter

Package: `ai.koog.prompt.executor.clients.openrouter`

```kotlin
import ai.koog.prompt.executor.clients.openrouter.OpenRouterLLMClient
import ai.koog.prompt.executor.clients.openrouter.OpenRouterModels
import ai.koog.prompt.executor.clients.openrouter.OpenRouterParams
import ai.koog.prompt.executor.llms.SingleLLMPromptExecutor

val client = OpenRouterLLMClient(apiKey = System.getenv("OPENROUTER_API_KEY"))
val executor = SingleLLMPromptExecutor(client)
```

### Available Models (OpenRouterModels)

| Kotlin property | OpenRouter model ID |
|----------------|---------------------|
| `DeepSeekV30324` | `deepseek/deepseek-chat-v3-0324` |
| `GPT4o` | `openai/gpt-4o` |
| `GPT4oMini` | `openai/gpt-4o-mini` |
| `GPT4` | `openai/gpt-4` |
| `GPT4Turbo` | `openai/gpt-4-turbo` |
| `GPT35Turbo` | `openai/gpt-3.5-turbo` |
| `GPT5` | `openai/gpt-5` |
| `GPT5Mini` | `openai/gpt-5-mini` |
| `GPT5Chat` | `openai/gpt-5-chat` |
| `Claude3Opus` | `anthropic/claude-3-opus` |
| `Claude3Sonnet` | `anthropic/claude-3-sonnet` |
| `Claude3Haiku` | `anthropic/claude-3-haiku` |
| `Claude3_5Sonnet` | `anthropic/claude-3.5-sonnet` |
| `Claude3_7Sonnet` | `anthropic/claude-3.7-sonnet` |
| `Claude4Sonnet` | `anthropic/claude-4-sonnet` |
| `Claude4_1Opus` | `anthropic/claude-4.1-opus` |
| `Gemini2_5Pro` | `google/gemini-2.5-pro` |
| `Gemini2_5Flash` | `google/gemini-2.5-flash` |
| `Gemini2_5FlashLite` | `google/gemini-2.5-flash-lite` |
| `Llama3` | `meta-llama/llama-3` |
| `Llama3Instruct` | `meta-llama/llama-3-instruct` |
| `Mistral7B` | `mistralai/mistral-7b` |
| `Mixtral8x7B` | `mistralai/mixtral-8x7b` |
| `Qwen2_5` | `qwen/qwen-2.5` |
| `Phi4Reasoning` | `microsoft/phi-4-reasoning` |

### OpenRouterParams (advanced)

```kotlin
val params = OpenRouterParams(
    temperature = 0.7,
    maxTokens = 4000,
    topP = 0.9,
    topK = 40,
    frequencyPenalty = 0.5,
    presencePenalty = 0.5,
    repetitionPenalty = 1.1,
    stop = listOf("\n\n"),
    // Model routing / fallbacks
    models = listOf("deepseek/deepseek-chat-v3-0324", "openai/gpt-4o"),
    route = "fallback",
    provider = ProviderPreferences(order = listOf("DeepSeek", "OpenAI"))
)
```

---

## OpenAI

Package: `ai.koog.prompt.executor.clients.openai`

```kotlin
import ai.koog.prompt.executor.llms.all.simpleOpenAIExecutor
import ai.koog.prompt.executor.clients.openai.OpenAIModels

// Simple helper function
val executor = simpleOpenAIExecutor(
    token = System.getenv("OPENAI_API_KEY"),
    baseUrl = "https://api.openai.com"  // optional, for custom endpoints
)

// Models: OpenAIModels.Chat.GPT4o, GPT4oMini, GPT4Turbo, GPT4_1, etc.
```

---

## Anthropic

Package: `ai.koog.prompt.executor.clients.anthropic`

```kotlin
import ai.koog.prompt.executor.llms.all.simpleAnthropicExecutor
import ai.koog.prompt.executor.clients.anthropic.AnthropicModels

val executor = simpleAnthropicExecutor(token = System.getenv("ANTHROPIC_API_KEY"))
// Models: AnthropicModels.Claude3Opus, Claude3Sonnet, Claude35Sonnet, etc.
```

---

## Google

Package: `ai.koog.prompt.executor.clients.google`

```kotlin
import ai.koog.prompt.executor.llms.all.simpleGoogleExecutor
import ai.koog.prompt.executor.clients.google.GoogleModels

val executor = simpleGoogleExecutor(token = System.getenv("GOOGLE_API_KEY"))
// Models: GoogleModels.GeminiPro, Gemini15Pro, etc.
```

---

## DeepSeek

Package: `ai.koog.prompt.executor.clients.deepseek`

```kotlin
import ai.koog.prompt.executor.clients.deepseek.DeepSeekLLMClient
import ai.koog.prompt.executor.clients.deepseek.DeepSeekParams
import ai.koog.prompt.executor.llms.SingleLLMPromptExecutor

val client = DeepSeekLLMClient(apiKey = System.getenv("DEEPSEEK_API_KEY"))
val executor = SingleLLMPromptExecutor(client)

// DeepSeek-specific params
val params = DeepSeekParams(
    temperature = 0.7,
    maxTokens = 4000,
    includeThoughts = true,     // enable reasoning
    thinkingBudget = 2000
)
```

---

## Ollama

Package: `ai.koog.prompt.executor.clients.ollama`

```kotlin
import ai.koog.prompt.executor.clients.ollama.OllamaLLMClient
import ai.koog.prompt.executor.llms.SingleLLMPromptExecutor

val client = OllamaLLMClient(baseUrl = "http://localhost:11434")
val executor = SingleLLMPromptExecutor(client)
```

---

## Common Pattern: Any Provider with Agent

```kotlin
// 1. Create client (any provider)
val client = OpenRouterLLMClient(apiKey = "...")
// or: OpenAILLMClient(...), AnthropicLLMClient(...), etc.

// 2. Wrap in executor
val executor = SingleLLMPromptExecutor(client)

// 3. Create agent
val agent = AIAgent(
    promptExecutor = executor,
    llmModel = OpenRouterModels.DeepSeekV30324,  // or any LLModel
    strategy = chatAgentStrategy(),
    toolRegistry = ToolRegistry { tools(myToolSet) },
    systemPrompt = "...",
    maxIterations = 10
)

// 4. Run (suspend function)
val result = agent.run("user input")
```
