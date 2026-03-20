---
name: rag-memory
description: Implement RAG (Retrieval-Augmented Generation) memory patterns for AI agents
tags: [memory, rag, retrieval, generation, context]
version: 1.0.0
---

# RAG Memory Skill

## Purpose

Implement **RAG (Retrieval-Augmented Generation)** memory patterns for AI agents. RAG enhances LLM capabilities by retrieving relevant context from external memory sources before generating responses, combining the strengths of both retrieval-based and generation-based approaches.

## What is RAG?

**RAG** enhances LLMs by:
1. **Retrieving** relevant information from external sources (memory, documents, databases)
2. **Augmenting** the LLM's context with this information
3. **Generating** responses based on the augmented context

This addresses limitations like:
- Hallucinations (making things up)
- Knowledge cutoff (old information)
- Context window limits
- Static knowledge

## When to Use

- **Long-term Memory** - Agents that need to remember conversations across sessions
- **Document Analysis** - Processing and querying large documents
- **Personalized Responses** - Tailoring responses to specific users
- **Knowledge Management** - Centralizing and retrieving knowledge
- **FAQ Systems** - Providing accurate answers to questions
- **Customer Support** - Using company knowledge base
- **Research Assistance** - Finding relevant information from archives
- **Learning Systems** - Building agent knowledge over time

## RAG Architecture

### Core Components

```
┌─────────────┐
│  Query      │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────┐
│   Retrieval │────▶│  Embedding   │
│   Layer     │     │   Model      │
└──────┬──────┘     └──────┬───────┘
       │                   │
       ▼                   │
┌─────────────┐             │
│ Similarity  │             │
│ Search      │             │
└──────┬──────┘             │
       │                    │
       ▼                    │
┌─────────────┐             │
│  Top-K      │             │
│  Retrieved  │             │
│  Context    │             │
└──────┬──────┘             │
       │                    │
       └────────┬───────────┘
                ▼
        ┌─────────────┐
        │  LLM Prompt │
        │  Augmented  │
        └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │   Generated │
        │   Response  │
        └─────────────┘
```

## RAG Workflow

### 1. Indexing Phase

```kotlin
data class MemoryDocument(
    val id: String,
    val content: String,
    val metadata: Map<String, Any>,
    val embedding: List<Float>,
    val createdAt: Long,
    val tags: List<String>
)

fun indexDocument(document: MemoryDocument) {
    // 1. Generate embedding
    val embedding = generateEmbedding(document.content)

    // 2. Store in vector database
    vectorStore.insert(document.id, embedding, document.metadata)

    // 3. Update inverted index (for keyword search)
    invertedIndex.update(document.id, document.content)

    // 4. Update filters (for metadata search)
    metadataIndex.update(document.id, document.metadata)
}
```

### 2. Retrieval Phase

```kotlin
data class RetrievalConfig(
    val k: Int = 5,              // Number of documents to retrieve
    val similarityThreshold: Double = 0.7,
    val queryExpansion: Boolean = true,
    val hybridSearch: Boolean = true
)

fun retrieveContext(
    query: String,
    config: RetrievalConfig = RetrievalConfig()
): List<MemoryDocument> {
    // 1. Generate query embedding
    val queryEmbedding = generateEmbedding(query)

    // 2. Hybrid search (vector + keyword)
    val vectorResults = vectorStore.search(queryEmbedding, config.k)
    val keywordResults = keywordSearch(query, config.k)

    // 3. Combine results with re-ranking
    val combinedResults = hybridSearch(vectorResults, keywordResults, query)

    // 4. Apply similarity threshold
    val filteredResults = combinedResults
        .filter { it.score >= config.similarityThreshold }
        .take(config.k)

    // 5. Re-rank using final query
    val finalResults = reRank(filteredResults, query)

    return finalResults
}
```

### 3. Augmentation Phase

```kotlin
fun augmentPrompt(
    query: String,
    retrievedDocs: List<MemoryDocument>
): String {
    // 1. Format retrieved documents
    val context = retrievedDocs.joinToString("\n\n") { doc ->
        formatDocument(doc)
    }

    // 2. Build augmented prompt
    val augmentedPrompt = """
        You are an AI assistant with access to the following context:

        Context:
        $context

        Question: $query

        Answer the question based on the context. If the context doesn't contain
        the answer, say "I don't know" or "The information is not available in memory".
    """.trimIndent()

    return augmentedPrompt
}
```

