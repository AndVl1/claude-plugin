# Graph-of-Thoughts (GoT) Pattern

**Graph-of-Thoughts** extends Tree-of-Thoughts with graph-based structure, enabling multi-hop reasoning, parallel branches, and interconnected decisions.

## 🎯 Key Concepts

- **Graph Structure**: Network of nodes with multi-parent/multi-child relationships
- **Cycle Handling**: Supports cycles and complex dependencies
- **Parallel Execution**: Execute independent nodes concurrently
- **Relationship Types**: Cause, effect, contradiction, support, dependency
- **Strength Values**: 0.0-1.0 for relationship confidence

## 📊 GoT vs ToT

| Aspect | Tree-of-Thoughts | Graph-of-Thoughts |
|--------|------------------|-------------------|
| Structure | Hierarchical tree | Networked graph |
| Flow | Single parent → children | Multi-parent, multi-child |
| Cycles | No | Yes |
| Parallel | Sequential | Parallel execution |
| Use Case | Linear paths | Complex interdependent decisions |

## 🔧 Components

### GoTNode
```kotlin
data class GoTNode(
    val id: String,
    val content: String,
    val type: NodeType,         // DECISION, FACT, ACTION, QUESTION, CONSTRAINT, EVALUATION
    val status: NodeStatus,     // PENDING, EVALUATING, RESOLVED, CONFLICTED, CYCLIC, INVALID
    val dependencies: List<String>,  // Parent node IDs
    val relationships: List<NodeRelationship>,
    val metadata: Map<String, Any>
)
```

### NodeRelationship
```kotlin
data class NodeRelationship(
    val type: RelationshipType,  // CAUSE, EFFECT, CONTRADICTION, SUPPORTS, DEPENDS_ON, EQUIVALENT, CONDITION
    val strength: Double,        // 0.0-1.0
    val direction: RelationshipDirection  // OUTGOING, INCOMING, BOTH
)
```

## 🚀 Quick Start

### Basic Graph

```kotlin
val graph = GoTGraphBuilder()
    .addNode("root", "Choose database technology")
    .addNode("postgresql", "Use PostgreSQL")
    .addNode("redis", "Use Redis")
    .addNode("postgres-adv", "PostgreSQL is scalable")
    .addNode("redis-adv", "Redis is fast for cache")
    .addRelationship("root", "postgresql", RelationshipType.CAUSE, 0.9)
    .addRelationship("root", "redis", RelationshipType.CAUSE, 0.8)
    .addRelationship("postgresql", "postgres-adv", RelationshipType.SUPPORTS, 0.9)
    .addRelationship("redis", "redis-adv", RelationshipType.SUPPORTS, 0.9)
    .build()
```

### Reasoning

```kotlin
val reasoner = GoTReasoner()
val result = reasoner.reason("root")
// result.decisions contains selected option(s)
```

### Parallel Execution

```kotlin
val executor = ParallelGoTExecutor(maxWorkers = 5)
val result = executor.reasonParallel(graph, listOf("root"))
```

## 📁 File Structure

```
graph-of-thoughts/
├── SKILL.md              # Full skill documentation
├── README.md            # This file
└── EXAMPLES.md          # Usage examples (in parent)
```

## 🎯 When to Use

- **Multi-hop reasoning** across multiple decision points
- **Complex interdependent decisions** where choices affect each other
- **Parallel exploration** of multiple independent branches
- **Debugging layered issues** (e.g., database → application → network)
- **System architecture design** with interconnected components
- **Product roadmap planning** with interdependent features
- **Technology stack selection** with trade-offs

## 🔗 Integration with Other Patterns

### GoT + ReAct

```kotlin
// Use GoT to decompose, ReAct to execute
val graph = buildGoTGraph(task)
val decisions = reasonGraph(graph)
decisions.forEach { executeWithReAct(it) }
```

### GoT + MCP

```kotlin
// Use GoT for reasoning, MCP for context
val graph = buildGoTGraph(query)
val context = mcpProvider.getContextForSession(sessionId)
val result = reasonWithContext(graph, context)
```

### GoT + Self-Correction

```kotlin
// Use GoT for reasoning, SC-ToT for self-correction
val graph = buildGoTGraph(problem)
val scTot = SelfCorrectingToT()
val result = scTot.makeDecisionWithMemory(problem, context, graph)
```

