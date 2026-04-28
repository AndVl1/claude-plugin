---
name: graph-of-thoughts
description: "Implement Graph-of-Thoughts (GoT) pattern for multi-hop reasoning and networked decision making. Use this skill when the user asks to: (1) implement GoT patterns, (2) create multi-hop reasoning workflows, (3) design networked decision graphs, (4) understand GoT for complex problem solving, (5) integrate GoT with other patterns, or (6) implement graph-based reasoning agents. Trigger on phrases like 'GoT', 'Graph of Thoughts', 'multi-hop reasoning', 'networked decisions', 'graph-based reasoning', 'GoT pattern', or 'graph reasoning'."
---

# Graph of Thoughts (GoT) Pattern

**Graph-of-Thoughts** extends Tree-of-Thoughts by introducing a **graph-based structure** where nodes can have multiple parents and relationships, enabling more flexible reasoning with cycles, parallel branches, and interconnected decisions.

---

## Why GoT vs ToT?

| Aspect | Tree-of-Thoughts | Graph-of-Thoughts |
|--------|------------------|-------------------|
| **Structure** | Hierarchical tree | Networked graph |
| **Flow** | Single parent → multiple children | Multi-parent, multi-child |
| **Cycles** | No (tree structure) | Yes (cycles allowed) |
| **Parallel** | Sequential exploration | Parallel branches |
| **Interconnections** | Linear chains | Rich relationships |
| **Use Case** | Linear decision paths | Complex interdependent decisions |
| **Memory** | Simple tree | Rich graph state |
| **Visualization** | Tree diagrams | Network graphs |

---

## GoT Core Concepts

### Graph Nodes (Thoughts)

```kotlin
data class GoTNode(
    val id: String,
    val content: String,              // The thought or decision
    val type: NodeType,               // Decision, Fact, Action, Question
    val status: NodeStatus = NodeStatus.PENDING,
    val dependencies: List<String> = emptyList(), // Parent node IDs
    val relationships: List<NodeRelationship> = emptyList(),
    val metadata: Map<String, Any> = emptyMap()
)

enum class NodeType {
    DECISION,      // A choice to be made
    FACT,          // Established truth
    ACTION,        // Step to execute
    QUESTION,      // Query to answer
    CONSTRAINT,    // Boundary condition
    EVALUATION     // Assessment of another node
}

enum class NodeStatus {
    PENDING,       // Not yet evaluated
    EVALUATING,    // Currently evaluating
    RESOLVED,      // Answer found
    CONFLICTED,    // Multiple valid options
    CYCLIC,        // In a cycle
    INVALID        // Conflict detected
}
```

### Node Relationships

```kotlin
data class NodeRelationship(
    val type: RelationshipType,
    val strength: Double,             // 0.0-1.0, how strongly connected
    val direction: RelationshipDirection,
    val metadata: Map<String, Any> = emptyMap()
)

enum class RelationshipType {
    CAUSE,           // A leads to B
    EFFECT,          // A is caused by B
    CONTRADICTION,   // A contradicts B
    SUPPORTS,        // A supports B
    CONFLICTS,       // A conflicts with B
    DEPENDS_ON,      // A depends on B
    EQUIVALENT,      // A is equivalent to B
    CONDITION        // A is conditional on B
}

enum class RelationshipDirection {
    OUTGOING,        // From A to B
    INCOMING,        // From B to A
    BOTH             // Both directions
}
```

### Graph Structure

```kotlin
data class GoTGraph(
    val nodes: Map<String, GoTNode> = emptyMap(),
    val relationships: List<NodeRelationship> = emptyList(),
    val context: GoTContext = GoTContext(),
    val metadata: Map<String, Any> = emptyMap()
)

data class GoTContext(
    val variables: Map<String, Any> = emptyMap(),
    val constraints: List<String> = emptyList(),
    val facts: List<String> = emptyList(),
    val decisions: Map<String, Any> = emptyMap(),
    val history: List<GoTStep> = emptyList()
)

data class GoTStep(
    val nodeId: String,
    val type: StepType,
    val timestamp: Long,
    val inputs: Map<String, Any> = emptyMap(),
    val outputs: Map<String, Any> = emptyMap(),
    val metadata: Map<String, Any> = emptyMap()
)

enum class StepType {
    REASON,       // Pure reasoning
    ACTION,       // Tool execution
    EVALUATION,   // Assessment
    DECISION,     // Choosing between options
    COMBINATION   // Combining multiple nodes
}
```