### 4. Generation Phase

```kotlin
fun generateResponse(
    query: String,
    retrievedDocs: List<MemoryDocument>
): String {
    // 1. Augment prompt
    val augmentedPrompt = augmentPrompt(query, retrievedDocs)

    // 2. Call LLM
    val response = llm.complete(
        prompt = augmentedPrompt,
        temperature = 0.3,  // Lower temperature for more factual responses
        maxTokens = 2000
    )

    return response
}
```

## RAG Implementation in Agents

### Agent with RAG Memory

```kotlin
class RagAgent(
    private val memoryStore: MemoryStore,
    private val embeddingModel: EmbeddingModel,
    private val llm: LLM,
    private val retrievalConfig: RetrievalConfig = RetrievalConfig()
) {
    suspend fun processQuery(query: String): String {
        // 1. Retrieve relevant context
        val retrievedDocs = retrieveContext(query, retrievalConfig)

        // 2. Generate response using retrieved context
        return generateResponse(query, retrievedDocs)
    }

    suspend fun storeExperience(
        experience: String,
        metadata: Map<String, Any> = emptyMap()
    ) {
        // 1. Create document
        val doc = MemoryDocument(
            id = UUID.randomUUID().toString(),
            content = experience,
            metadata = metadata,
            createdAt = System.currentTimeMillis()
        )

        // 2. Index the document
        indexDocument(doc)
    }
}
```

## Predefined RAG Patterns

### Pattern 1: Conversational Memory

Maintain a running conversation history with RAG:

```kotlin
data class ConversationContext(
    val conversationId: String,
    val messages: List<ConversationMessage>,
    val userPreferences: Map<String, Any>,
    val relevantHistory: List<MemoryDocument>
)

fun updateConversation(
    conversationId: String,
    userMessage: String,
    botResponse: String
) {
    // 1. Retrieve relevant past conversations
    val relevantHistory = retrieveContext(
        query = userMessage,
        config = RetrievalConfig(k = 3)
    )

    // 2. Update conversation context
    val updatedContext = conversationContext.copy(
        messages = conversationContext.messages +
            ConversationMessage(role = "user", content = userMessage) +
            ConversationMessage(role = "assistant", content = botResponse),
        relevantHistory = relevantHistory
    )

    // 3. Store updated context
    memoryStore.save(conversationId, updatedContext)
}
```

### Pattern 2: Document Q&A

Query documents with RAG:

```kotlin
data class DocumentQAPattern(
    val documents: List<MemoryDocument>,
    val question: String
) {
    fun answer() {
        // 1. Retrieve relevant documents
        val retrievedDocs = retrieveContext(question)

        // 2. Extract key information
        val keyInfo = extractKeyInformation(question, retrievedDocs)

        // 3. Generate answer
        val answer = generateResponse(question, retrievedDocs)

        return Answer(question, retrievedDocs, keyInfo, answer)
    }
}
```

### Pattern 3: Personal Assistant

Personal assistant with personalized RAG:

```kotlin
data class PersonalAssistantPattern(
    val userProfile: UserProfile,
    val conversationHistory: List<Message>,
    val userKnowledgeBase: List<MemoryDocument>
) {
    fun provideAssistance(query: String): String {
        // 1. Retrieve user-specific context
        val retrievedDocs = retrieveContext(
            query = query,
            config = RetrievalConfig(
                k = 5,
                similarityThreshold = 0.75
            )
        )

        // 2. Generate personalized response
        val response = generateResponse(query, retrievedDocs)

        return response
    }
}
```

### Pattern 4: Learning Agent

Learning agent that builds knowledge over time:

```kotlin
class LearningAgent(
    private val knowledgeBase: MemoryStore,
    private val embeddingModel: EmbeddingModel
) {
    suspend fun learn(newKnowledge: KnowledgeItem) {
        // 1. Process new knowledge
        val processed = preprocessKnowledge(newKnowledge)

        // 2. Generate embedding
        val embedding = generateEmbedding(processed.content)

        // 3. Store in knowledge base
        val doc = MemoryDocument(
            id = UUID.randomUUID().toString(),
            content = processed.content,
            metadata = mapOf(
                "type" to processed.type,
                "source" to processed.source,
                "timestamp" to System.currentTimeMillis()
            ),
            embedding = embedding,
            tags = processed.tags
        )

        indexDocument(doc)
    }

    suspend fun queryKnowledge(query: String): KnowledgeAnswer {
        // 1. Retrieve relevant knowledge
        val retrievedDocs = retrieveContext(query)

        // 2. Generate response
        val response = generateResponse(query, retrievedDocs)

        return KnowledgeAnswer(query, retrievedDocs, response)
    }
}
```

