# Graph-of-Thoughts Examples

## Example 1: System Architecture Decision

```kotlin
// System architecture decision with multiple constraints
suspend fun decideSystemArchitecture(): ArchitectureDecision {
    val graph = GoTGraphBuilder()
        // Root decision
        .addNode("arch-decision", "Choose system architecture")

        // Options
        .addNode("monolith", "Use monolithic architecture")
        .addNode("microservices", "Use microservices")
        .addNode("modular-monolith", "Use modular monolith")

        // Constraints
        .addNode("scale", "Needs to scale to 1M users")
        .addNode("team-size", "Team has 5 developers")
        .addNode("time", "Release in 3 months")
        .addNode("maintainability", "Code must be maintainable")

        // Evaluation of each option
        .addNode("monolith-eval", "Monolith is simpler")
        .addNode("micro-eval", "Microservices are scalable")
        .addNode("modular-eval", "Modular monolith is balanced")

        // Relationships showing trade-offs
        .addRelationship("arch-decision", "monolith", RelationshipType.CAUSE, 0.7)
        .addRelationship("arch-decision", "microservices", RelationshipType.CAUSE, 0.9)
        .addRelationship("arch-decision", "modular-monolith", RelationshipType.CAUSE, 0.8)

        .addRelationship("scale", "microservices", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("scale", "monolith", RelationshipType.CONTRADICTION, 0.85)

        .addRelationship("team-size", "monolith", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("team-size", "microservices", RelationshipType.CONFLICTS, 0.8)

        .addRelationship("time", "monolith", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("time", "microservices", RelationshipType.CONFLICTS, 0.9)

        .addRelationship("maintainability", "modular-monolith", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("maintainability", "monolith", RelationshipType.CONTRADICTION, 0.75)
        .addRelationship("maintainability", "microservices", RelationshipType.CONTRADICTION, 0.7)

        // Evaluation results
        .addRelationship("monolith-eval", "monolith", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("micro-eval", "microservices", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("modular-eval", "modular-monolith", RelationshipType.SUPPORTS, 0.95)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("arch-decision")

    return ArchitectureDecision(
        architecture = result.decisions.firstOrNull()?.decision ?: "Unknown",
        evaluations = result.evaluations,
        timeElapsedMs = result.timeElapsedMs
    )
}

data class ArchitectureDecision(
    val architecture: String,
    val evaluations: List<GoTEvaluation>,
    val timeElapsedMs: Long
)
```

**Expected Output:**
- Architecture: **modular-monolith**
- Reasoning: Balanced approach, meets scale requirements, manageable for team, fits timeline
- Key trade-offs: Moderately scalable vs microservices, more complex than monolith

---

## Example 2: Feature Implementation Plan

```kotlin
// Feature implementation with dependencies
suspend fun createFeaturePlan(feature: String): FeaturePlan {
    val graph = GoTGraphBuilder()
        .addNode("plan", "Create implementation plan for $feature")

        // Implementation options
        .addNode("fast-mvp", "Fast MVP with limited features")
        .addNode("standard", "Standard full-featured implementation")
        .addNode("comprehensive", "Comprehensive with all features")

        // Requirements
        .addNode("core", "Must have core functionality")
        .addNode("maintenance", "Must be maintainable")
        .addNode("security", "Must be secure")
        .addNode("testing", "Must have test coverage")

        // Evaluation results
        .addNode("fast-mvp-eval", "Fast MVP meets core requirement")
        .addNode("standard-eval", "Standard meets all requirements")
        .addNode("comprehensive-eval", "Comprehensive exceeds requirements")

        // Relationships
        .addRelationship("plan", "fast-mvp", RelationshipType.CAUSE, 0.8)
        .addRelationship("plan", "standard", RelationshipType.CAUSE, 0.9)
        .addRelationship("plan", "comprehensive", RelationshipType.CAUSE, 0.7)

        .addRelationship("core", "fast-mvp-eval", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("core", "standard-eval", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("core", "comprehensive-eval", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("maintenance", "fast-mvp-eval", RelationshipType.CONTRADICTION, 0.85)
        .addRelationship("maintenance", "standard-eval", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("maintenance", "comprehensive-eval", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("security", "fast-mvp-eval", RelationshipType.CONTRADICTION, 0.9)
        .addRelationship("security", "standard-eval", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("security", "comprehensive-eval", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("testing", "fast-mvp-eval", RelationshipType.CONTRADICTION, 0.8)
        .addRelationship("testing", "standard-eval", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("testing", "comprehensive-eval", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("fast-mvp-eval", "fast-mvp", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("standard-eval", "standard", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("comprehensive-eval", "comprehensive", RelationshipType.SUPPORTS, 0.95)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("plan")

    return FeaturePlan(
        featureName = feature,
        architecture = result.decisions.firstOrNull()?.decision ?: "Unknown",
        evaluations = result.evaluations
    )
}

data class FeaturePlan(
    val featureName: String,
    val architecture: String,
    val evaluations: List<GoTEvaluation>
)
```