---

## GoT Pattern Implementation

### 1. Initialize Graph

```kotlin
class GoTGraphBuilder {
    private val nodes = mutableMapOf<String, GoTNode>()
    private val relationships = mutableListOf<NodeRelationship>()

    fun addNode(
        id: String,
        content: String,
        type: NodeType = NodeType.DECISION,
        dependencies: List<String> = emptyList()
    ): GoTGraphBuilder {
        nodes[id] = GoTNode(
            id = id,
            content = content,
            type = type,
            dependencies = dependencies,
            relationships = emptyList()
        )
        return this
    }

    fun addRelationship(
        from: String,
        to: String,
        type: RelationshipType = RelationshipType.CAUSE,
        strength: Double = 0.5
    ): GoTGraphBuilder {
        relationships.add(NodeRelationship(
            type = type,
            strength = strength,
            direction = RelationshipDirection.OUTGOING,
            metadata = mapOf("from" to from, "to" to to)
        ))
        return this
    }

    fun build(): GoTGraph {
        return GoTGraph(
            nodes = nodes,
            relationships = relationships
        )
    }
}

// Usage
val graph = GoTGraphBuilder()
    .addNode("n1", "Choose database technology")
    .addNode("n2", "Use PostgreSQL for structured data")
    .addNode("n3", "Use Redis for caching")
    .addNode("n4", "PostgreSQL is scalable")
    .addNode("n5", "Redis is fast for cache")
    .addRelationship("n1", "n2", RelationshipType.CAUSE, 0.9)
    .addRelationship("n1", "n3", RelationshipType.CAUSE, 0.8)
    .addRelationship("n2", "n4", RelationshipType.SUPPORTS, 0.9)
    .addRelationship("n3", "n5", RelationshipType.SUPPORTS, 0.9)
    .build()
```

### 2. Reason Through Graph

```kotlin
class GoTReasoner {
    private val graph: GoTGraph

    suspend fun reason(
        startNodeId: String,
        config: GoTConfig = GoTConfig()
    ): GoTResult {
        val startTime = System.currentTimeMillis()

        // Initialize with start node
        val queue = PriorityQueue<GoTNode>(
            compareBy { it.dependencies.size }
        )
        queue.add(graph.nodes[startNodeId]!!)

        val resolvedNodes = mutableSetOf<String>()
        val evaluations = mutableListOf<GoTEvaluation>()
        val decisions = mutableListOf<GoTDecision>()

        while (queue.isNotEmpty()) {
            val node = queue.poll()

            // Skip if already resolved or evaluating
            if (node.status in listOf(NodeStatus.RESOLVED, NodeStatus.EVALUATING)) {
                continue
            }

            // Check dependencies
            val missingDeps = node.dependencies.filter { dep ->
                !resolvedNodes.contains(dep)
            }

            if (missingDeps.isNotEmpty()) {
                queue.add(node)
                continue
            }

            // Evaluate node
            val evaluation = evaluateNode(node)

            if (evaluation.status == NodeStatus.RESOLVED) {
                resolvedNodes.add(node.id)
                decisions.add(evaluation.decision)

                // Add dependent nodes to queue
                val dependents = findDependents(node.id)
                queue.addAll(dependents)
            }

            evaluations.add(evaluation)
        }

        return GoTResult(
            graph = graph,
            evaluations = evaluations,
            decisions = decisions,
            timeElapsedMs = System.currentTimeMillis() - startTime,
            status = resolveFinalStatus(evaluations)
        )
    }

    private suspend fun evaluateNode(node: GoTNode): GoTEvaluation {
        return when (node.type) {
            NodeType.DECISION -> evaluateDecision(node)
            NodeType.FACT -> resolveFact(node)
            NodeType.ACTION -> resolveAction(node)
            NodeType.CONSTRAINT -> resolveConstraint(node)
            NodeType.EVALUATION -> evaluateAnotherNode(node)
            NodeType.QUESTION -> answerQuestion(node)
        }
    }

    private suspend fun evaluateDecision(node: GoTNode): GoTEvaluation {
        // Determine which decision to make
        val options = node.content.split("|").map { it.trim() }
        val selected = selectBestOption(node, options)

        return GoTEvaluation(
            nodeId = node.id,
            status = NodeStatus.RESOLVED,
            decision = GoTDecision(
                nodeId = node.id,
                decision = selected,
                confidence = calculateConfidence(node)
            )
        )
    }

    private suspend fun selectBestOption(node: GoTNode, options: List<String>): String {
        // Evaluate each option using connected nodes
        val scores = options.map { option ->
            val score = calculateScore(node, option)
            option to score
        }

        return scores.maxByOrNull { it.second }?.first
            ?: options.first()
    }

    private suspend fun resolveFact(node: GoTNode): GoTEvaluation {
        // Facts are true by definition or verified
        return GoTEvaluation(
            nodeId = node.id,
            status = NodeStatus.RESOLVED,
            decision = GoTDecision(
                nodeId = node.id,
                decision = "True",
                confidence = 1.0
            )
        )
    }

    private suspend fun resolveAction(node: GoTNode): GoTEvaluation {
        // Execute action
        val result = executeNodeAction(node)

        return GoTEvaluation(
            nodeId = node.id,
            status = NodeStatus.RESOLVED,
            decision = GoTDecision(
                nodeId = node.id,
                decision = "Action completed: ${result}",
                confidence = 0.95
            )
        )
    }

    private suspend fun resolveConstraint(node: GoTNode): GoTEvaluation {
        // Check if constraints are satisfied
        val satisfied = checkConstraint(node.content)

        return GoTEvaluation(
            nodeId = node.id,
            status = if (satisfied) NodeStatus.RESOLVED else NodeStatus.CONFLICTED,
            decision = GoTDecision(
                nodeId = node.id,
                decision = if (satisfied) "Constraint satisfied" else "Constraint violated",
                confidence = if (satisfied) 1.0 else 0.5
            )
        )
    }

    private suspend fun findDependents(nodeId: String): List<GoTNode> {
        return graph.nodes.values.filter { node ->
            node.dependencies.contains(nodeId)
        }
    }
}

data class GoTEvaluation(
    val nodeId: String,
    val status: NodeStatus,
    val decision: GoTDecision,
    val timestamp: Long = System.currentTimeMillis()
)

data class GoTDecision(
    val nodeId: String,
    val decision: String,
    val confidence: Double,
    val rationale: String = ""
)
```