## Integration with Existing Skills

### RAG + Context Persistence

```kotlin
class EnhancedContextPersistence(
    private val ragMemory: MemoryStore,
    private val sessionManager: SessionManager
) {
    fun resumeSession(sessionId: String): SessionContext {
        // 1. Retrieve long-term memory for context
        val longTermMemory = ragMemory.retrieveContext(
            query = "Previous session context",
            config = RetrievalConfig(k = 3)
        )

        // 2. Load session-specific context
        val sessionContext = sessionManager.load(sessionId)

        // 3. Combine both
        return sessionContext.copy(
            longTermMemory = longTermMemory
        )
    }
}
```

### RAG + Tool Orchestration

```kotlin
fun performResearchTask(topic: String) {
    // Use ReAct pattern for high-level reasoning
    val reactContext = executeReAct(topic)

    // Use tool-orchestration for detailed steps
    val chain = ToolChainDSL<String, ResearchResult>()
        .bead("Search Knowledge Base", { _ -> searchKnowledgeBase(topic) })
        .bead("Analyze Results", { results -> analyzeResults(results) })
        .bead("Generate Insights", { analysis -> generateInsights(analysis) })
        .bead("Save to Memory", { insights -> saveToRagMemory(insights) })
        .build()

    val result = chain.execute(topic)
}
```

## RAG Configuration

### Embedding Model

```kotlin
data class EmbeddingConfig(
    val model: String = "text-embedding-ada-002",
    val dimension: Int = 1536,
    val batchSize: Int = 100,
    val timeoutMs: Long = 30000
)

fun generateEmbedding(text: String): List<Float> {
    return embeddingClient.embed(
        text = text,
        config = EmbeddingConfig()
    )
}
```

### Vector Database

```kotlin
interface VectorStore {
    fun insert(id: String, embedding: List<Float>, metadata: Map<String, Any>)
    fun search(embedding: List<Float>, k: Int): List<SearchResult>
    fun delete(id: String)
    fun update(id: String, embedding: List<Float>, metadata: Map<String, Any>)
}

// Simple in-memory implementation
class InMemoryVectorStore : VectorStore {
    private val store = mutableMapOf<String, IndexedDocument>()
    private val embeddingMap = mutableMapOf<String, List<Float>>()

    override fun insert(id: String, embedding: List<Float>, metadata: Map<String, Any>) {
        store[id] = IndexedDocument(id, embedding, metadata)
        embeddingMap[id] = embedding
    }

    override fun search(embedding: List<Float>, k: Int): List<SearchResult> {
        // Calculate cosine similarity
        val results = embeddingMap.entries.map { (id, storedEmbedding) ->
            val similarity = cosineSimilarity(embedding, storedEmbedding)
            SearchResult(id, similarity, store[id]?.metadata)
        }

        // Sort by similarity and return top k
        return results
            .sortedByDescending { it.similarity }
            .take(k)
    }
}
```

### Hybrid Search

```kotlin
data class SearchResult(
    val id: String,
    val score: Double,
    val metadata: Map<String, Any>?,
    val content: String? = null
)

fun hybridSearch(
    vectorResults: List<SearchResult>,
    keywordResults: List<SearchResult>,
    query: String
): List<SearchResult> {
    // 1. Weight vector search higher for semantic similarity
    val vectorWeight = 0.7
    val keywordWeight = 0.3

    // 2. Combine scores
    val combinedResults = mutableMapOf<String, Double>()

    vectorResults.forEach { result ->
        combinedResults[result.id] = combinedResults.getOrDefault(result.id, 0.0) +
            result.score * vectorWeight
    }

    keywordResults.forEach { result ->
        combinedResults[result.id] = combinedResults.getOrDefault(result.id, 0.0) +
            result.score * keywordWeight
    }

    // 3. Re-rank by combined score
    return combinedResults.entries
        .map { (id, score) ->
            SearchResult(
                id = id,
                score = score,
                metadata = vectorResults.find { it.id == id }?.metadata
            )
        }
        .sortedByDescending { it.score }
}
```

## RAG Prompt Templates

