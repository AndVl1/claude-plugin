# Koog EventHandler Feature Reference

Package: `ai.koog.agents.features.eventHandler.feature`

## Installation

Two equivalent syntaxes:

```kotlin
import ai.koog.agents.features.eventHandler.feature.EventHandler
import ai.koog.agents.features.eventHandler.feature.handleEvents

// Option 1: handleEvents shorthand
val agent = AIAgent(...) {
    handleEvents {
        onAgentStarting { ctx -> println("Starting: ${ctx.agent.id}") }
        onAgentCompleted { ctx -> println("Result: ${ctx.result}") }
    }
}

// Option 2: install(EventHandler) — equivalent
val agent = AIAgent(...) {
    install(EventHandler) {
        onAgentStarting { ctx -> println("Starting: ${ctx.agent.id}") }
        onAgentCompleted { ctx -> println("Result: ${ctx.result}") }
    }
}
```

## All Event Callbacks

### Agent Lifecycle

```kotlin
handleEvents {
    onAgentStarting { ctx: AgentStartingContext ->
        // ctx.agent — agent instance
        // ctx.runId — unique run ID
    }

    onAgentCompleted { ctx: AgentCompletedContext ->
        // ctx.result — agent output
    }

    onAgentExecutionFailed { ctx: AgentExecutionFailedContext ->
        // ctx.error — thrown exception
    }

    onAgentClosing { ctx: AgentClosingContext ->
        // cleanup resources
    }
}
```

### Strategy Lifecycle

```kotlin
handleEvents {
    onStrategyStarting { ctx: StrategyStartingContext ->
        // ctx.strategy.name — strategy name
    }

    onStrategyCompleted { ctx: StrategyCompletedContext ->
        // ctx.result — strategy output
    }
}
```

### Node Execution

```kotlin
handleEvents {
    onNodeExecutionStarting { ctx: NodeExecutionStartingContext ->
        // ctx.node.name — node name
        // ctx.input — node input
    }

    onNodeExecutionCompleted { ctx: NodeExecutionCompletedContext ->
        // ctx.node.name, ctx.input, ctx.output
    }

    onNodeExecutionFailed { ctx: NodeExecutionFailedContext ->
        // ctx.node.name, ctx.error
    }
}
```

### LLM Calls

```kotlin
handleEvents {
    onLLMCallStarting { ctx: LLMCallStartingContext ->
        // ctx.prompt — full prompt being sent
        // ctx.tools — list of tools available for this call
    }

    onLLMCallCompleted { ctx: LLMCallCompletedContext ->
        // ctx.responses — list of LLM responses
    }
}
```

### LLM Streaming

```kotlin
import ai.koog.prompt.streaming.StreamFrame

handleEvents {
    onLLMStreamingStarting { ctx -> /* streaming begins */ }

    onLLMStreamingFrameReceived { ctx ->
        // Print streamed text chunks
        (ctx.streamFrame as? StreamFrame.Append)?.let { print(it.text) }
    }

    onLLMStreamingCompleted { ctx -> println("\nDone") }

    onLLMStreamingFailed { ctx ->
        println("Streaming error: ${ctx.error}")
    }
}
```

### Tool Execution

```kotlin
handleEvents {
    onToolCallStarting { ctx: ToolCallStartingContext ->
        // ctx.toolName — tool name
        // ctx.toolArgs — tool arguments (JsonObject)
    }

    onToolCallCompleted { ctx: ToolCallCompletedContext ->
        // ctx.result — tool result
    }

    onToolCallFailed { ctx: ToolCallFailedContext ->
        // ctx.throwable — exception thrown by tool
    }

    onToolValidationFailed { ctx: ToolValidationFailedContext ->
        // ctx.toolName — tool that failed validation
    }
}
```

## Complete Monitoring Example