### 3. Handle Cycles

```kotlin
class CycleDetector {
    private val visited = mutableSetOf<String>()
    private val inStack = mutableSetOf<String>()

    fun hasCycle(graph: GoTGraph): Boolean {
        return graph.nodes.keys.any { nodeId ->
            if (visited.contains(nodeId)) return false
            return hasCycleInComponent(nodeId, graph)
        }
    }

    private fun hasCycleInComponent(
        nodeId: String,
        graph: GoTGraph,
        depth: Int = 0
    ): Boolean {
        if (depth > 100) return true // Prevent infinite recursion

        visited.add(nodeId)
        inStack.add(nodeId)

        val node = graph.nodes[nodeId] ?: return false

        // Check dependencies (incoming edges)
        val dependencies = node.dependencies
        for (depId in dependencies) {
            if (inStack.contains(depId)) {
                return true
            }
            if (!visited.contains(depId) && hasCycleInComponent(depId, graph, depth + 1)) {
                return true
            }
        }

        // Check outgoing relationships
        for (rel in node.relationships) {
            if (rel.direction == RelationshipDirection.INCOMING) {
                val fromId = rel.metadata["from"] as? String ?: continue
                if (inStack.contains(fromId)) {
                    return true
                }
                if (!visited.contains(fromId) && hasCycleInComponent(fromId, graph, depth + 1)) {
                    return true
                }
            }
        }

        inStack.remove(nodeId)
        return false
    }

    fun detectConflicts(
        graph: GoTGraph,
        evaluation: GoTEvaluation
    ): List<Conflict> {
        val conflicts = mutableListOf<Conflict>()

        val node = graph.nodes[evaluation.nodeId] ?: return conflicts

        // Find conflicting nodes
        for (otherNode in graph.nodes.values) {
            if (otherNode.id == evaluation.nodeId) continue

            val conflict = checkConflict(node, otherNode)
            if (conflict != null) {
                conflicts.add(conflict)
            }
        }

        return conflicts
    }

    private fun checkConflict(
        node1: GoTNode,
        node2: GoTNode
    ): Conflict? {
        for (rel in node1.relationships) {
            for (otherRel in node2.relationships) {
                if (rel.type == RelationshipType.CONTRADICTION &&
                    otherRel.type == RelationshipType.CONTRADICTION) {
                    return Conflict(
                        nodes = listOf(node1.id, node2.id),
                        relationship = rel,
                        otherRelationship = otherRel
                    )
                }
            }
        }
        return null
    }
}

data class Conflict(
    val nodes: List<String>,
    val relationship: NodeRelationship,
    val otherRelationship: NodeRelationship
)
```

