# Koog Agent Memory Reference

Package: `ai.koog.agents.memory`

## Installation

```kotlin
import ai.koog.agents.memory.feature.AgentMemory
import ai.koog.agents.memory.storage.SimpleStorage
import ai.koog.agents.memory.provider.LocalFileMemoryProvider
import ai.koog.agents.memory.provider.LocalMemoryConfig
import ai.koog.rag.base.files.JVMFileSystemProvider
import kotlinx.io.files.Path

val agent = AIAgent(...) {
    install(AgentMemory) {
        memoryProvider = LocalFileMemoryProvider(
            config = LocalMemoryConfig("my-memory"),
            storage = SimpleStorage(JVMFileSystemProvider),
            root = Path("memory/data")
        )
        featureName = "my-feature"
        organizationName = "my-org"
    }
}
```

## Core Concepts

### Concept

A category/topic for stored information:

```kotlin
import ai.koog.agents.memory.model.Concept
import ai.koog.agents.memory.model.FactType

val userNameConcept = Concept(
    keyword = "user-name",
    description = "The user's preferred name",
    factType = FactType.SINGLE      // one value per subject
)

val interestsConcept = Concept(
    keyword = "user-interests",
    description = "Topics the user is interested in",
    factType = FactType.MULTI       // multiple values per subject
)
```

- `FactType.SINGLE` — one fact per concept+subject (overwrites on save)
- `FactType.MULTI` — multiple facts accumulate

### Fact

A piece of information stored in memory:

```kotlin
import ai.koog.agents.memory.model.SingleFact
import ai.koog.agents.memory.model.MultiFact
import kotlinx.datetime.Clock

// Single fact
val nameFact = SingleFact(
    concept = userNameConcept,
    value = "John",
    timestamp = Clock.System.now().toEpochMilliseconds()
)

// Multi fact
val interestFact = MultiFact(
    concept = interestsConcept,
    values = listOf("Kotlin", "AI agents", "music"),
    timestamp = Clock.System.now().toEpochMilliseconds()
)
```

### MemoryScope

Defines the context/lifetime of facts:

```kotlin
import ai.koog.agents.memory.model.MemoryScope

MemoryScope.Global                    // available everywhere
MemoryScope.Product("my-app")        // scoped to a product/app
MemoryScope.Feature("chat-module")   // scoped to a feature
MemoryScope.CrossProduct              // shared across products
```

### MemorySubject

What/who the memory is about:

```kotlin
import ai.koog.agents.memory.model.MemorySubject

MemorySubject.Everything              // general facts
MemorySubject.User                    // about the user

// Custom subjects:
object MemorySubjects {
    val User = MemorySubject("user")
    val Project = MemorySubject("project")
    val Session = MemorySubject("session")
}
```

## Direct Provider API

### Save Facts

```kotlin
memoryProvider.save(
    fact = SingleFact(
        concept = Concept("greeting", "User's name", FactType.SINGLE),
        value = "John",
        timestamp = Clock.System.now().toEpochMilliseconds()
    ),
    subject = MemorySubjects.User,
    scope = MemoryScope.Product("my-app")
)
```

### Load Facts

```kotlin
val facts = memoryProvider.load(
    concept = Concept("greeting", "User's name", FactType.SINGLE),
    subject = MemorySubjects.User,
    scope = MemoryScope.Product("my-app")
)

if (facts.isNotEmpty()) {
    println("Found: ${facts.joinToString(", ")}")
} else {
    println("No memories found")
}
```

## Using Memory in Strategy Nodes

### withMemory DSL

Inside any custom node, access memory via `withMemory`:

```kotlin
import ai.koog.agents.memory.feature.withMemory

val loadUserPrefs by node<String, String> { input ->
    withMemory {
        loadFactsToAgent(
            llm = llm,
            concept = Concept(
                "preferred-language",
                "What programming language is preferred by the user?",
                FactType.SINGLE
            )
        )
    }
    input // pass through
}

val saveUserPrefs by node<String, String> { input ->
    withMemory {
        saveFactsFromHistory(
            llm = llm,
            concept = Concept(
                "preferred-language",
                "What programming language is preferred by the user?",
                FactType.SINGLE
            ),
            subject = MemorySubjects.User,
            scope = MemoryScope.Product("my-app")
        )
    }
    input
}
```