```kotlin
import ai.koog.agents.core.agent.AIAgent
import ai.koog.agents.features.eventHandler.feature.EventHandler
import ai.koog.agents.features.eventHandler.feature.handleEvents
import ai.koog.prompt.streaming.StreamFrame

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    toolRegistry = toolRegistry,
    systemPrompt = "You are a helpful assistant."
) {
    handleEvents {
        // Agent lifecycle
        onAgentStarting { ctx ->
            println("[AGENT] Starting: ${ctx.agent.id}, run: ${ctx.runId}")
        }
        onAgentCompleted { ctx ->
            println("[AGENT] Completed: ${ctx.result}")
        }
        onAgentExecutionFailed { ctx ->
            println("[AGENT] Failed: ${ctx.error}")
        }

        // LLM calls
        onLLMCallStarting { ctx ->
            println("[LLM] Sending prompt with ${ctx.tools.size} tools")
        }
        onLLMCallCompleted { ctx ->
            println("[LLM] Received ${ctx.responses.size} response(s)")
        }

        // Tool usage
        onToolCallStarting { ctx ->
            println("[TOOL] Calling: ${ctx.toolName}(${ctx.toolArgs})")
        }
        onToolCallCompleted { ctx ->
            println("[TOOL] Result: ${ctx.result}")
        }
        onToolCallFailed { ctx ->
            println("[TOOL] Failed: ${ctx.throwable.message}")
        }

        // Strategy
        onStrategyStarting { ctx ->
            println("[STRATEGY] Started: ${ctx.strategy.name}")
        }
        onStrategyCompleted { ctx ->
            println("[STRATEGY] Finished: ${ctx.result}")
        }

        // Nodes
        onNodeExecutionStarting { ctx ->
            println("[NODE] ${ctx.node.name} <- ${ctx.input}")
        }
        onNodeExecutionCompleted { ctx ->
            println("[NODE] ${ctx.node.name} -> ${ctx.output}")
        }
    }
}
```

## Custom Feature (Low-Level Interceptors)

For full control, create a custom `AIAgentFeature` with pipeline interceptors:

```kotlin
import ai.koog.agents.core.feature.AIAgentFeature
import ai.koog.agents.core.feature.AIAgentPipeline
import ai.koog.agents.core.feature.AIAgentStorageKey
import ai.koog.agents.core.feature.InterceptContext

class LoggingFeature(val logger: Logger) {
    class Config {
        var loggerName: String = "agent-logs"
    }

    companion object Feature : AIAgentFeature<Config, LoggingFeature> {
        override val key = createStorageKey<LoggingFeature>("logging-feature")
        override fun createInitialConfig() = Config()

        override fun install(config: Config, pipeline: AIAgentPipeline) {
            val feature = LoggingFeature(LoggerFactory.getLogger(config.loggerName))
            val ctx = InterceptContext(this, feature)

            pipeline.interceptAgentStarting(ctx) { event ->
                event.feature.logger.info("Agent starting: runId=${event.runId}")
            }
            pipeline.interceptLLMCallStarting(ctx) { event ->
                event.feature.logger.info("LLM call with ${event.tools.size} tools")
            }
            pipeline.interceptLLMCallCompleted(ctx) { event ->
                event.feature.logger.info("${event.responses.size} response(s)")
            }
            pipeline.interceptToolCallStarting(ctx) { event ->
                event.feature.logger.info("Tool: ${event.toolName}(${event.toolArgs})")
            }
            pipeline.interceptNodeExecutionStarting(ctx) { event ->
                event.feature.logger.info("Node ${event.node.name} <- ${event.input}")
            }
            pipeline.interceptNodeExecutionCompleted(ctx) { event ->
                event.feature.logger.info("Node ${event.node.name} -> ${event.output}")
            }
        }
    }
}

// Usage:
val agent = AIAgent(...) {
    install(LoggingFeature) {
        loggerName = "my-agent"
    }
}
```

### Available Pipeline Interceptors

| Interceptor | Event |
|------------|-------|
| `interceptAgentStarting` | Agent run begins |
| `interceptAgentCompleted` | Agent run finished |
| `interceptAgentExecutionFailed` | Agent threw exception |
| `interceptAgentClosing` | Agent shutting down |
| `interceptStrategyStarting` | Strategy graph execution begins |
| `interceptStrategyCompleted` | Strategy graph finished |
| `interceptNodeExecutionStarting` | Node receives input |
| `interceptNodeExecutionCompleted` | Node produced output |
| `interceptNodeExecutionFailed` | Node threw exception |
| `interceptLLMCallStarting` | LLM request about to be sent |
| `interceptLLMCallCompleted` | LLM response received |
| `interceptToolCallStarting` | Tool about to execute |
| `interceptToolCallCompleted` | Tool produced result |
| `interceptToolCallFailed` | Tool threw exception |
| `interceptToolValidationFailed` | Tool args validation failed |
| `interceptLLMStreamingStarting` | Streaming begins |
| `interceptLLMStreamingFrameReceived` | Stream chunk received |
| `interceptLLMStreamingCompleted` | Streaming finished |
| `interceptLLMStreamingFailed` | Streaming error |