### 4. Parallel Execution

```kotlin
class ParallelGoTExecutor {
    suspend fun reasonParallel(
        graph: GoTGraph,
        startNodeIds: List<String>,
        maxWorkers: Int = 5
    ): GoTResult {
        val semaphore = Semaphore(maxWorkers)
        val results = mutableMapOf<String, GoTEvaluation>()
        val lock = Mutex()

        val startTime = System.currentTimeMillis()

        suspend fun processNode(nodeId: String) {
            semaphore.withPermit {
                try {
                    val node = graph.nodes[nodeId] ?: return@withPermit
                    val evaluation = evaluateNode(node)
                    lock.withLock {
                        results[nodeId] = evaluation
                    }
                } catch (e: Exception) {
                    lock.withLock {
                        results[nodeId] = GoTEvaluation(
                            nodeId = nodeId,
                            status = NodeStatus.INVALID,
                            decision = GoTDecision(
                                nodeId = nodeId,
                                decision = "Error: ${e.message}",
                                confidence = 0.0
                            )
                        )
                    }
                }
            }
        }

        // Process all starting nodes in parallel
        startNodeIds.forEach { processNode(it) }

        // Wait for all to complete
        while (results.size < startNodeIds.size) {
            delay(100)
        }

        return GoTResult(
            graph = graph,
            evaluations = results.values.toList(),
            decisions = results.values
                .filter { it.status == NodeStatus.RESOLVED }
                .map { it.decision },
            timeElapsedMs = System.currentTimeMillis() - startTime,
            status = resolveFinalStatus(results.values)
        )
    }
}
```

---

## Integration Examples

### Example 1: System Architecture Decision

```kotlin
suspend fun decideSystemArchitecture(): ArchitectureDecision {
    val graph = GoTGraphBuilder()
        .addNode("arch-decision", "Choose system architecture")
        .addNode("monolith", "Use monolithic architecture")
        .addNode("microservices", "Use microservices")
        .addNode("modular-monolith", "Use modular monolith")
        .addNode("scale", "Needs to scale to 1M users")
        .addNode("team-size", "Team has 5 developers")
        .addNode("time", "Release in 3 months")
        .addRelationship("arch-decision", "monolith", RelationshipType.CAUSE, 0.7)
        .addRelationship("arch-decision", "microservices", RelationshipType.CAUSE, 0.9)
        .addRelationship("arch-decision", "modular-monolith", RelationshipType.CAUSE, 0.8)
        .addRelationship("scale", "microservices", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("scale", "modular-monolith", RelationshipType.SUPPORTS, 0.7)
        .addRelationship("team-size", "monolith", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("team-size", "modular-monolith", RelationshipType.SUPPORTS, 0.8)
        .addRelationship("time", "microservices", RelationshipType.CONFLICTS, 0.9)
        .addRelationship("time", "monolith", RelationshipType.SUPPORTS, 0.8)
        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("arch-decision")

    return ArchitectureDecision(
        architecture = result.decisions.firstOrNull()?.decision ?: "Unknown",
        evaluations = result.evaluations,
        timeElapsedMs = result.timeElapsedMs,
        conflicts = detectConflicts(graph, result.evaluations)
    )
}
```

### Example 2: Feature Implementation Plan