### Predefined Memory Nodes

```kotlin
import ai.koog.agents.memory.feature.nodes.*

val strategy = strategy<String, String>("with-memory") {
    val nodeLLM by nodeLLMRequest()

    // Load facts into prompt before LLM call
    val loadMem by nodeLoadFromMemory(
        name = "loadMemory",
        scopeTypes = listOf(MemoryScopeType.Product, MemoryScopeType.Global)
    )

    // Save facts after conversation
    val saveMem by nodeSaveToMemory(
        name = "saveMemory",
        scopes = listOf(MemoryScope.Product("my-app"))
    )

    // Auto-detect facts from history and save
    val autoSave by nodeSaveToMemoryAutoDetectFacts(
        name = "autoSave",
        scopes = listOf(MemoryScope.Product("my-app"))
    )

    // Load all facts (all concepts)
    val loadAll by nodeLoadAllFactsFromMemory(
        name = "loadAll",
        scopeTypes = listOf(MemoryScopeType.Product)
    )

    edge(nodeStart forwardTo loadMem)
    edge(loadMem forwardTo nodeLLM)
    // ... rest of strategy
}
```

## Memory Providers

### LocalFileMemoryProvider

File-based persistence:

```kotlin
import ai.koog.agents.memory.provider.LocalFileMemoryProvider
import ai.koog.agents.memory.provider.LocalMemoryConfig
import ai.koog.agents.memory.storage.SimpleStorage
import ai.koog.rag.base.files.JVMFileSystemProvider
import kotlinx.io.files.Path

val memoryProvider = LocalFileMemoryProvider(
    config = LocalMemoryConfig("agent-memory"),
    storage = SimpleStorage(JVMFileSystemProvider),
    root = Path("data/memory")
)
```

### Encrypted Storage

For sensitive data:

```kotlin
import ai.koog.agents.memory.storage.EncryptedStorage
import ai.koog.agents.memory.storage.Aes256GCMEncryptor
import ai.koog.rag.base.files.JVMFileSystemProvider

val secureStorage = EncryptedStorage(
    fs = JVMFileSystemProvider.ReadWrite,
    encryption = Aes256GCMEncryptor("your-secret-key-here")
)

val memoryProvider = LocalFileMemoryProvider(
    config = LocalMemoryConfig("secure-memory"),
    storage = secureStorage,
    root = Path("data/secure-memory")
)
```

### NoMemory

Disable memory (default if not installed):

```kotlin
import ai.koog.agents.memory.provider.NoMemory

val memoryProvider = NoMemory
```

## Strategy Pattern: Memory-Augmented Chat

```kotlin
val strategy = strategy<String, String>("memory-chat") {
    val loadMemory by nodeLoadFromMemory("load", listOf(MemoryScopeType.Product))
    val callLLM by nodeLLMRequest()
    val execTool by nodeExecuteTool()
    val sendResult by nodeLLMSendToolResult()
    val saveMemory by nodeSaveToMemoryAutoDetectFacts(
        "save", listOf(MemoryScope.Product("my-app"))
    )

    // Load memory → LLM call → tool loop → save memory → finish
    edge(nodeStart forwardTo loadMemory)
    edge(loadMemory forwardTo callLLM)
    edge(callLLM forwardTo execTool onToolCall { true })
    edge(execTool forwardTo sendResult)
    edge(sendResult forwardTo execTool onToolCall { true })
    edge(callLLM forwardTo saveMemory onAssistantMessage { true })
    edge(sendResult forwardTo saveMemory onAssistantMessage { true })
    edge(saveMemory forwardTo nodeFinish)
}
```