### Template 1: Q&A

```markdown
You are an AI assistant with access to the following information:

## Retrieved Context

${context}

## Question

${query}

## Instructions

1. Answer the question based on the retrieved context
2. If the context doesn't contain the answer, say "I don't have information about this in memory"
3. Cite your sources using the context
4. If multiple answers exist, provide all of them
```

### Template 2: Personal Assistant

```markdown
You are a personal assistant for ${user.name}. Here's what you know about them:

## User Profile

${user.profile}

## Retrieved Context

${context}

## Conversation History

${conversationHistory}

## Current Request

${query}

## Instructions

1. Provide a helpful, personalized response
2. Reference the user's preferences when relevant
3. Use the retrieved context to provide accurate information
4. Maintain a friendly, helpful tone
5. Remember this interaction for future conversations
```

### Template 3: Knowledge Extraction

```markdown
## Task

Extract and summarize the following information:

## Retrieved Documents

${context}

## Source Information

- ${documentSource}
- ${documentDate}

## Instructions

1. Extract key information from the documents
2. Summarize the main points
3. Identify any important entities, dates, or values
4. Note any conflicting information
5. Provide a concise summary in 3-5 paragraphs
```

## RAG Evaluation Metrics

### Retrieval Metrics

```kotlin
data class RetrievalMetrics(
    val precisionAtK: Double,      // Precision at top K results
    val recallAtK: Double,         // Recall at top K results
    val meanReciprocalRank: Double, // MRR score
    val f1Score: Double,           // F1 score
    val hitRate: Double            // Percentage of queries with at least one relevant result
)
```

### Generation Metrics

```kotlin
data class GenerationMetrics(
    val faithfulness: Double,      // Faithfulness to retrieved context
    val relevance: Double,         // Relevance to query
    val coherence: Double,         // Coherence of response
    val helpfulness: Double,       // Helpfulness to user
    val answerCorrectness: Double  // Accuracy of the answer
)
```

## Best Practices

### ✅ Do

- **Chunk documents appropriately** - Use chunking strategies (semantic, fixed-size)
- **Index metadata** - Enable fast filtering by metadata
- **Update embeddings regularly** - Keep memories current
- **Use hybrid search** - Combine vector and keyword search
- **Provide source citations** - Help users verify information
- **Monitor performance** - Track retrieval and generation metrics
- **Handle retrieval failures** - Graceful degradation when retrieval fails
- **Use appropriate chunk sizes** - Balance detail and context window

### ❌ Don't

- **Don't retrieve too much context** - Exceeds LLM context window
- **Don't ignore relevance scoring** - Filter irrelevant documents
- **Don't forget to store new knowledge** - Continuously build memory
- **Don't use static embeddings** - Embeddings should reflect current knowledge
- **Don't mix sources indiscriminately** - Organize by source/topic
- **Don't ignore relevance feedback** - User feedback improves retrieval

## Common Issues and Solutions

### Issue 1: Hallucinations

**Problem:** Agent makes up information not in retrieved context

**Solution:**
```kotlin
fun generateFaithfulResponse(
    query: String,
    retrievedDocs: List<MemoryDocument>
): String {
    val context = formatContext(retrievedDocs)
    val prompt = """
        Answer the question based ONLY on the provided context.

        Context:
        $context

        Question: $query

        If the context doesn't contain the answer, say "I don't have information about this in memory."
    """.trimIndent()

    return llm.complete(prompt, temperature = 0.0)
}
```

### Issue 2: Low Retrieval Quality

**Problem:** Retrieval doesn't find relevant documents

**Solution:**
```kotlin
// Use query expansion
fun enhancedRetrieve(query: String): List<MemoryDocument> {
    // 1. Expand query with synonyms
    val expandedQuery = queryExpansion.expand(query)

    // 2. Generate multiple queries
    val queries = listOf(query, expandedQuery)

    // 3. Retrieve from each query
    val allResults = queries.flatMap { retrieveContext(it) }

    // 4. Deduplicate and re-rank
    return deduplicateAndReRank(allResults)
}
```

### Issue 3: Context Window Exceeded

**Problem:** Retrieved documents exceed LLM context window