```kotlin
data class FeaturePlan(
    val featureName: String,
    val graph: GoTGraph,
    val result: GoTResult
)

suspend fun createFeaturePlan(feature: String): FeaturePlan {
    val graph = GoTGraphBuilder()
        // Root decision
        .addNode("plan", "Create implementation plan for $feature")

        // Options
        .addNode("option1", "Fast but limited: MVP approach")
        .addNode("option2", "Balanced: Standard implementation")
        .addNode("option3", "Comprehensive: Full-featured approach")

        // Constraints
        .addNode("requirement1", "Must have core functionality")
        .addNode("requirement2", "Must be maintainable")
        .addNode("requirement3", "Must be secure")

        // Evaluate options
        .addNode("eval1", "MVP meets requirement1")
        .addNode("eval2", "MVP fails requirement2")
        .addNode("eval3", "Standard meets all requirements")
        .addNode("eval4", "Standard fails requirement3")

        // Relationships
        .addRelationship("plan", "option1", RelationshipType.CAUSE, 0.8)
        .addRelationship("plan", "option2", RelationshipType.CAUSE, 0.9)
        .addRelationship("plan", "option3", RelationshipType.CAUSE, 0.7)
        .addRelationship("requirement1", "eval1", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("requirement2", "eval2", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("requirement3", "eval3", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("requirement3", "eval4", RelationshipType.CONTRADICTION, 0.95)

        .build()

    val executor = ParallelGoTExecutor()
    val result = executor.reasonParallel(graph, listOf("plan"))

    return FeaturePlan(feature, graph, result)
}
```

### Example 3: Debugging Multi-layered Issues

```kotlin
suspend fun debugPerformanceIssue(): DebugSolution {
    val graph = GoTGraphBuilder()
        .addNode("debug", "Debug performance degradation")

        // Potential causes
        .addNode("cause1", "Database query optimization")
        .addNode("cause2", "Memory leak in Java code")
        .addNode("cause3", "Network latency to external API")
        .addNode("cause4", "Caching misconfiguration")

        // Symptoms
        .addNode("symptom1", "Slow query times")
        .addNode("symptom2", "High memory usage")
        .addNode("symptom3", "Increased latency")

        // Analysis
        .addNode("analysis1", "Query time increased by 200%")
        .addNode("analysis2", "Heap dump shows object retention")
        .addNode("analysis3", "Response time matches network RTT")

        // Relationships
        .addRelationship("debug", "cause1", RelationshipType.CAUSE, 0.7)
        .addRelationship("debug", "cause2", RelationshipType.CAUSE, 0.8)
        .addRelationship("debug", "cause3", RelationshipType.CAUSE, 0.6)
        .addRelationship("debug", "cause4", RelationshipType.CAUSE, 0.5)

        .addRelationship("symptom1", "analysis1", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("symptom2", "analysis2", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("symptom3", "analysis3", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("cause1", "analysis1", RelationshipType.CONTRADICTION, 0.8)
        .addRelationship("cause2", "analysis2", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("cause3", "analysis3", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("cause4", "analysis3", RelationshipType.CONTRADICTION, 0.7)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("debug")

    // Find root cause
    val rootCause = result.decisions.firstOrNull()

    return DebugSolution(
        diagnosis = rootCause?.decision ?: "Unknown",
        evaluations = result.evaluations,
        graph = graph
    )
}
```

---

## GoT vs ToT Comparison

### ToT Example (Tree)

```
Root: Choose architecture
├── Branch 1: Monolith
│   ├── Sub-branch 1.1: Low complexity
│   │   ├── Pro: Easy to deploy
│   │   └── Con: Limited scaling
│   └── Sub-branch 1.2: High effort
│       ├── Pro: Simple
│       └── Con: Difficult to modify
└── Branch 2: Microservices
    ├── Sub-branch 2.1: High complexity
    │   ├── Pro: Scalable
    │   └── Con: Hard to deploy
    └── Sub-branch 2.2: High effort
        ├── Pro: Resilient
        └── Con: Difficult to test
```

### GoT Example (Graph)

```
                    Root: Choose architecture
                      /      |      \
        Monolith      Microservices  Modular
             |             |             |
     Simple   Scalable    Complicated   Balanced
        \         |         /       /
         \        |        /       /
      [Trade-offs form network]
```

**Key Difference:** In GoT, you can have multiple paths leading to the same decision point, and decisions can influence each other through relationships.

---

## Best Practices

### 1. Graph Design

```
✓ Start with root decision and main options
✓ Identify constraints and dependencies
✓ Add relationships to show influence
✓ Keep graph size manageable (50-100 nodes)
✓ Use clear node names
```

### 2. Node Types

```
✓ DECISION: Main choices to make
✓ FACT: Established truths
✓ ACTION: Steps to execute
✓ CONSTRAINT: Boundaries to respect
✓ EVALUATION: Assessing another node
```