**Expected Output:**
- Implementation: **Standard approach**
- Meets all core requirements
- Good maintainability
- Appropriate security measures
- Comprehensive test coverage

---

## Example 3: Debugging Multi-layered Issues

```kotlin
// Multi-layer debugging with interconnected causes
suspend fun debugPerformanceIssue(): DebugSolution {
    val graph = GoTGraphBuilder()
        .addNode("debug", "Debug performance degradation")

        // Potential causes
        .addNode("db-query", "Database query optimization")
        .addNode("memory-leak", "Memory leak in Java code")
        .addNode("network-latency", "Network latency to external API")
        .addNode("cache-config", "Caching misconfiguration")
        .addNode("idle-timeout", "Connection idle timeout")

        // Symptoms
        .addNode("symptom-slow", "Slow query times")
        .addNode("symptom-high-cpu", "High CPU usage")
        .addNode("symptom-high-heap", "High heap memory usage")
        .addNode("symptom-slow-api", "Slow API responses")

        // Analysis evidence
        .addNode("analysis1", "Query time increased by 200%")
        .addNode("analysis2", "Heap dump shows object retention")
        .addNode("analysis3", "Response time matches network RTT")
        .addNode("analysis4", "Cache hit rate dropped to 40%")

        // Relationships
        .addRelationship("debug", "db-query", RelationshipType.CAUSE, 0.7)
        .addRelationship("debug", "memory-leak", RelationshipType.CAUSE, 0.8)
        .addRelationship("debug", "network-latency", RelationshipType.CAUSE, 0.6)
        .addRelationship("debug", "cache-config", RelationshipType.CAUSE, 0.5)
        .addRelationship("debug", "idle-timeout", RelationshipType.CAUSE, 0.4)

        .addRelationship("symptom-slow", "analysis1", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("symptom-high-heap", "analysis2", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("symptom-slow-api", "analysis3", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("symptom-slow-api", "analysis4", RelationshipType.CONTRADICTION, 0.8)

        .addRelationship("db-query", "analysis1", RelationshipType.CONTRADICTION, 0.9)
        .addRelationship("memory-leak", "analysis2", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("network-latency", "analysis3", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("cache-config", "analysis4", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("cache-config", "analysis1", RelationshipType.CONTRADICTION, 0.8)
        .addRelationship("idle-timeout", "analysis3", RelationshipType.CONTRADICTION, 0.7)

        .addRelationship("db-query", "symptom-slow", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("memory-leak", "symptom-high-heap", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("network-latency", "symptom-slow-api", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("cache-config", "symptom-slow-api", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("idle-timeout", "symptom-slow-api", RelationshipType.CONTRADICTION, 0.6)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("debug")

    val diagnosis = result.decisions.firstOrNull()?.decision ?: "Unknown"
    val evaluation = result.evaluations

    return DebugSolution(
        diagnosis = diagnosis,
        evaluations = evaluation
    )
}

data class DebugSolution(
    val diagnosis: String,
    val evaluations: List<GoTEvaluation>
)
```

