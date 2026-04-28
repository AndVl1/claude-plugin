# Claude Plugin Skill Integration Examples

This directory contains examples demonstrating integration between different skills in the claude-plugin.

## Integration Examples

### 1. GoT + ReAct Integration

**Context:** Use GoT for planning complex multi-step tasks, then use ReAct for execution.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + [react-pattern](../react-pattern/)

**Implementation:**
```kotlin
class GoTReActIntegration {
    private val goTBuilder = GoTGraphBuilder()
    private val reActAgent = ReActAgent()

    suspend fun executeComplexTask(task: String): TaskResult {
        // Step 1: Use GoT to plan
        val graph = buildGoTGraphForTask(task)
        val planResult = GoTReasoner().reason(graph)

        // Step 2: Use ReAct to execute decisions
        val executed = mutableListOf<String>()
        planResult.decisions.forEach { decision ->
            val reActAction = buildReActFromDecision(decision)
            val reActResult = reActAgent.execute(reActAction)
            executed.add(decision.decision)
        }

        return TaskResult(
            success = true,
            executedDecisions = executed,
            plan = graph
        )
    }
}
```

**Benefits:**
- GoT provides structured planning and multi-hop reasoning
- ReAct handles step-by-step execution with observations
- Combines planning power with execution capability

**See Also:** [graph-of-thoughts/EXAMPLES.md#example-7](../graph-of-thoughts/EXAMPLES.md#example-7)

---

### 2. GoT + Self-Correcting ToT

**Context:** Use GoT for complex planning, then apply self-correction loops for quality assurance.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + [tree-of-thoughts/SELF-CORRECTING-TOT.md](../tree-of-thoughts/SELF-CORRECTING-TOT.md)

**Implementation:**
```kotlin
class GoTSCToTIntegration {
    private val goTGraph = GoTGraphBuilder()
    private val scTot = SelfCorrectingToT()

    suspend fun makeDecisionWithGoTAndCorrection(
        problem: String,
        context: Map<String, Any>
    ): DecisionResult {
        // Step 1: Build GoT graph for problem
        val graph = buildComplexGraph(problem)
        val reasoner = GoTReasoner()
        val result = reasoner.reason(graph)

        // Step 2: Apply self-correction loops
        val correctedResult = scTot.makeDecisionWithMemory(
            problem = problem,
            context = context,
            maxIterations = 3
        )

        return DecisionResult(
            originalDecision = result.decisions.first(),
            correctedDecision = correctedResult.finalBranch,
            correctionsApplied = correctedResult.iterations - 1,
            evaluations = result.evaluations
        )
    }
}
```

**Benefits:**
- GoT handles complex multi-hop reasoning
- Self-correction ensures quality and catches errors
- Memory integration learns from outcomes

**See Also:** [tree-of-thoughts/SELF-CORRECTING-TOT.md](../tree-of-thoughts/SELF-CORRECTING-TOT.md)

---

### 3. GoT + MCP Integration

**Context:** Use GoT for reasoning, MCP for context management across sessions.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + [mcp-patterns](../mcp-patterns/)

**Implementation:**
```kotlin
class GoTMCPIntegration {
    private val goTReasoner = GoTReasoner()
    private val mcpContextProvider = McpContextProvider()

    suspend fun queryWithMCPContext(
        sessionId: String,
        query: String
    ): QueryResult {
        // Step 1: Load MCP context for session
        val context = mcpContextProvider.getContextForSession(sessionId)

        // Step 2: Build GoT graph with MCP context
        val graph = buildGoTGraphWithContext(query, context)

        // Step 3: Reason through graph
        val result = goTReasoner.reason(graph)

        // Step 4: Update MCP context with results
        mcpContextProvider.updateContext(
            sessionId,
            ContextUpdate.UpdateDecision(
                decision = result.decisions.first().decision,
                timestamp = System.currentTimeMillis()
            )
        )

        return QueryResult(
            query = query,
            graph = graph,
            decisions = result.decisions,
            context = context
        )
    }
}
```

**Benefits:**
- MCP provides persistent session context
- GoT uses context for informed reasoning
- Cross-session knowledge persistence

**See Also:** [mcp-patterns/SKILL.md#mcp-pattern-context-provider](../mcp-patterns/SKILL.md#mcp-pattern-context-provider)

---

### 4. GoT + RAG Memory

**Context:** Use GoT for complex reasoning, RAG for retrieval of relevant information.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + [rag-memory](../rag-memory/)

**Implementation:**
```kotlin
class GoTRAGIntegration {
    private val goTReasoner = GoTReasoner()
    private val ragSystem = RAGMemorySystem()

    suspend fun reasonWithRAG(
        query: String,
        memoryPartition: String
    ): ReasoningResult {
        // Step 1: Retrieve relevant memory using RAG
        val retrievedDocs = ragSystem.retrieve(
            query = query,
            partition = memoryPartition,
            k = 5
        )

        // Step 2: Build GoT graph with retrieved context
        val graph = buildGoTGraphWithContext(query, retrievedDocs)

        // Step 3: Reason through graph
        val result = goTReasoner.reason(graph)

        // Step 4: Store result in RAG for future retrieval
        ragSystem.store(
            content = result.decisions.first().decision,
            partition = memoryPartition,
            metadata = mapOf(
                "query" to query,
                "timestamp" to System.currentTimeMillis(),
                "evaluationCount" to result.evaluations.size
            )
        )

        return ReasoningResult(
            query = query,
            retrievedDocs = retrievedDocs,
            decisions = result.decisions,
            evaluations = result.evaluations
        )
    }
}
```

**Benefits:**
- RAG provides relevant context for reasoning
- GoT uses context to make informed decisions
- Results stored for future retrieval

**See Also:** [rag-memory/SKILL.md](../rag-memory/SKILL.md)

---

### 5. GoT + Iterative Refinement

**Context:** Use GoT for initial planning, then apply iterative refinement for quality improvement.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + [iterative-refinement](../iterative-refinement/)

**Implementation:**
```kotlin
class GoTRefinementIntegration {
    private val goTGraphBuilder = GoTGraphBuilder()
    private val refinementEngine = IterativeRefinementEngine()

    suspend fun refineDecision(
        problem: String,
    ): RefinedResult {
        // Step 1: Create initial GoT graph
        val graph = goTGraphBuilder
            .addNode("initial", problem)
            .build()

        // Step 2: Generate initial decision
        val reasoner = GoTReasoner()
        val initialResult = reasoner.reason(graph)

        // Step 3: Apply iterative refinement
        val refinementResult = refinementEngine.refine(
            initialOutput = initialResult.decisions.first().decision,
            criteria = listOf(
                "Functional Correctness",
                "Code Quality",
                "Integration",
                "Documentation",
                "Performance"
            )
        )

        return RefinedResult(
            initialDecision = initialResult.decisions.first().decision,
            refinedDecision = refinementResult.refinedOutput,
            iterations = refinementResult.iterations,
            improvements = refinementResult.improvements
        )
    }
}
```

**Benefits:**
- GoT provides structured initial decision
- Iterative refinement improves quality systematically
- Multiple evaluation criteria ensure completeness

**See Also:** [iterative-refinement/SKILL.md](../iterative-refinement/SKILL.md)

---

### 6. GoT + Tool Orchestration

**Context:** Use GoT for planning, then orchestrate tools using Beads pattern.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + [tool-orchestration](../tool-orchestration/)

**Implementation:**
```kotlin
class GoTToolOrchestrationIntegration {
    private val goTReasoner = GoTReasoner()
    private val toolChainBuilder = ToolChainBuilder()

    suspend fun orchestrateTaskWithTools(
        task: String
    ): OrchestrationResult {
        // Step 1: Build GoT graph for task
        val graph = buildGoTGraphForTask(task)
        val result = goTReasoner.reason(graph)

        // Step 2: Create tool chain from decisions
        val toolChain = buildToolChainFromDecisions(result.decisions)

        // Step 3: Execute tool chain
        val executionResult = toolChainBuilder.execute(toolChain)

        return OrchestrationResult(
            task = task,
            goTDecisions = result.decisions,
            toolChain = toolChain,
            executionResults = executionResult.results
        )
    }

    private fun buildToolChainFromDecisions(decisions: List<GoTDecision>): ToolChain {
        return ToolChainBuilder()
            .addBead(AnalysisBead())
            .addBead(ValidationBead())
            .addBead(ExecutionBead())
            .addBead(ReportingBead())
            .build()
    }
}
```

**Benefits:**
- GoT plans complex workflows
- Tool orchestration executes steps reliably
- Beads pattern ensures clean, reusable chains

**See Also:** [tool-orchestration/SKILL.md](../tool-orchestration/SKILL.md)

---

### 7. GoT + LLM Integration

**Context:** Use GoT structure, but let LLM evaluate nodes.

**Skill:** [graph-of-thoughts](../graph-of-thoughts/) + LLM (OpenRouter with qwen/deepseek/kimi-2.5)

**Implementation:**
```kotlin
class GoTLLMIntegration {
    private val goTGraphBuilder = GoTGraphBuilder()
    private val llmClient = LLMClient()

    suspend fun reasonWithLLM(
        problem: String
    ): LLMReasoningResult {
        // Step 1: Build GoT graph
        val graph = buildGoTGraphForLLM(problem)
        val nodes = graph.nodes.values.toList()

        // Step 2: Let LLM evaluate each node
        val llmResults = mutableMapOf<String, GoTEvaluation>()

        for (node in nodes) {
            val llmEvaluation = evaluateNodeWithLLM(node, problem)
            llmResults[node.id] = llmEvaluation
        }

        // Step 3: Compile results
        val decisions = llmResults.values
            .filter { it.status == NodeStatus.RESOLVED }
            .map { it.decision }

        return LLMReasoningResult(
            problem = problem,
            graph = graph,
            evaluations = llmResults.values.toList(),
            decisions = decisions,
            llmCalls = nodes.size
        )
    }

    private suspend fun evaluateNodeWithLLM(
        node: GoTNode,
        problem: String
    ): GoTEvaluation {
        val prompt = """
            Evaluate this node for problem: $problem

            Node content: ${node.content}
            Node type: ${node.type}

            Based on the problem, determine if this node:
            1. Is a valid solution/fact/action
            2. Has dependencies satisfied
            3. Should be marked as RESOLVED or CONFLICTED

            Respond in JSON:
            {
              "status": "RESOLVED" | "CONFLICTED" | "INVALID",
              "decision": "your decision",
              "confidence": 0.0-1.0,
              "rationale": "brief explanation"
            }
        """.trimIndent()

        val response = llmClient.generate(prompt, model = "qwen/qwen-2.5-72b-instruct")
        return parseLLMEvaluation(response)
    }
}
```

**Benefits:**
- GoT provides structure
- LLM handles complex reasoning naturally
- Flexible for diverse problems

**LLM Models:** qwen/deepseek/kimi-2.5 (from OpenRouter)

---

### 8. Complete Workflow: GoT → ReAct → MCP → RAG

**Context:** End-to-end workflow combining all patterns.

**Skills:** All major agent patterns

**Implementation:**
```kotlin
class CompleteAgentWorkflow {
    private val goTReasoner = GoTReasoner()
    private val reActAgent = ReActAgent()
    private val mcpContextProvider = McpContextProvider()
    private val ragSystem = RAGMemorySystem()

    suspend fun executeEndToEndWorkflow(
        sessionId: String,
        query: String
    ): WorkflowResult {
        val startTime = System.currentTimeMillis()

        // Phase 1: Load context
        val mcpContext = mcpContextProvider.getContextForSession(sessionId)

        // Phase 2: Retrieve relevant memory
        val retrievedDocs = ragSystem.retrieve(query, partition = "knowledge", k = 5)

        // Phase 3: Build GoT graph with context
        val graph = buildCompleteGoTGraph(query, mcpContext, retrievedDocs)
        val plan = goTReasoner.reason(graph)

        if (plan.decisions.isEmpty()) {
            return WorkflowResult(
                success = false,
                phase = "GO_T",
                error = "Could not create plan"
            )
        }

        // Phase 4: Execute via ReAct
        val executionResults = mutableListOf<ReActResult>()
        plan.decisions.forEach { decision ->
            val reActAction = buildReActFromDecision(decision, mcpContext)
            val result = reActAgent.execute(reActAction)
            executionResults.add(result)
        }

        // Phase 5: Update context
        mcpContextProvider.updateContext(
            sessionId,
            ContextUpdate.AddWorkout(
                sessionId = sessionId,
                workout = WorkLog(
                    query = query,
                    decisions = plan.decisions.map { it.decision },
                    executionResults = executionResults,
                    timestamp = System.currentTimeMillis()
                )
            )
        )

        // Phase 6: Store in RAG
        ragSystem.store(
            content = plan.decisions.first().decision,
            partition = "decisions",
            metadata = mapOf(
                "query" to query,
                "sessionId" to sessionId,
                "timestamp" to System.currentTimeMillis()
            )
        )

        val elapsed = System.currentTimeMillis() - startTime

        return WorkflowResult(
            success = executionResults.all { it.success },
            phase = "COMPLETED",
            query = query,
            plan = plan,
            executionResults = executionResults,
            timeElapsedMs = elapsed,
            mcpContextUsed = true,
            ragContextUsed = true
        )
    }
}
```

**Workflow:**
1. **Load MCP context** for session
2. **Retrieve RAG context** for query
3. **Build GoT graph** with all context
4. **Reason through graph** to create plan
5. **Execute via ReAct** with context
6. **Update MCP context**
7. **Store in RAG**

**Benefits:**
- Multi-pattern integration for comprehensive solutions
- Context persistence across patterns
- Robust end-to-end workflow

---

## Integration Benefits

### Pattern Complementarity

| Pattern | Strengths | Limitations | Complementarity |
|---------|-----------|-------------|-----------------|
| **GoT** | Multi-hop, networked reasoning | Can be complex | + ReAct for execution |
| **ReAct** | Step-by-step reasoning | Linear, limited scope | + GoT for complex planning |
| **SC-ToT** | Self-correction, memory | Can be slow | + GoT for structured planning |
| **MCP** | Context sharing, persistence | No reasoning capability | + GoT for informed decisions |
| **RAG** | Retrieval of relevant info | No reasoning | + GoT for informed reasoning |
| **Iterative Refinement** | Quality improvement | Slow for simple tasks | + GoT for initial decisions |
| **Tool Orchestration** | Reliable execution | No reasoning | + GoT for planning |

### When to Use Together

| Scenario | Recommended Integration |
|----------|------------------------|
| Complex feature implementation | GoT → ReAct |
| Long-term memory decisions | GoT + MCP + RAG |
| Quality-critical decisions | GoT → SC-ToT → Refinement |
| Multi-tool workflows | GoT + Tool Orchestration |
| General problem solving | All patterns combined |

---

## Best Practices

### 1. Layer Patterns Wisely

```
Planning Layer: GoT / ToT
  ↓
Reasoning Layer: ReAct / SC-ToT
  ↓
Context Layer: MCP / RAG
  ↓
Execution Layer: Tool Orchestration
  ↓
Quality Layer: Iterative Refinement
```

### 2. Avoid Over-Engineering

```
✓ Use GoT for complex decisions (>3 independent branches)
✓ Use ReAct for simple steps (<3 actions)
✓ Use MCP only for cross-session context
✓ Use RAG for retrieval needs only
✓ Use Iterative Refinement only for quality-critical output
```

### 3. Monitor Performance

```kotlin
// Track which patterns are used
class PatternUsageTracker {
    suspend fun trackUsage(pattern: String, durationMs: Long) {
        // Log pattern usage for optimization
    }
}
```

---

## Resources

- [graph-of-thoughts/SKILL.md](../graph-of-thoughts/SKILL.md)
- [react-pattern/SKILL.md](../react-pattern/SKILL.md)
- [tree-of-thoughts/SELF-CORRECTING-TOT.md](../tree-of-thoughts/SELF-CORRECTING-TOT.md)
- [mcp-patterns/SKILL.md](../mcp-patterns/SKILL.md)
- [rag-memory/SKILL.md](../rag-memory/SKILL.md)
- [iterative-refinement/SKILL.md](../iterative-refinement/SKILL.md)
- [tool-orchestration/SKILL.md](../tool-orchestration/SKILL.md)

---

*Last Updated: 2026-04-28*