**Solution:**
```kotlin
fun retrieveWithinContextWindow(
    query: String,
    maxTokens: Int
): List<MemoryDocument> {
    val retrievedDocs = retrieveContext(query)

    // 1. Calculate total tokens
    var totalTokens = estimateTokens(query)

    // 2. Select top documents until limit reached
    val selectedDocs = mutableListOf<MemoryDocument>()
    var totalTokensInDocs = 0

    for (doc in retrievedDocs) {
        val docTokens = estimateTokens(doc.content)

        if (totalTokens + totalTokensInDocs + docTokens <= maxTokens) {
            selectedDocs.add(doc)
            totalTokensInDocs += docTokens
        } else {
            break
        }
    }

    return selectedDocs
}
```

## Integration Examples

### Example 1: Chatbot with Memory

```kotlin
class MemoryChatbot {
    private val memoryStore = MemoryStore()
    private val ragAgent = RagAgent(memoryStore, embeddingModel, llm)

    fun chat(userId: String, message: String): String {
        // 1. Retrieve user's relevant memories
        val retrievedDocs = ragAgent.retrieveContext(
            query = message,
            config = RetrievalConfig(k = 5, similarityThreshold = 0.7)
        )

        // 2. Generate response with RAG
        val response = ragAgent.generateResponse(message, retrievedDocs)

        // 3. Store conversation for future reference
        memoryStore.storeExperience(
            experience = "$userId: $message → $response",
            metadata = mapOf(
                "userId" to userId,
                "timestamp" to System.currentTimeMillis(),
                "category" to determineCategory(message)
            )
        )

        return response
    }
}
```

### Example 2: Knowledge Base Assistant

```kotlin
class KnowledgeBaseAssistant(
    private val knowledgeBase: MemoryStore,
    private val documentProcessor: DocumentProcessor
) {
    suspend fun uploadDocument(documentId: String, content: String) {
        // 1. Process and chunk document
        val chunks = documentProcessor.process(content)

        // 2. Index each chunk
        chunks.forEach { chunk ->
            memoryStore.insertDocument(
                id = "$documentId-$chunk.id",
                content = chunk.content,
                metadata = mapOf(
                    "documentId" to documentId,
                    "chunkId" to chunk.id,
                    "title" to chunk.title,
                    "tags" to chunk.tags
                )
            )
        }
    }

    suspend fun queryKnowledgeBase(question: String): KnowledgeAnswer {
        // 1. Retrieve relevant chunks
        val retrievedChunks = memoryStore.retrieveContext(
            query = question,
            config = RetrievalConfig(k = 5)
        )

        // 2. Generate answer
        val answer = ragAgent.generateResponse(question, retrievedChunks)

        return KnowledgeAnswer(
            question = question,
            retrievedChunks = retrievedChunks,
            answer = answer
        )
    }
}
```

### Example 3: Personal Learning Agent

```kotlin
class LearningAgent(
    private val knowledgeBase: MemoryStore,
    private val embeddingModel: EmbeddingModel
) {
    suspend fun studyTopic(topic: String, material: LearningMaterial) {
        // 1. Process learning material
        val summaries = material.process()

        // 2. Index summaries
        summaries.forEach { summary ->
            memoryStore.insertDocument(
                id = "$topic-${summary.id}",
                content = summary.content,
                metadata = mapOf(
                    "topic" to topic,
                    "type" to summary.type,
                    "complexity" to summary.complexity,
                    "importance" to summary.importance
                )
            )
        }
    }

    suspend fun review(topic: String): ReviewResponse {
        // 1. Retrieve all related knowledge
        val retrievedDocs = memoryStore.retrieveContext(
            query = topic,
            config = RetrievalConfig(k = 10)
        )

        // 2. Generate summary and review questions
        val summary = ragAgent.generateResponse(
            query = "Summarize the following topics: ${retrievedDocs.joinToString { it.content }}",
            retrievedDocs = retrievedDocs
        )

        // 3. Generate practice questions
        val questions = generatePracticeQuestions(retrievedDocs)

        return ReviewResponse(
            summary = summary,
            questions = questions,
            reviewedTopics = retrievedDocs.map { it.metadata["topic"] as String }
        )
    }
}
```

## Advanced RAG Techniques

### 1. Dynamic Retrieval