**Expected Output:**
- **Primary Cause: Memory leak**
- Evidence: High heap memory usage, object retention in heap dump
- Secondary: Network latency contributing to API response times
- Recommended actions: Investigate object retention patterns, optimize garbage collection

---

## Example 4: Technology Stack Selection

```kotlin
// Technology stack decision with trade-offs
suspend fun selectTechnologyStack(projectType: ProjectType): TechnologyDecision {
    val graph = GoTGraphBuilder()
        .addNode("stack-decision", "Choose technology stack for $projectType")

        // Backend options
        .addNode("spring-boot", "Spring Boot (Java)")
        .addNode("quarkus", "Quarkus (Java)")
        .addNode("ktor", "Ktor (Kotlin)")
        .addNode("go", "Golang")
        .addNode("nodejs", "Node.js")

        // Frontend options
        .addNode("react", "React")
        .addNode("svelte", "Svelte")
        .addNode("vue", "Vue")

        // Database options
        .addNode("postgresql", "PostgreSQL")
        .addNode("mongodb", "MongoDB")
        .addNode("redis", "Redis")

        // Project requirements
        .addNode("performance", "High performance required")
        .addNode("scale", "Need to scale to 100K users")
        .addNode("dev-speed", "Fast development speed")
        .addNode("team-expertise", "Team has Java expertise")
        .addNode("time", "Launch in 4 months")

        // Relationships (simplified)
        .addRelationship("stack-decision", "spring-boot", RelationshipType.CAUSE, 0.9)
        .addRelationship("stack-decision", "quarkus", RelationshipType.CAUSE, 0.85)
        .addRelationship("stack-decision", "ktor", RelationshipType.CAUSE, 0.8)
        .addRelationship("stack-decision", "go", RelationshipType.CAUSE, 0.7)
        .addRelationship("stack-decision", "nodejs", RelationshipType.CAUSE, 0.6)

        .addRelationship("performance", "go", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("performance", "ktor", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("performance", "quarkus", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("performance", "spring-boot", RelationshipType.CONTRADICTION, 0.7)

        .addRelationship("scale", "go", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("scale", "ktor", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("scale", "quarkus", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("scale", "spring-boot", RelationshipType.CONTRADICTION, 0.7)

        .addRelationship("dev-speed", "react", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("dev-speed", "svelte", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("dev-speed", "vue", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("dev-speed", "spring-boot", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("dev-speed", "go", RelationshipType.CONTRADICTION, 0.6)

        .addRelationship("team-expertise", "spring-boot", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("team-expertise", "quarkus", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("team-expertise", "ktor", RelationshipType.CONTRADICTION, 0.7)
        .addRelationship("team-expertise", "go", RelationshipType.CONTRADICTION, 0.6)

        .addRelationship("time", "spring-boot", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("time", "quarkus", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("time", "react", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("time", "go", RelationshipType.CONTRADICTION, 0.6)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("stack-decision")

    return TechnologyDecision(
        stack = result.decisions.map { it.decision }.toList(),
        evaluations = result.evaluations
    )
}

data class TechnologyDecision(
    val stack: List<String>,
    val evaluations: List<GoTEvaluation>
)

enum class ProjectType {
    BACKEND_API,
    FULLSTACK,
    MOBILE_WEB,
    REALTIME_SYSTEM
}
```

**Expected Output:**
- Backend: **Spring Boot**
- Frontend: **React**
- Database: **PostgreSQL**
- Rationale: Good performance, scalable, matches team expertise, fits timeline

---

## Example 5: Parallel Execution Example