### 3. Relationship Strength

```
✓ Strong (0.7-1.0): Clear cause-effect
✓ Medium (0.4-0.7): Weak correlation
✓ Weak (<0.4): Just a connection
```

### 4. Cycle Handling

```
✓ Detect cycles early
✓ Use cycle detection algorithms
✓ Resolve conflicts if found
✓ Document cycles for review
```

---

## Performance Considerations

### Optimization

```kotlin
class GoTOptimizer {
    // Remove redundant nodes
    fun removeRedundantNodes(graph: GoTGraph): GoTGraph {
        val newNodes = mutableMapOf<String, GoTNode>()
        val newRelationships = mutableListOf<NodeRelationship>()

        // Keep nodes that are dependencies of others
        val nodesWithDependencies = graph.nodes.values
            .flatMap { it.dependencies }
            .toSet()

        graph.nodes.values.forEach { node ->
            if (nodesWithDependencies.contains(node.id)) {
                newNodes[node.id] = node
                newRelationships.addAll(node.relationships)
            }
        }

        return GoTGraph(
            nodes = newNodes,
            relationships = newRelationships
        )
    }

    // Prune weak connections
    fun pruneWeakConnections(graph: GoTGraph, threshold: Double = 0.3): GoTGraph {
        val prunedRelationships = graph.relationships
            .filter { it.strength >= threshold }

        val prunedNodes = graph.nodes.values
            .filter { node ->
                node.relationships.any { rel ->
                    prunedRelationships.contains(rel)
                } || node.dependencies.isEmpty()
            }
            .associateBy { it.id }

        return GoTGraph(
            nodes = prunedNodes,
            relationships = prunedRelationships
        )
    }
}
```

---

## Integration with Other Patterns

### GoT + ReAct

```kotlin
class ReActGoTAgent {
    suspend fun solveTask(task: String): String {
        // Use GoT to decompose and reason about task
        val graph = buildGoTGraph(task)
        val result = GoTReasoner().reason(graph)

        // Use ReAct to execute decisions
        val reActAgent = ReActAgent()

        result.decisions.forEach { decision ->
            val action = buildReActAction(decision)
            reActAgent.execute(action)
        }

        return "Task completed successfully"
    }
}
```

### GoT + MCP

```kotlin
class MCPPatternGoTAgent {
    suspend fun queryWithMCP(query: String): Result {
        // Build GoT graph for query
        val graph = buildGoTGraphForQuery(query)

        // Use MCP to retrieve context
        val mcpProvider = McpContextProvider()
        val context = mcpProvider.getContextForSession(currentSessionId)

        // Reason through graph
        val result = GoTReasoner().reason(graph)

        return Result(
            query = query,
            graph = graph,
            evaluations = result.evaluations,
            context = context
        )
    }
}
```

---

## Visualizing GoT

### Mermaid Diagram

```kotlin
fun visualizeGoT(graph: GoTGraph): String {
    val lines = mutableListOf("graph TD")

    // Add nodes
    graph.nodes.values.forEach { node ->
        val style = when (node.status) {
            NodeStatus.PENDING -> "style ${node.id} fill:#f9f9f9,stroke:#333,stroke-width:1px"
            NodeStatus.RESOLVED -> "style ${node.id} fill:#52c41a,stroke:#389e0d"
            NodeStatus.CONFLICTED -> "style ${node.id} fill:#ff4d4f,stroke:#cf1322"
            NodeStatus.INVALID -> "style ${node.id} fill:#faad14,stroke:#d48806"
            else -> "style ${node.id} fill:#d9d9d9,stroke:#595959"
        }
        lines.add(style)
        lines.add("${node.id}[${node.content}]")
    }

    // Add relationships
    graph.relationships.forEach { rel ->
        val line = when (rel.type) {
            RelationshipType.CAUSE -> "    ${rel.metadata["from"]} --> ${rel.metadata["to"]}"
            RelationshipType.CONTRADICTION -> "    ${rel.metadata["from"]} -.-> ${rel.metadata["to"]}"
            RelationshipType.SUPPORTS -> "    ${rel.metadata["from"]} ==> ${rel.metadata["to"]}"
            else -> "    ${rel.metadata["from"]} --> ${rel.metadata["to"]}"
        }
        lines.add(line)
    }

    return lines.joinToString("\n")
}

// Usage
val diagram = visualizeGoT(graph)
// Output: Mermaid diagram as string
```