## 📚 Related Skills

- **tree-of-thoughts**: Hierarchical tree decision patterns
- **react-pattern**: Reasoning + Acting cycle
- **self-correcting-tot**: Self-correction loops with memory
- **mcp-patterns**: Model Context Protocol patterns
- **rag-memory**: Retrieval-Augmented Generation memory
- **iterative-refinement**: Ralph Loop pattern
- **tool-orchestration**: Beads pattern for tool chains

## 💡 Use Cases

### 1. Architecture Decision

```kotlin
suspend fun decideArchitecture(): ArchitectureDecision {
    val graph = GoTGraphBuilder()
        .addNode("decision", "Choose architecture")
        .addNode("monolith", "Monolithic")
        .addNode("microservices", "Microservices")
        .addNode("modular-monolith", "Modular Monolith")
        .addNode("scale", "Needs 1M users")
        .addNode("team", "5 developers")
        .addRelationship("decision", "monolith", RelationshipType.CAUSE, 0.7)
        .addRelationship("decision", "microservices", RelationshipType.CAUSE, 0.9)
        .addRelationship("scale", "microservices", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("team", "monolith", RelationshipType.SUPPORTS, 0.9)
        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("decision")

    return ArchitectureDecision(result.decisions.first().decision, result.evaluations)
}
```

### 2. Debugging Performance Issues

```kotlin
suspend fun debugPerformance(): DebugSolution {
    val graph = GoTGraphBuilder()
        .addNode("debug", "Debug performance degradation")
        .addNode("db", "Database query optimization")
        .addNode("memory", "Memory leak")
        .addNode("network", "Network latency")
        .addNode("cache", "Caching misconfiguration")
        .addNode("symptom1", "Slow query times")
        .addNode("symptom2", "High memory usage")
        .addRelationship("debug", "db", RelationshipType.CAUSE, 0.7)
        .addRelationship("debug", "memory", RelationshipType.CAUSE, 0.8)
        .addRelationship("debug", "network", RelationshipType.CAUSE, 0.6)
        .addRelationship("symptom1", "db", RelationshipType.CONTRADICTION, 0.8)
        .addRelationship("symptom2", "memory", RelationshipType.SUPPORTS, 0.9)
        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("debug")

    return DebugSolution(result.decisions.first().decision, result.evaluations)
}
```

## 📈 Performance

- **Time Complexity**: O(V + E) for graph traversal
- **Space Complexity**: O(V + E) for graph storage
- **Parallel Execution**: Up to maxWorkers concurrent nodes
- **Typical Graph Size**: 50-100 nodes recommended

## 🔍 Visualizing GoT

```kotlin
fun visualizeGoT(graph: GoTGraph): String {
    // Returns Mermaid diagram string
}
```

Output:
```
graph TD
    root[Choose architecture]
    root --> monolith
    root --> microservices
    monolith --> pros[Simple]
    microservices --> pros2[Scalable]
```

## 🛠️ Tools

- **GoTGraphBuilder**: Build graphs programmatically
- **GoTReasoner**: Sequential reasoning through graph
- **ParallelGoTExecutor**: Parallel node execution
- **CycleDetector**: Detect and handle cycles
- **GoTOptimizer**: Prune and optimize graphs

## ⚠️ Best Practices

1. **Keep graph size manageable** (50-100 nodes)
2. **Use clear node names** with descriptive content
3. **Set appropriate relationship strengths** (0.7-1.0 for strong)
4. **Detect and resolve cycles** before reasoning
5. **Use parallel execution** for independent branches
6. **Visualize results** with Mermaid diagrams

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Too many cycles | Use CycleDetector, resolve conflicts |
| Poor decision quality | Prune weak connections (threshold > 0.5) |
| Slow performance | Use ParallelGoTExecutor with maxWorkers |
| Inconsistent results | Increase relationship strength thresholds |

## 📖 Further Reading

- [Tree-of-Thoughts (ToT)](./tree-of-thoughts/) - Hierarchical tree patterns
- [ReAct Pattern](./react-pattern/) - Reasoning + Acting cycle
- [Self-Correcting ToT](./tree-of-thoughts/SELF-CORRECTING-TOT.md) - Memory integration
- [MCP Patterns](./mcp-patterns/) - Context management

---

*Version: 1.0.0 | Last Updated: 2026-04-28*