```kotlin
// Use parallel execution for independent branches
suspend fun parallelDecisionMaking(): ParallelResult {
    val graph = GoTGraphBuilder()
        .addNode("main-decision", "Make main architectural decision")

        // Independent branches
        .addNode("branch-a", "Option A: Monolithic")
        .addNode("branch-b", "Option B: Microservices")
        .addNode("branch-c", "Option C: Modular")

        // Branch A specific
        .addNode("a-scale", "Monolith can scale with infrastructure")
        .addNode("a-team", "Monolith works with small team")

        // Branch B specific
        .addNode("b-scale", "Microservices scale horizontally")
        .addNode("b-team", "Microservices need larger team")

        // Branch C specific
        .addNode("c-scale", "Modular scales with load")
        .addNode("c-team", "Modular works with medium team")

        // Relationships
        .addRelationship("main-decision", "branch-a", RelationshipType.CAUSE, 0.8)
        .addRelationship("main-decision", "branch-b", RelationshipType.CAUSE, 0.9)
        .addRelationship("main-decision", "branch-c", RelationshipType.CAUSE, 0.8)

        .addRelationship("a-scale", "branch-a", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("a-team", "branch-a", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("b-scale", "branch-b", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("b-team", "branch-b", RelationshipType.CONTRADICTION, 0.9)

        .addRelationship("c-scale", "branch-c", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("c-team", "branch-c", RelationshipType.SUPPORTS, 0.95)

        .build()

    val executor = ParallelGoTExecutor(maxWorkers = 3)
    val result = executor.reasonParallel(graph, listOf("main-decision"))

    return ParallelResult(
        decisions = result.decisions,
        evaluations = result.evaluations,
        timeElapsedMs = result.timeElapsedMs
    )
}

data class ParallelResult(
    val decisions: List<GoTDecision>,
    val evaluations: List<GoTEvaluation>,
    val timeElapsedMs: Long
)
```

**Expected Output:**
- Decisions: branch-a, branch-c (both evaluated successfully)
- Time: Significantly faster than sequential (depends on maxWorkers)
- Branch B was rejected due to team size constraint

---

## Example 6: Conflict Resolution

```kotlin
// Detect and resolve conflicts in graph
suspend fun detectAndResolveConflicts(): ConflictResolutionResult {
    val graph = GoTGraphBuilder()
        .addNode("decision", "Choose deployment strategy")

        // Conflicting options
        .addNode("blue-green", "Blue-Green deployment")
        .addNode("canary", "Canary release")
        .addNode("rolling", "Rolling update")

        // Conflicting constraints
        .addNode("risk", "Low risk required")
        .addNode("speed", "Fast deployment required")

        // Contradictory evidence
        .addNode("evidence1", "Blue-green has low risk but slow")
        .addNode("evidence2", "Canary is medium risk and medium speed")
        .addNode("evidence3", "Rolling is high risk but fast")

        // Relationships
        .addRelationship("decision", "blue-green", RelationshipType.CAUSE, 0.8)
        .addRelationship("decision", "canary", RelationshipType.CAUSE, 0.8)
        .addRelationship("decision", "rolling", RelationshipType.CAUSE, 0.8)

        .addRelationship("risk", "evidence1", RelationshipType.CONTRADICTION, 0.9)
        .addRelationship("risk", "evidence2", RelationshipType.SUPPORTS, 0.85)
        .addRelationship("risk", "evidence3", RelationshipType.CONTRADICTION, 0.8)

        .addRelationship("speed", "evidence1", RelationshipType.CONTRADICTION, 0.9)
        .addRelationship("speed", "evidence2", RelationshipType.CONTRADICTION, 0.7)
        .addRelationship("speed", "evidence3", RelationshipType.SUPPORTS, 0.95)

        .addRelationship("evidence1", "blue-green", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("evidence2", "canary", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("evidence3", "rolling", RelationshipType.SUPPORTS, 0.95)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("decision")

    val detector = CycleDetector()
    val conflicts = detector.detectConflicts(graph, result.evaluations)

    return ConflictResolutionResult(
        decisions = result.decisions,
        conflicts = conflicts,
        resolution = resolveConflicts(conflicts)
    )
}

suspend fun resolveConflicts(conflicts: List<Conflict>): ConflictResolution {
    return when {
        conflicts.isNotEmpty() -> {
            // Priority: risk > speed
            val riskConflict = conflicts.find { it.relationship.type == RelationshipType.CONTRADICTION }
            if (riskConflict != null) {
                ConflictResolution(
                    chosen = riskConflict.nodes.first(),
                    reason = "Risk constraint takes priority over speed",
                    resolvedConflicts = conflicts
                )
            } else {
                ConflictResolution(
                    chosen = "canary",
                    reason = "Canary provides balanced risk/speed trade-off",
                    resolvedConflicts = conflicts
                )
            }
        }
        else -> ConflictResolution(
            chosen = result.decisions.firstOrNull()?.decision ?: "",
            reason = "No conflicts found",
            resolvedConflicts = emptyList()
        )
    }
}

data class ConflictResolutionResult(
    val decisions: List<GoTDecision>,
    val conflicts: List<Conflict>,
    val resolution: ConflictResolution
)

data class ConflictResolution(
    val chosen: String,
    val reason: String,
    val resolvedConflicts: List<Conflict>
)
```