---

## Common Use Cases

### Use Case 1: Complex Decision Making

```kotlin
class ComplexDecisionGoT {
    suspend fun decideTechnologyStack(): TechnologyDecision {
        val graph = GoTGraphBuilder()
            .addNode("decision", "Choose technology stack")
            .addNode("backend", "Choose backend framework")
            .addNode("frontend", "Choose frontend framework")
            .addNode("database", "Choose database")
            .addNode("storage", "Choose storage")
            .addNode("requirements", "Project requirements")
            .addNode("team", "Team expertise")
            .addNode("time", "Timeline")
            .addRelationship("decision", "backend", RelationshipType.CAUSE, 0.9)
            .addRelationship("decision", "frontend", RelationshipType.CAUSE, 0.9)
            .addRelationship("backend", "database", RelationshipType.CAUSE, 0.9)
            .addRelationship("requirements", "backend", RelationshipType.SUPPORTS, 0.9)
            .addRelationship("team", "backend", RelationshipType.SUPPORTS, 0.8)
            .addRelationship("time", "backend", RelationshipType.CONFLICTS, 0.7)
            .build()

        val reasoner = GoTReasoner()
        val result = reasoner.reason("decision")

        return TechnologyDecision(
            backend = result.decisions.find { it.nodeId == "backend" }?.decision ?: "",
            frontend = result.decisions.find { it.nodeId == "frontend" }?.decision ?: "",
            database = result.decisions.find { it.nodeId == "database" }?.decision ?: "",
            evaluations = result.evaluations
        )
    }
}
```

### Use Case 2: Product Roadmap Planning

```kotlin
class RoadmapGoT {
    suspend fun planRoadmap(): RoadmapPlan {
        val graph = GoTGraphBuilder()
            .addNode("roadmap", "Create product roadmap")
            .addNode("feature1", "Implement core feature")
            .addNode("feature2", "Add authentication")
            .addNode("feature3", "Optimize performance")
            .addNode("feedback", "User feedback")
            .addNode("market", "Market analysis")
            .addRelationship("roadmap", "feature1", RelationshipType.CAUSE, 0.8)
            .addRelationship("roadmap", "feature2", RelationshipType.CAUSE, 0.9)
            .addRelationship("roadmap", "feature3", RelationshipType.CAUSE, 0.7)
            .addRelationship("feedback", "feature2", RelationshipType.SUPPORTS, 0.9)
            .addRelationship("market", "feature1", RelationshipType.SUPPORTS, 0.8)
            .build()

        val executor = ParallelGoTExecutor()
        val result = executor.reasonParallel(graph, listOf("roadmap"))

        return RoadmapPlan(
            features = result.decisions,
            evaluations = result.evaluations
        )
    }
}
```

---

## Troubleshooting

### Problem: Too many cycles

**Solution:**
```kotlin
// Detect and break cycles
val detector = CycleDetector()
if (detector.hasCycle(graph)) {
    val conflicts = detector.detectConflicts(graph, evaluations)
    // Resolve conflicts by removing conflicting nodes or relationships
}
```

### Problem: Poor decision quality

**Solution:**
```kotlin
// Improve relationship strengths
val optimizer = GoTOptimizer()
val pruned = optimizer.pruneWeakConnections(graph, threshold = 0.5)
val newGraph = optimizer.removeRedundantNodes(pruned)
```

### Problem: Slow performance

**Solution:**
```kotlin
// Use parallel execution for independent nodes
val executor = ParallelGoTExecutor(maxWorkers = 10)
val result = executor.reasonParallel(graph, startNodeIds, maxWorkers = 10)
```

---

## Summary

**Graph-of-Thoughts (GoT)** enables:
- **Multi-hop reasoning** with interconnected decisions
- **Parallel exploration** of multiple branches
- **Cycle handling** for complex dependencies
- **Rich relationships** with strength and direction
- **Visual representation** of reasoning networks

GoT complements Tree-of-Thoughts by providing more flexibility for complex, interconnected decision-making scenarios where decisions influence each other in non-linear ways.

---

*Version: 1.0.0 | Category: agent-patterns | Tags: graph, reasoning, network, multi-hop, orchestration*
