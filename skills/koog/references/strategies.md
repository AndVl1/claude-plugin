# Koog Custom Strategies Reference

## Table of Contents
- [Strategy Builder](#strategy-builder)
- [Node Types](#node-types)
- [Edge Conditions](#edge-conditions)
- [Subgraphs](#subgraphs)
- [Parallel Execution](#parallel-execution)
- [Advanced Patterns](#advanced-patterns)

---

## Strategy Builder

```kotlin
import ai.koog.agents.core.dsl.builder.forwardTo
import ai.koog.agents.core.dsl.builder.strategy
import ai.koog.agents.core.dsl.extension.*

val myStrategy = strategy<String, String>("my-strategy") {
    // nodeStart and nodeFinish are built-in
    val nodeLLM by nodeLLMRequest()
    val nodeExecTool by nodeExecuteTool()
    val nodeSendResult by nodeLLMSendToolResult()

    edge(nodeStart forwardTo nodeLLM)
    edge(nodeLLM forwardTo nodeFinish onAssistantMessage { true })
    edge(nodeLLM forwardTo nodeExecTool onToolCall { true })
    edge(nodeExecTool forwardTo nodeSendResult)
    edge(nodeSendResult forwardTo nodeFinish onAssistantMessage { true })
    edge(nodeSendResult forwardTo nodeExecTool onToolCall { true })
}
```

The `strategy()` function returns `AIAgentGraphStrategy<Input, Output>`.

Built-in nodes available in every strategy:
- `nodeStart` — entry point, receives `Input`
- `nodeFinish` — exit point, produces `Output`

---

## Node Types

### LLM Request Nodes

```kotlin
// Standard LLM request (appends user message to prompt, gets response)
val node by nodeLLMRequest(name = "sendInput", allowToolCalls = true)

// Force a specific tool call
val node by nodeLLMSendMessageForceOneTool(name = "forceTool", tool = myTool)

// Only allow tool calls (no text responses)
val node by nodeLLMSendMessageOnlyCallingTools(name = "toolsOnly")

// Request multiple choices (uses numberOfChoices from config)
val node by nodeLLMRequestMultiple(name = "multiChoice")
```

### Structured Output Node

```kotlin
val node by nodeLLMRequestStructured<MyDataClass>(
    name = "structured",
    examples = listOf(MyDataClass(...)),        // few-shot examples
    fixingParser = StructureFixingParser(        // auto-fix malformed JSON
        fixingModel = OpenAIModels.Chat.GPT4oMini,
        retries = 2
    )
)
// Returns Result<StructuredResponse<MyDataClass>>
```

### Tool Execution Nodes

```kotlin
// Execute single tool call
val nodeExec by nodeExecuteTool(name = "execTool")
// Input: Message.Tool.Call → Output: ReceivedToolResult

// Send tool result back to LLM
val nodeSend by nodeLLMSendToolResult(name = "sendResult")
// Input: ReceivedToolResult → Output: Message.Response

// Execute multiple tools in parallel
val nodeMulti by nodeExecuteMultipleTools(name = "execMulti", parallel = true)
// Input: List<Message.Tool.Call> → Output: List<ReceivedToolResult>

// Execute multiple + send results
val nodeMultiSend by nodeExecuteMultipleToolsAndSendResults(name = "execAndSend", parallel = true)
```

### Custom Nodes

```kotlin
// Custom processing node
val nodeProcess by node<String, Int> { input ->
    // `this` is AIAgentNodeContext with access to:
    // - llm (LLM context, history, prompt)
    // - agentInput (original agent input)
    // - environment, config, storage, etc.
    input.length
}
```

### Prompt Manipulation Nodes

```kotlin
// Append to prompt
val nodeAppend by nodeAppendPrompt<String>(name = "appendCtx") {
    system("Additional context: ...")
}

// Rewrite prompt entirely
val nodeRewrite by nodeUpdatePrompt<String>(name = "rewrite") {
    prompt("new-prompt") {
        system("New system prompt")
        user("New user message")
    }
}

// Or rewrite inside a custom node:
val nodeCustomRewrite by node<String, Unit> { input ->
    llm.writeSession {
        rewritePrompt {
            prompt("research_prompt") {
                system("You are given research results. Make a plan.")
                user("Research: $input")
            }
        }
    }
}
```

### History Compression Node

```kotlin
val nodeCompress by nodeLLMCompressHistory<String>(
    name = "compress",
    strategy = HistoryCompressionStrategy.Summarize,
    model = OpenAIModels.Chat.GPT4oMini,
    verbose = false
)
```

### Utility Nodes

```kotlin
// Pass-through (no-op)
val nodeNoop by nodeDoNothing<String>(name = "noop")
```

---

## Edge Conditions

### Basic Edges

```kotlin
edge(nodeA forwardTo nodeB)                    // unconditional
edge(nodeA forwardTo nodeB onCondition { true }) // with condition
```

### Message Type Conditions

```kotlin
// On assistant text response
edge(nodeLLM forwardTo nodeFinish onAssistantMessage { true })

// On any tool call
edge(nodeLLM forwardTo nodeExec onToolCall { true })

// On specific tool called
edge(nodeLLM forwardTo nodeExec onToolCall(myTool) { true })
edge(nodeLLM forwardTo nodeExec onToolCall(myTool))  // shorthand

// On tool NOT called
edge(nodeLLM forwardTo nodeExec onToolNotCalled(myTool))

// On multiple tool calls
edge(nodeLLM forwardTo nodeMultiExec onMultipleToolCalls { true })
```

### Custom Conditions

```kotlin
edge(nodeA forwardTo nodeB onCondition { output ->
    output.contains("approved")
})

// On structured output success/failure
edge(nodeStructured forwardTo nodeFinish onCondition { it.isSuccess })
edge(nodeStructured forwardTo nodeFallback onCondition { it.isFailure })
```

### Transformed Edges

Transform output before passing to next node:

```kotlin
// Simple transform
edge(nodeA forwardTo nodeB transformed { output ->
    "Processed: $output"
})

// Combined condition + transform
edge(
    nodeStructured forwardTo nodeFinish
        onCondition { it.isSuccess }
        transformed { it.getOrThrow().data }
)

// Transform with context access
edge(
    nodeUpdatePrompt forwardTo nodeLLM
        transformed { "Task: $agentInput" }
)
```

---

## Subgraphs

Subgraphs are isolated strategy sections with their own tool set and optional model override.

### Basic Subgraph

```kotlin
val strategy = strategy<String, String>("main") {
    val research by subgraph<String, String>(
        name = "research",
        tools = listOf(WebSearchTool())
    ) {
        val callLLM by nodeLLMRequest()
        val execTool by nodeExecuteTool()
        val sendResult by nodeLLMSendToolResult()

        edge(nodeStart forwardTo callLLM)
        edge(callLLM forwardTo execTool onToolCall { true })
        edge(execTool forwardTo sendResult)
        edge(sendResult forwardTo execTool onToolCall { true })
        edge(callLLM forwardTo nodeFinish onAssistantMessage { true })
        edge(sendResult forwardTo nodeFinish onAssistantMessage { true })
    }

    edge(nodeStart forwardTo research)
    edge(research forwardTo nodeFinish)
}
```

### Subgraph With Task Description

```kotlin
import ai.koog.agents.ext.agent.subgraphWithTask

val transfer by subgraphWithTask<ClassifiedRequest, String>(
    tools = MoneyTransferTools().asTools() + AskUser,
    llmModel = OpenAIModels.Chat.GPT4o  // override model for this subgraph
) { request ->
    """
    You are a banking assistant.
    Handle this request: ${request.userRequest}
    """.trimIndent()
}
```

### Sequential Subgraphs (then)

```kotlin
// Chain subgraphs sequentially
nodeStart then researchSubgraph then planSubgraph then executeSubgraph then nodeFinish
```

### Subgraph With Verification (LLM-as-Judge)

```kotlin
import ai.koog.agents.ext.agent.subgraphWithVerification

val verified by subgraphWithVerification<String>(
    tools = listOf(myTool),
    taskDescription = { ctx, input -> "Solve: $input" }
)
// Returns CriticResult<String> with approve/reject
```

### Subgraph With Retry

```kotlin
import ai.koog.agents.ext.agent.subgraphWithRetry

val retryable by subgraphWithRetry<String, String>(
    maxRetries = 3,
    beforeAction = { ctx, input -> /* setup */ },
    action = { ctx, input -> /* do work */ "result" },
    decide = { ctx, output ->
        if (output.contains("error")) RetrySubgraphResult.Failure
        else RetrySubgraphResult.Success
    },
    cleanup = { ctx -> /* cleanup on retry */ }
)
```

---

## Parallel Execution

Run multiple nodes concurrently and merge results:

```kotlin
val strategy = strategy<String, String>("parallel-demo") {
    val nodeCalcTokens by node<String, Int> { input -> countTokens(input) }
    val nodeCalcWords by node<String, Int> { input -> input.split(" ").size }
    val nodeCalcChars by node<String, Int> { input -> input.length }

    val bestResult by parallel<String, Int>(
        nodeCalcTokens, nodeCalcWords, nodeCalcChars
    ) {
        // Merge strategy — pick the max value
        selectByMax { it }
    }

    edge(nodeStart forwardTo bestResult)
    edge(bestResult forwardTo nodeFinish transformed { "Best: $it" })
}
```

Merge strategies:
- `selectByMax { selector }` — pick result with max value
- `selectBy { predicate }` — pick first matching result
- `selectByIndex { indexFn }` — pick by computed index
- `fold(initial) { acc, output -> R }` — reduce all results

---

## Advanced Patterns

### Conditional Routing Between Subgraphs

```kotlin
val strategy = strategy<String, String>("router") {
    val classify by subgraph<String, ClassifiedRequest>(...) { /* ... */ }
    val handleTypeA by subgraphWithTask<ClassifiedRequest, String>(...) { /* ... */ }
    val handleTypeB by subgraphWithTask<ClassifiedRequest, String>(...) { /* ... */ }

    edge(nodeStart forwardTo classify)
    edge(classify forwardTo handleTypeA onCondition { it.type == "A" })
    edge(classify forwardTo handleTypeB onCondition { it.type == "B" })
    edge(handleTypeA forwardTo nodeFinish)
    edge(handleTypeB forwardTo nodeFinish)
}
```

### Looping with Custom Trim

```kotlin
// Custom node to trim history (prevent context overflow)
val nodeTrimHistory by node<ReceivedToolResult, ReceivedToolResult> { result ->
    llm.writeSession {
        // Remove old messages, keep only recent
        trimHistory(keepLast = 10)
    }
    result
}

edge(nodeExecTool forwardTo nodeTrimHistory)
edge(nodeTrimHistory forwardTo nodeSendResult)
```

### LLM as a Judge

```kotlin
import ai.koog.agents.ext.agent.llmAsAJudge

val judge = llmAsAJudge<String>(
    judgePrompt = "Evaluate if this response is helpful and accurate.",
    model = OpenAIModels.Chat.GPT4o
)
// Returns: suspend (context, input) -> ConditionResult (Approve/Reject)
```

### Tool Selection Strategy

```kotlin
// In subgraph definition
val sg by subgraph<String, String>(
    toolSelectionStrategy = ToolSelectionStrategy.Auto,  // LLM decides
    // or: ToolSelectionStrategy.Required  — force tool call
    // or: ToolSelectionStrategy.None      — no tools
    // or: ToolSelectionStrategy.Parallel  — allow parallel tool calls
    tools = listOf(...)
) { /* ... */ }
```
