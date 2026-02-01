# Koog Tracing & Persistence Reference

## Tracing

Package: `ai.koog.agents.features.tracing.feature`

Captures trace events during agent execution for debugging, monitoring, and auditing.

### Installation

```kotlin
import ai.koog.agents.features.tracing.feature.Tracing
import ai.koog.agents.features.tracing.writer.TraceFeatureMessageLogWriter
import ai.koog.agents.features.tracing.writer.TraceFeatureMessageFileWriter
import io.github.oshai.kotlinlogging.KotlinLogging
import kotlinx.io.buffered
import kotlinx.io.files.Path
import kotlinx.io.files.SystemFileSystem

val logger = KotlinLogging.logger {}

val agent = AIAgent(...) {
    install(Tracing) {
        // Log to kotlin-logging
        addMessageProcessor(TraceFeatureMessageLogWriter(logger))

        // Write to file
        addMessageProcessor(TraceFeatureMessageFileWriter(
            Path("/path/to/trace.log"),
            { path -> SystemFileSystem.sink(path).buffered() }
        ))
    }
}
```

### Trace Writers

| Writer | Output |
|--------|--------|
| `TraceFeatureMessageLogWriter(logger)` | kotlin-logging logger |
| `TraceFeatureMessageFileWriter(path, sinkFactory)` | File on disk |
| `TraceFeatureMessageRemoteWriter(url, client)` | HTTP endpoint |

### Custom Trace Writer

Implement `TraceFeatureMessageProcessor`:

```kotlin
class CustomTraceWriter : TraceFeatureMessageProcessor {
    override suspend fun process(message: TraceFeatureMessage) {
        // message.eventType — what happened
        // message.timestamp — when
        // message.data — event-specific data
        myDatabase.insert(message)
    }
}

val agent = AIAgent(...) {
    install(Tracing) {
        addMessageProcessor(CustomTraceWriter())
    }
}
```

### Traced Events

All events from the EventHandler pipeline are traced:
- Agent start/complete/fail/close
- Strategy start/complete
- Node execution start/complete/fail
- LLM call start/complete
- LLM streaming start/frame/complete/fail
- Tool call start/complete/fail/validation-fail

---

## Persistence (Snapshots)

Package: `ai.koog.agents.snapshot.feature`

Save and restore agent state checkpoints for fault tolerance, time-travel debugging, and state rollback.

### Installation

```kotlin
import ai.koog.agents.snapshot.feature.Persistence
import ai.koog.agents.snapshot.feature.RollbackStrategy
import ai.koog.agents.snapshot.feature.InMemoryPersistenceStorageProvider

val agent = AIAgent(...) {
    install(Persistence) {
        // Storage backend
        storage = InMemoryPersistenceStorageProvider()

        // Auto-checkpoint after each node execution
        enableAutomaticPersistence = true

        // How to restore state
        rollbackStrategy = RollbackStrategy.Default
    }
}
```

### Rollback Strategies

| Strategy | Behavior |
|----------|----------|
| `RollbackStrategy.Default` | Full state machine checkpoint — resumes from exact same node |
| `RollbackStrategy.MessageHistoryOnly` | Only checkpoints message history (lighter) |

### Storage Providers

```kotlin
import ai.koog.agents.snapshot.feature.InMemoryPersistenceStorageProvider
import ai.koog.agents.snapshot.feature.FilePersistenceStorageProvider
import ai.koog.agents.snapshot.feature.NoPersistencyStorageProvider

// In-memory (lost on restart)
storage = InMemoryPersistenceStorageProvider()

// File-based (survives restart)
storage = FilePersistenceStorageProvider(Path("checkpoints/"))

// Disabled
storage = NoPersistencyStorageProvider()
```

### Rollback Tool Registry

When rolling back to a checkpoint, you may need to undo side-effects from tools that already executed. Register rollback handlers:

```kotlin
import ai.koog.agents.snapshot.feature.RollbackToolRegistry

val agent = AIAgent(...) {
    install(Persistence) {
        storage = FilePersistenceStorageProvider(Path("checkpoints/"))
        enableAutomaticPersistence = true
        rollbackStrategy = RollbackStrategy.Default

        // Define how to undo tool side-effects
        rollbackToolRegistry = RollbackToolRegistry {
            registerRollback(::createFile, ::deleteFile)
            registerRollback(::sendEmail, ::retractEmail)
            registerRollback(::updateDatabase, ::revertDatabase)
        }
    }
}
```

### Manual Checkpoint Management

```kotlin
// Inside a custom node, manually create/restore checkpoints
val saveCheckpoint by node<String, String> { input ->
    val persistence = features.get(Persistence)
    persistence?.saveCheckpoint("before-risky-operation")
    input
}

val restoreIfNeeded by node<String, String> { input ->
    if (input.contains("error")) {
        val persistence = features.get(Persistence)
        persistence?.restoreCheckpoint("before-risky-operation")
    }
    input
}
```

### Use Case: Fault-Tolerant Agent

```kotlin
val agent = AIAgent(
    promptExecutor = executor,
    llmModel = model,
    toolRegistry = toolRegistry,
    strategy = chatAgentStrategy(),
    systemPrompt = "You are a reliable assistant."
) {
    install(Persistence) {
        storage = FilePersistenceStorageProvider(Path("agent-state/"))
        enableAutomaticPersistence = true
        rollbackStrategy = RollbackStrategy.Default
    }

    handleEvents {
        onAgentExecutionFailed { ctx ->
            println("Agent failed: ${ctx.error}. State can be restored from checkpoint.")
        }
    }
}
```