```kotlin
fun dynamicRetrieve(
    query: String,
    conversationHistory: List<Message>,
    userContext: Map<String, Any>
): List<MemoryDocument> {
    // Build composite query from multiple sources
    val compositeQuery = buildCompositeQuery(query, conversationHistory, userContext)

    // Retrieve based on composite query
    return retrieveContext(compositeQuery)
}

fun buildCompositeQuery(
    query: String,
    conversationHistory: List<Message>,
    userContext: Map<String, Any>
): String {
    val historyContext = conversationHistory
        .takeLast(5)
        .joinToString(" ") { "${it.role}: ${it.content}" }

    val userContextText = userContext
        .map { "${it.key}: ${it.value}" }
        .joinToString(", ")

    return """
        Query: $query
        Recent conversation: $historyContext
        User context: $userContextText
    """.trimIndent()
}
```

### 2. Multi-Stage Retrieval

```kotlin
fun multiStageRetrieve(query: String): List<MemoryDocument> {
    // Stage 1: Broad retrieval
    val broadResults = retrieveContext(query, RetrievalConfig(k = 20))

    // Stage 2: Re-ranking
    val rerankedResults = reRank(broadResults, query)

    // Stage 3: Narrow retrieval for top results
    val narrowResults = broadResults.take(10).map { doc ->
        val narrowQuery = "${doc.content}. ${query}"
        retrieveContext(narrowQuery, RetrievalConfig(k = 3))
    }.flatten()

    return narrowResults.take(5)
}
```

### 3. Knowledge Graph + RAG

```kotlin
data class KnowledgeGraph(
    val nodes: Map<String, Node>,
    val edges: List<Edge>
)

data class KnowledgeGraphRAG(
    private val graph: KnowledgeGraph,
    private val memoryStore: MemoryStore
) {
    fun retrieveGraphContext(query: String): List<MemoryDocument> {
        // 1. Find relevant nodes using RAG
        val relevantNodes = retrieveContext(query, RetrievalConfig(k = 10))

        // 2. Find connected nodes (graph traversal)
        val connectedNodes = relevantNodes.flatMap { node ->
            val neighbors = findNeighbors(node.id)
            neighbors.map { neighborId ->
                memoryStore.getDocument(neighborId)
                    ?: MemoryDocument(
                        id = neighborId,
                        content = "Node not found",
                        metadata = emptyMap()
                    )
            }
        }

        // 3. Combine and deduplicate
        return (relevantNodes + connectedNodes).distinctBy { it.id }.take(10)
    }

    private fun findNeighbors(nodeId: String): List<String> {
        // Find nodes connected to nodeId
        return graph.edges
            .filter { it.source == nodeId || it.target == nodeId }
            .flatMap { edge ->
                if (edge.source == nodeId) listOf(edge.target)
                else listOf(edge.source)
            }
            .distinct()
    }
}
```

## Performance Optimization

### Caching Results

```kotlin
class CachedRAGMemory(
    private val delegate: RAGMemory,
    private val cache: LRUCache<String, List<MemoryDocument>>
) {
    fun retrieveContext(query: String): List<MemoryDocument> {
        // Check cache first
        val cacheKey = generateCacheKey(query)
        cache.get(cacheKey)?.let { return it }

        // Retrieve and cache
        val results = delegate.retrieveContext(query)
        cache.put(cacheKey, results)

        return results
    }
}
```

### Batch Processing

```kotlin
fun batchIndexDocuments(documents: List<MemoryDocument>) {
    // Batch embeddings
    val embeddings = embeddingModel.batchEmbed(documents.map { it.content })

    // Batch insert
    documents.zip(embeddings).forEach { (doc, embedding) ->
        doc.copy(embedding = embedding)
        vectorStore.insert(doc.id, embedding, doc.metadata)
    }
}
```

## Resources

- **RAG Paper**: [Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks](https://arxiv.org/abs/2005.11401)
- **LangChain RAG**: [LangChain RAG Implementation](https://python.langchain.com/docs/modules/data_connection/document_retrievers/)
- **Pinecone RAG**: [Pinecone RAG Guide](https://www.pinecone.io/learn/rag/)
- **Weaviate RAG**: [Weaviate RAG Patterns](https://weaviate.io/developers/weaviate/rag)
- **Modern RAG**: [Modern RAG: Architectures, Applications, and Frontiers](https://arxiv.org/abs/2404.16198)

## Summary

RAG memory enhances AI agents by:
1. **Retrieving** relevant information from external memory
2. **Augmenting** the LLM's context with retrieved information
3. **Generating** responses based on augmented context

This creates agents that:
- Remember conversations across sessions
- Provide accurate, grounded answers
- Learn and improve over time
- Maintain personal context and preferences
- Handle knowledge-intensive tasks effectively
