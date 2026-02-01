# Koog Built-in Tools Reference

## Table of Contents
- [User Interaction Tools](#user-interaction-tools)
- [File Tools](#file-tools)
- [Shell Tools](#shell-tools)
- [SimpleTool (Class-Based)](#simpletool-class-based)
- [ToolRegistry Advanced Usage](#toolregistry-advanced-usage)

---

## User Interaction Tools

Package: `ai.koog.agents.ext.tool`

### Registration

```kotlin
import ai.koog.agents.core.tools.ToolRegistry
import ai.koog.agents.ext.tool.AskUser
import ai.koog.agents.ext.tool.SayToUser
import ai.koog.agents.ext.tool.ExitTool

val toolRegistry = ToolRegistry {
    tool(AskUser)     // ask user a question, get text response
    tool(SayToUser)   // display message to user
    tool(ExitTool)    // terminate agent execution
}
```

### AskUser

LLM calls this to ask the user a question and receive a text response.

- **Args**: `question: String`
- **Returns**: User's text response

Use case: clarifying ambiguous requests, getting missing information.

### SayToUser

LLM calls this to display a message to the user (no response expected).

- **Args**: `message: String`
- **Returns**: Unit

Use case: showing intermediate results, progress updates, final answers.

### ExitTool

LLM calls this to terminate the agent execution.

- **Args**: `reason: String`
- **Returns**: Nothing (terminates)

Use case: graceful termination when task is complete or cannot be completed.

---

## File Tools

Package: `ai.koog.agents.ext.tool.file`

All file tools require a `FileSystemProvider` — use `JVMFileSystemProvider` for JVM:

```kotlin
import ai.koog.agents.ext.tool.file.ReadFileTool
import ai.koog.agents.ext.tool.file.WriteFileTool
import ai.koog.agents.ext.tool.file.EditFileTool
import ai.koog.agents.ext.tool.file.ListDirectoryTool
import ai.koog.rag.base.files.JVMFileSystemProvider

val toolRegistry = ToolRegistry {
    tool(ReadFileTool(JVMFileSystemProvider.ReadOnly))
    tool(WriteFileTool(JVMFileSystemProvider.ReadWrite))
    tool(EditFileTool(JVMFileSystemProvider.ReadWrite))
    tool(ListDirectoryTool(JVMFileSystemProvider.ReadOnly))
}
```

### ReadFileTool

Read file contents with optional line range.

- **Args**: `path: String`, `startLine: Int?`, `endLine: Int?`
- **Returns**: File content (or specified line range)

### WriteFileTool

Write text content to a file.

- **Args**: `path: String`, `content: String`, `createDirectories: Boolean = true`
- **Returns**: Success/failure status

### EditFileTool

Make targeted text replacements in a file.

- **Args**: `path: String`, `original: String`, `updated: String`
- **Returns**: Success/failure status

Uses token-normalized patch application for robust matching.

### ListDirectoryTool

List directory contents with hierarchical display and filtering.

- **Args**: `path: String`, `recursive: Boolean = false`, `maxDepth: Int?`, `includeHidden: Boolean = false`, `glob: String?`
- **Returns**: List of `FileSystemEntry` (files and folders with metadata)

```kotlin
// FileSystemEntry types:
sealed class FileSystemEntry {
    data class File(val name: String, val path: String, val size: FileSize, val content: Content)
    data class Folder(val name: String, val path: String, val children: List<FileSystemEntry>)
}
```

### Complete File Tools Example

```kotlin
import ai.koog.agents.core.agent.AIAgent
import ai.koog.agents.core.tools.ToolRegistry
import ai.koog.agents.ext.tool.SayToUser
import ai.koog.agents.ext.tool.AskUser
import ai.koog.agents.ext.tool.ExitTool
import ai.koog.agents.ext.tool.file.*
import ai.koog.rag.base.files.JVMFileSystemProvider

val fileAgentTools = ToolRegistry {
    tool(SayToUser)
    tool(AskUser)
    tool(ExitTool)
    tool(ReadFileTool(JVMFileSystemProvider.ReadOnly))
    tool(ListDirectoryTool(JVMFileSystemProvider.ReadOnly))
    tool(WriteFileTool(JVMFileSystemProvider.ReadWrite))
    tool(EditFileTool(JVMFileSystemProvider.ReadWrite))
}

val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    toolRegistry = fileAgentTools,
    systemPrompt = "You are a file assistant. Use tools to read, write, and list files."
)
```

---

## Shell Tools

Package: `ai.koog.agents.ext.tool.shell`

### ExecuteShellCommandTool

Execute shell commands on the host system.

```kotlin
import ai.koog.agents.ext.tool.shell.ExecuteShellCommandTool
import ai.koog.agents.ext.tool.shell.BraveModeConfirmationHandler
import ai.koog.agents.ext.tool.shell.PrintShellCommandConfirmationHandler

// Auto-approve all commands (dangerous!)
val shellTool = ExecuteShellCommandTool(
    confirmationHandler = BraveModeConfirmationHandler
)

// Ask user before executing each command
val safeShellTool = ExecuteShellCommandTool(
    confirmationHandler = PrintShellCommandConfirmationHandler
)

val toolRegistry = ToolRegistry {
    tool(shellTool)
}
```

- **Args**: `command: String`, `workingDirectory: String?`, `timeout: Long?` (ms)
- **Returns**: `exitCode: Int`, `stdout: String`, `stderr: String`

### Confirmation Handlers

| Handler | Behavior |
|---------|----------|
| `BraveModeConfirmationHandler` | Auto-approve all commands |
| `PrintShellCommandConfirmationHandler` | Print command and ask user |

---

## SimpleTool (Class-Based)

For tools that need custom serialization, complex args, or async execution. Alternative to annotation-based `@Tool`.

```kotlin
import ai.koog.agents.core.tools.SimpleTool
import kotlinx.serialization.Serializable

class WebSearchTool : SimpleTool<WebSearchTool.Args>(
    argsSerializer = Args.serializer(),
    name = "web_search",
    description = "Search the web for information"
) {
    @Serializable
    data class Args(
        val query: String,
        val maxResults: Int = 5
    )

    override suspend fun execute(args: Args): String {
        val results = httpClient.get("https://api.search.com") {
            parameter("q", args.query)
            parameter("limit", args.maxResults)
        }
        return results.bodyAsText()
    }
}

// Register:
val toolRegistry = ToolRegistry {
    tool(WebSearchTool())
}
```

### When to Use SimpleTool vs @Tool

| Feature | `@Tool` (annotation) | `SimpleTool` (class) |
|---------|----------------------|----------------------|
| Ease of use | Simpler, less boilerplate | More verbose |
| Async support | No (`fun`, not `suspend fun`) | Yes (`suspend fun execute`) |
| Custom serialization | Automatic via reflection | Manual via `KSerializer` |
| Complex args | Limited to primitives, String | Any `@Serializable` class |
| Naming | Method name or `@Tool(customName=)` | Constructor `name` param |

---

## ToolRegistry Advanced Usage

### Combining Registries

```kotlin
val baseTools = ToolRegistry {
    tool(AskUser)
    tool(SayToUser)
}

val fileTools = ToolRegistry {
    tool(ReadFileTool(JVMFileSystemProvider.ReadOnly))
    tool(ListDirectoryTool(JVMFileSystemProvider.ReadOnly))
}

// Merge registries
val allTools = baseTools + fileTools
```

### Converting ToolSet to Tool List

```kotlin
// .asTools() returns List<Tool<*, *>> from annotation-based ToolSet
val myTools: List<Tool<*, *>> = MyToolSet().asTools()

// Useful in subgraph definitions:
val sg by subgraphWithTask<String, String>(
    tools = MyToolSet().asTools() + listOf(AskUser, SayToUser)
) { input -> "Task: $input" }
```

### Getting Tools by Name/Type

```kotlin
val registry = ToolRegistry { /* ... */ }

// By name
val tool = registry.getTool("web_search")

// By type (reified)
val askUser = registry.getTool<AskUser>()
```

### Tool Descriptors

Every tool exposes a `ToolDescriptor` used by the LLM:

```kotlin
tool.descriptor.name        // tool name
tool.descriptor.description // tool description for LLM
tool.descriptor.parameters  // parameter definitions
```