**Expected Output:**
- **Chosen Strategy: Blue-Green deployment**
- **Reason:** Low risk takes priority over fast deployment
- **Resolves:** Risk-speed conflict by prioritizing risk constraint
- **Alternative:** Canary release if speed becomes critical

---

## Example 7: GoT + ReAct Integration

```kotlin
// Combine GoT for planning, ReAct for execution
class GoTReActIntegration {
    private val goTBuilder = GoTGraphBuilder()
    private val reActAgent = ReActAgent()

    suspend fun executeComplexTask(task: String): TaskResult {
        // Step 1: Use GoT to plan
        val graph = buildGoTGraphForTask(task)
        val planResult = GoTReasoner().reason(graph)

        if (planResult.decisions.isEmpty()) {
            return TaskResult(
                success = false,
                error = "Could not create plan for task",
                plan = graph,
                decisions = emptyList()
            )
        }

        // Step 2: Use ReAct to execute decisions
        val executed = mutableListOf<String>()
        val reActResults = mutableListOf<ReActResult>()

        planResult.decisions.forEach { decision ->
            val reActAction = buildReActFromDecision(decision)
            val reActResult = reActAgent.execute(reActAction)
            executed.add(decision.decision)
            reActResults.add(reActResult)
        }

        // Step 3: Verify results
        val verification = verifyExecutionResults(reActResults)

        return TaskResult(
            success = verification.success,
            executedDecisions = executed,
            reActResults = reActResults,
            plan = graph,
            evaluations = planResult.evaluations,
            verification = verification
        )
    }

    private fun buildGoTGraphForTask(task: String): GoTGraph {
        return GoTGraphBuilder()
            .addNode("task", task)
            .addNode("step1", "Research domain")
            .addNode("step2", "Design solution")
            .addNode("step3", "Implement")
            .addNode("step4", "Test")
            .addRelationship("task", "step1", RelationshipType.CAUSE, 0.9)
            .addRelationship("step1", "step2", RelationshipType.CAUSE, 0.95)
            .addRelationship("step2", "step3", RelationshipType.CAUSE, 0.95)
            .addRelationship("step3", "step4", RelationshipType.CAUSE, 0.95)
            .build()
    }

    private fun buildReActFromDecision(decision: GoTDecision): ReActAction {
        return ReActAction(
            thought = "Execute: ${decision.decision}",
            action = decision.decision,
            expectedOutcome = "Task completed successfully"
        )
    }

    private fun verifyExecutionResults(results: List<ReActResult>): VerificationResult {
        val successful = results.count { it.success }
        val total = results.size

        return when {
            successful == total -> VerificationResult(
                success = true,
                passed = successful,
                failed = 0,
                summary = "All steps completed successfully"
            )
            successful >= total * 0.8 -> VerificationResult(
                success = true,
                passed = successful,
                failed = total - successful,
                summary = "Most steps completed successfully"
            )
            else -> VerificationResult(
                success = false,
                passed = successful,
                failed = total - successful,
                summary = "Some steps failed, needs retry"
            )
        }
    }
}

data class TaskResult(
    val success: Boolean,
    val executedDecisions: List<String>,
    val reActResults: List<ReActResult>,
    val plan: GoTGraph,
    val evaluations: List<GoTEvaluation>,
    val verification: VerificationResult
)

data class VerificationResult(
    val success: Boolean,
    val passed: Int,
    val failed: Int,
    val summary: String
)
```

**Expected Output:**
- **Plan Created:** 4-step plan for task
- **Executed:** All 4 steps via ReAct
- **Verification:** All steps successful
- **Success Rate:** 100%

---

## Example 8: GoT with Multi-Hop Reasoning

```kotlin
// Multi-hop reasoning through intermediate nodes
suspend fun multiHopReasoning(): MultiHopResult {
    val graph = GoTGraphBuilder()
        .addNode("root", "Evaluate new framework adoption")

        // Intermediate steps
        .addNode("evaluate", "Evaluate feasibility")
        .addNode("benefits", "Identify benefits")
        .addNode("risks", "Identify risks")
        .addNode("costs", "Estimate costs")
        .addNode("implementation", "Plan implementation")

        // Final decision
        .addNode("decision", "Should we adopt?")

        // Relationships showing reasoning path
        .addRelationship("root", "evaluate", RelationshipType.CAUSE, 0.9)
        .addRelationship("evaluate", "benefits", RelationshipType.CAUSE, 0.95)
        .addRelationship("evaluate", "risks", RelationshipType.CAUSE, 0.95)
        .addRelationship("evaluate", "costs", RelationshipType.CAUSE, 0.9)

        .addRelationship("benefits", "decision", RelationshipType.CAUSE, 0.8)
        .addRelationship("risks", "decision", RelationshipType.CAUSE, 0.9)
        .addRelationship("costs", "decision", RelationshipType.CAUSE, 0.85)

        // Multi-hop connections
        .addRelationship("risks", "benefits", RelationshipType.CONTRADICTION, 0.85)
        .addRelationship("costs", "benefits", RelationshipType.CONTRADICTION, 0.8)
        .addRelationship("benefits", "implementation", RelationshipType.SUPPORTS, 0.95)

        // Additional evaluation nodes
        .addNode("benefit1", "Performance improvement")
        .addNode("benefit2", "Developer productivity")
        .addNode("risk1", "Learning curve")
        .addNode("risk2", "Migration effort")

        .addRelationship("benefits", "benefit1", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("benefits", "benefit2", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("risks", "risk1", RelationshipType.SUPPORTS, 0.95)
        .addRelationship("risks", "risk2", RelationshipType.SUPPORTS, 0.9)

        .addRelationship("benefit1", "decision", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("benefit2", "decision", RelationshipType.SUPPORTS, 0.9)
        .addRelationship("risk1", "decision", RelationshipType.CONTRADICTION, 0.95)
        .addRelationship("risk2", "decision", RelationshipType.CONTRADICTION, 0.9)

        .build()

    val reasoner = GoTReasoner()
    val result = reasoner.reason("root")

    val intermediateResults = result.evaluations.filter {
        it.nodeId in listOf("evaluate", "benefits", "risks", "costs")
    }

    return MultiHopResult(
        rootDecision = result.decisions.firstOrNull()?.decision ?: "Unknown",
        intermediateResults = intermediateResults,
        evaluations = result.evaluations,
        reasoningPath = traceReasoningPath(result.evaluations)
    )
}

data class MultiHopResult(
    val rootDecision: String,
    val intermediateResults: List<GoTEvaluation>,
    val evaluations: List<GoTEvaluation>,
    val reasoningPath: List<String>
)
```

**Expected Output:**
- **Decision:** "Adopt framework with implementation plan"
- **Intermediate Steps:**
  - Evaluated: ✅ Feasibility confirmed
  - Benefits: ✅ Performance +20%, Developer productivity +30%
  - Risks: ⚠️ Learning curve, Migration effort
  - Costs: ✅ Justified ROI
- **Reasoning Path:** Root → Evaluate → Benefits/Risks → Decision

---

*These examples demonstrate GoT's flexibility for complex, interconnected decision-making scenarios.*
