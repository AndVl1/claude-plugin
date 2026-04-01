---
name: tree-of-thoughts
description: Implement Tree-of-Thoughts pattern for multi-branch reasoning and solution exploration
tags: [agent-pattern, reasoning, exploration, strategy, decision-making]
version: 1.0.0
---

# Tree-of-Thoughts (ToT) Pattern Skill

## Purpose

Enable agents to systematically explore multiple reasoning paths and solution branches before committing to the best approach. **ToT** extends ReAct by allowing exploration of multiple hypotheses and strategies, making complex decision-making more structured and transparent.

## What is Tree-of-Thoughts?

**Tree-of-Thoughts** is an agentic workflow pattern where:
1. **Generate multiple hypotheses** about the solution
2. **Explore each hypothesis** through reasoning and action
3. **Evaluate branches** based on evidence and criteria
4. **Prune branches** that are unlikely to succeed
5. **Commit to best branch** or iterate further

This creates a visual reasoning tree that makes the decision-making process transparent and extensible.

## When to Use

- **Complex Problem Solving** - Problems with multiple possible solutions
- **Strategic Decisions** - Architectural choices, technology selection
- **Debugging** - When multiple potential causes exist
- **Research** - Exploring unknown domains
- **Feature Planning** - Choosing between implementation approaches
- **Optimization** - Finding the best performance strategy
- **Security Analysis** - Assessing multiple threat vectors

## ToT vs ReAct

| Aspect | ReAct | Tree-of-Thoughts |
|--------|-------|------------------|
| **Structure** | Linear chain | Tree with branching |
| **Exploration** | Single path | Multiple paths |
| **Decision** | Sequential choices | Branch evaluation |
| **Backtracking** | Limited | Natural backtracking |
| **Transparency** | Step-by-step | Visual tree structure |
| **Use Case** | Clear, linear tasks | Complex, uncertain problems |

## The ToT Pattern

### Tree Structure

```
Root Problem
├── Branch 1: Approach A
│   ├── Sub-branch 1.1: Implementation
│   │   ├── Step 1.1.1
│   │   └── Step 1.1.2
│   └── Sub-branch 1.2: Evaluation
│       ├── Pros
│       └── Cons
├── Branch 2: Approach B
│   └── ...
└── Branch 3: Approach C
    └── ...
```

### ToT Process

#### 1. Generate Branches (Hypotheses)

Create multiple possible approaches:

```
Root Problem: How to optimize API response time

Branch 1: Caching Layer
- Implement Redis cache
- Set TTL on hot endpoints
- Cache invalidation strategy
- Pros: Low complexity, immediate impact
- Cons: Cache consistency issues

Branch 2: Database Optimization
- Add composite indexes
- Optimize queries
- Connection pooling
- Pros: Better data access
- Cons: Higher complexity, requires DB expertise

Branch 3: API Versioning & Restructuring
- Version 2 with new schema
- Gradual migration
- Pros: Cleaner architecture
- Cons: High implementation cost, migration risk
```

#### 2. Explore Branches (Reason + Act)

Investigate each branch:

```
Branch 1: Caching Layer
Thought: Redis is well-suited for API response caching
Action: Research Redis best practices
Observation: Redis requires connection management, expiration policies
Thought: Cache invalidation will be complex
Action: Evaluate cache invalidation strategies
Observation: Write-through caching is most reliable
```

#### 3. Evaluate Branches (Assessment)

Score each branch:

```
Evaluation Criteria:
1. Implementation Effort (Low → High)
2. Performance Impact (High → Low)
3. Complexity Risk (Low → High)
4. Maintainability (High → Low)
5. Rollback Risk (Low → High)

Branch 1: Caching Layer
- Effort: 2/5
- Impact: 4/5
- Complexity: 3/5
- Maintainability: 4/5
- Rollback: 1/5
- Total: 14/25 (Medium)

Branch 2: Database Optimization
- Effort: 3/5
- Impact: 4/5
- Complexity: 2/5
- Maintainability: 5/5
- Rollback: 1/5
- Total: 15/25 (Medium)

Branch 3: API Restructuring
- Effort: 5/5
- Impact: 4/5
- Complexity: 5/5
- Maintainability: 4/5
- Rollback: 4/5
- Total: 22/25 (High)
```

#### 4. Prune Branches

Discard low-scoring branches:

```
Branch 3 (API Restructuring): Dropped
- Too high effort and risk
- Rollback difficulty too high

Selected Branches: 1 and 2
```

#### 5. Commit or Iterate

Choose best approach or explore further:

```
Decision: Test Branch 1 and 2 in parallel
Plan:
1. Implement caching layer
2. Optimize database
3. A/B test both
4. Measure response time
5. Select winner
```

## ToT Framework Example

### Kotlin Implementation

```kotlin
data class ToTBranch(
    val id: String,
    val name: String,
    val description: String,
    val hypotheses: List<String>,
    val reasoningPath: List<ToTStep>,
    val evaluation: ToTEvaluation,
    val isSelected: Boolean = false
)

data class ToTStep(
    val id: String,
    val thought: String,
    val action: ToTAction?,
    val observation: String?,
    val isComplete: Boolean = false
)

data class ToTAction(
    val type: ActionType,
    val description: String
)

enum class ActionType {
    THINK, EXECUTE, OBSERVE, EVALUATE, DECIDE
}

data class ToTEvaluation(
    val effort: Int, // 1-5, 1=Low, 5=High
    val impact: Int, // 1-5, 5=High
    val complexity: Int, // 1-5, 1=Low, 5=High
    val maintainability: Int, // 1-5, 5=High
    val rollbackRisk: Int, // 1-5, 1=Low, 5=High
    val totalScore: Int
)

class TreeOfThoughts {
    private val branches = mutableListOf<ToTBranch>()
    private var currentTree = ToTTree()

    fun generateBranches(problem: String): List<ToTBranch> {
        // Generate multiple approaches to solve the problem
        val approaches = listOf(
            ToTBranch(
                id = "branch-1",
                name = "Caching Layer",
                description = "Add Redis cache to hot endpoints",
                hypotheses = listOf(
                    "Redis provides fast in-memory storage",
                    "TTL-based cache invalidation is reliable",
                    "Read performance will improve significantly"
                ),
                reasoningPath = emptyList(),
                evaluation = ToTEvaluation(
                    effort = 2,
                    impact = 4,
                    complexity = 3,
                    maintainability = 4,
                    rollbackRisk = 1,
                    totalScore = 14
                )
            ),
            ToTBranch(
                id = "branch-2",
                name = "Database Optimization",
                description = "Optimize queries and add indexes",
                hypotheses = listOf(
                    "Slow queries need indexing",
                    "Connection pooling reduces overhead",
                    "Proper schema design improves performance"
                ),
                reasoningPath = emptyList(),
                evaluation = ToTEvaluation(
                    effort = 3,
                    impact = 4,
                    complexity = 2,
                    maintainability = 5,
                    rollbackRisk = 1,
                    totalScore = 15
                )
            ),
            ToTBranch(
                id = "branch-3",
                name = "API Restructuring",
                description = "Version 2 with optimized schema",
                hypotheses = listOf(
                    "New schema reduces payload size",
                    "Separate endpoints reduce load",
                    "Better caching opportunities"
                ),
                reasoningPath = emptyList(),
                evaluation = ToTEvaluation(
                    effort = 5,
                    impact = 4,
                    complexity = 5,
                    maintainability = 4,
                    rollbackRisk = 4,
                    totalScore = 22
                )
            )
        )
        
        branches.addAll(approaches)
        return approaches
    }

    fun exploreBranch(branchId: String, steps: Int = 5) {
        val branch = branches.find { it.id == branchId }
            ?: return

        println("Exploring: ${branch.name}")
        
        // Simulate reasoning path
        val path = mutableListOf<ToTStep>()
        
        for (i in 1..steps) {
            val step = ToTStep(
                id = "${branch.id}-step-$i",
                thought = generateThought(branch, i),
                action = if (i < steps) generateAction(branch, i) else null,
                observation = if (i == steps) null else generateObservation(branch, i),
                isComplete = i == steps
            )
            path.add(step)
        }
        
        branch.reasoningPath = path
        println("Explored ${steps} steps")
    }

    fun evaluateBranches() {
        println("\n=== Branch Evaluation ===")
        
        branches.sortedByDescending { it.evaluation.totalScore }.forEach { branch ->
            println("\n${branch.name}")
            println("  Score: ${branch.evaluation.totalScore}/25")
            println("  Effort: ${branch.evaluation.effort}/5")
            println("  Impact: ${branch.evaluation.impact}/5")
            println("  Complexity: ${branch.evaluation.complexity}/5")
            println("  Maintainability: ${branch.evaluation.maintainability}/5")
            println("  Rollback: ${branch.evaluation.rollbackRisk}/5")
            
            if (branch.isSelected) {
                println("  ⭐ SELECTED")
            }
        }
    }

    fun pruneBranches(minScore: Int = 15) {
        println("\n=== Pruning Branches (min score: $minScore) ===")
        
        val toRemove = branches.filter { it.evaluation.totalScore < minScore }
        toRemove.forEach { branch ->
            println("Removed: ${branch.name} (score: ${branch.evaluation.totalScore})")
            branches.remove(branch)
        }
        
        if (branches.isEmpty()) {
            throw IllegalStateException("No viable branches remaining!")
        }
    }

    fun selectBestBranch(): ToTBranch {
        val selected = branches.maxByOrNull { it.evaluation.totalScore }
            ?: throw IllegalStateException("No branch selected!")
        
        selected.isSelected = true
        println("\n✅ Selected: ${selected.name} (score: ${selected.evaluation.totalScore})")
        
        return selected
    }

    private fun generateThought(branch: ToTBranch, step: Int): String {
        return when (step) {
            1 -> "I should explore ${branch.name} approach"
            2 -> "What are the key components of ${branch.name}?"
            3 -> "How would ${branch.name} solve the problem?"
            4 -> "Are there potential risks with ${branch.name}?"
            else -> "This approach looks promising"
        }
    }

    private fun generateAction(branch: ToTBranch, step: Int): ToTAction {
        return ToTAction(
            type = ActionType.EXECUTE,
            description = "Analyze ${branch.name} implementation"
        )
    }

    private fun generateObservation(branch: ToTBranch, step: Int): String {
        return when (step) {
            1 -> "Found ${branch.name} documentation"
            2 -> "Components identified: ${branch.hypotheses.take(2)}"
            3 -> "Benefits: improved performance, scalability"
            4 -> "Risks: requires monitoring, setup time"
            else -> "Ready to evaluate"
        }
    }
}

// Usage Example
fun main() {
    val tot = TreeOfThoughts()
    
    // Step 1: Generate branches
    val branches = tot.generateBranches("Optimize API response time")
    
    // Step 2: Explore each branch
    branches.forEach { branch ->
        tot.exploreBranch(branch.id, steps = 4)
    }
    
    // Step 3: Evaluate branches
    tot.evaluateBranches()
    
    // Step 4: Prune low-scoring branches
    tot.pruneBranches(minScore = 15)
    
    // Step 5: Select best branch
    val selectedBranch = tot.selectBestBranch()
    
    println("\n=== Implementation Plan ===")
    println("Approach: ${selectedBranch.name}")
    println("Reasoning: ${selectedBranch.reasoningPath}")
}
```

### Spring Boot Integration

```kotlin
@Service
class ToTDecisionService(
    private val llmClient: LLMClient
) {
    private val toTreeOfThoughts = TreeOfThoughts()

    suspend fun makeDecision(
        problem: String,
        context: Map<String, Any>,
        timeLimitMs: Long = 60000
    ): DecisionResult {
        val startTime = System.currentTimeMillis()
        
        // 1. Generate branches
        val branches = toTreeOfThoughts.generateBranches(problem)
        
        // 2. Explore branches with LLM
        branches.forEach { branch ->
            exploreBranchWithLLM(branch, context)
            
            // Check time limit
            if (System.currentTimeMillis() - startTime > timeLimitMs) {
                break
            }
        }
        
        // 3. Evaluate and select
        toTreeOfThoughts.evaluateBranches()
        toTreeOfThoughts.pruneBranches(minScore = 15)
        val selected = toTreeOfThoughts.selectBestBranch()
        
        return DecisionResult(
            decision = selected,
            branches = branches.toList(),
            timeElapsedMs = System.currentTimeMillis() - startTime,
            confidence = calculateConfidence(branches)
        )
    }

    private suspend fun exploreBranchWithLLM(
        branch: ToTBranch,
        context: Map<String, Any>
    ) {
        val prompt = """
            Explore this decision branch: ${branch.name}
            
            Context: ${context}
            
            Branch description: ${branch.description}
            
            Hypotheses:
            ${branch.hypotheses.joinToString("\n") { "• $it" }}
            
            Reason step by step:
        """.trimIndent()
        
        val response = llmClient.generate(prompt, maxTokens = 500)
        
        // Parse and store reasoning path
        val steps = parseReasoningPath(response)
        branch.reasoningPath = steps
        
        // Update evaluation with LLM input
        branch.evaluation = llmEvaluateBranch(branch)
    }

    private suspend fun llmEvaluateBranch(branch: ToTBranch): ToTEvaluation {
        val prompt = """
            Evaluate this decision branch:
            
            Name: ${branch.name}
            Description: ${branch.description}
            Hypotheses: ${branch.hypotheses.joinToString(", ")}
            
            For each criterion (1=Low, 5=High), provide score and brief justification:
            
            Effort to implement
            Impact on problem
            Implementation complexity
            Long-term maintainability
            Ease of rollback
            
            Respond in JSON format:
            {
              "effort": 1-5,
              "impact": 1-5,
              "complexity": 1-5,
              "maintainability": 1-5,
              "rollbackRisk": 1-5
            }
        """.trimIndent()
        
        val response = llmClient.generate(prompt, maxTokens = 300)
        val evaluation = parseEvaluation(response)
        
        return ToTEvaluation(
            effort = evaluation.effort,
            impact = evaluation.impact,
            complexity = evaluation.complexity,
            maintainability = evaluation.maintainability,
            rollbackRisk = evaluation.rollbackRisk,
            totalScore = (evaluation.effort + evaluation.impact + evaluation.complexity +
                         evaluation.maintainability + evaluation.rollbackRisk) / 5.0
        )
    }
}

data class DecisionResult(
    val decision: ToTBranch,
    val branches: List<ToTBranch>,
    val timeElapsedMs: Long,
    val confidence: Double
)
```

## Integration with ReAct

ToT and ReAct can work together:

### Hybrid Approach

```
1. Use ToT for high-level decision making (choose approach)
2. Use ReAct for detailed implementation (execute approach)
3. Use ToT again for optimization decisions
```

### Example

```kotlin
class HybridAgent(
    private val totService: ToTDecisionService,
    private val reActAgent: ReActAgent
) {
    suspend fun solveComplexProblem(
        problem: String
    ): Solution {
        // Step 1: Use ToT to choose approach
        val decision = totService.makeDecision(problem)
        
        // Step 2: Use ReAct to implement chosen approach
        val reActPrompt = buildReActPrompt(problem, decision.decision)
        val solution = reActAgent.execute(reActPrompt)
        
        return Solution(
            approach = decision.decision.name,
            solution = solution,
            confidence = decision.confidence
        )
    }
}
```

## Real-world Use Cases

### Use Case 1: Feature Architecture Decision

```kotlin
class FeatureArchitectureToT {
    data class Branch(
        val name: String,
        val approach: String,
        val rationale: String,
        val evaluation: ToTEvaluation
    )

    fun decideArchitecture(
        feature: String,
        requirements: FeatureRequirements
    ): Branch {
        val branches = listOf(
            Branch(
                name = "Monolith",
                approach = "Single codebase with modular structure",
                rationale = "Simpler deployment, faster development",
                evaluation = ToTEvaluation(
                    effort = 1, impact = 3, complexity = 1,
                    maintainability = 2, rollbackRisk = 1,
                    totalScore = 8
                )
            ),
            Branch(
                name = "Microservices",
                approach = "Decoupled services with API gateway",
                rationale = "Scalability, technology diversity",
                evaluation = ToTEvaluation(
                    effort = 5, impact = 5, complexity = 5,
                    maintainability = 3, rollbackRisk = 4,
                    totalScore = 22
                )
            ),
            Branch(
                name = "Modular Monolith",
                approach = "Structured monolith with clear boundaries",
                rationale = "Balance of simplicity and scalability",
                evaluation = ToTEvaluation(
                    effort = 2, impact = 4, complexity = 3,
                    maintainability = 4, rollbackRisk = 2,
                    totalScore = 15
                )
            )
        )

        return branches.maxByOrNull { it.evaluation.totalScore }
            ?: throw IllegalStateException("No viable architecture")
    }
}
```

### Use Case 2: Debugging Performance Issues

```kotlin
class PerformanceDebugToT {
    data class DebugBranch(
        val suspectedCause: String,
        val investigationSteps: List<String>,
        val expectedImpact: String,
        val evaluation: ToTEvaluation
    )

    fun diagnosePerformanceIssue(issue: PerformanceIssue): DebugBranch {
        val branches = listOf(
            DebugBranch(
                suspectedCause = "Database Query Inefficiency",
                investigationSteps = listOf(
                    "Add query profiling",
                    "Review execution plan",
                    "Check indexes",
                    "Optimize joins"
                ),
                expectedImpact = "Reduce query time by 50-80%",
                evaluation = ToTEvaluation(
                    effort = 3, impact = 5, complexity = 2,
                    maintainability = 5, rollbackRisk = 1,
                    totalScore = 16
                )
            ),
            DebugBranch(
                suspectedCause = "Memory Leaks",
                investigationSteps = listOf(
                    "Enable heap dumps",
                    "Use profilers",
                    "Check object retention",
                    "Analyze GC logs"
                ),
                expectedImpact = "Reduce memory usage by 30-50%",
                evaluation = ToTEvaluation(
                    effort = 4, impact = 5, complexity = 3,
                    maintainability = 4, rollbackRisk = 1,
                    totalScore = 17
                )
            ),
            DebugBranch(
                suspectedCause = "Network Latency",
                investigationSteps = listOf(
                    "Check network paths",
                    "Analyze HTTP roundtrips",
                    "Implement caching",
                    "Use CDN if applicable"
                ),
                expectedImpact = "Reduce response time by 40-60%",
                evaluation = ToTEvaluation(
                    effort = 2, impact = 4, complexity = 2,
                    maintainability = 5, rollbackRisk = 1,
                    totalScore = 14
                )
            )
        )

        return branches.maxByOrNull { it.evaluation.totalScore }
            ?: throw IllegalStateException("No viable diagnosis")
    }
}
```

### Use Case 3: Technology Stack Selection

```kotlin
class TechStackToT {
    data class StackBranch(
        val framework: String,
        val pros: List<String>,
        val cons: List<String>,
        val evaluation: ToTEvaluation
    )

    suspend fun selectStack(
        projectType: ProjectType,
        teamExperience: List<String>
    ): StackBranch {
        val frameworks = when (projectType) {
            ProjectType.BACKEND_API -> listOf(
                StackBranch(
                    framework = "Spring Boot",
                    pros = listOf(
                        "Enterprise-grade features",
                        "Comprehensive documentation",
                        "Large ecosystem",
                        "Strong community"
                    ),
                    cons = listOf(
                        "Verbose configuration",
                        "Heavy by default",
                        "Steep learning curve"
                    ),
                    evaluation = ToTEvaluation(
                        effort = 2, impact = 5, complexity = 2,
                        maintainability = 5, rollbackRisk = 1,
                        totalScore = 15
                    )
                ),
                StackBranch(
                    framework = "Quarkus",
                    pros = listOf(
                        "Fast startup",
                        "Declarative config",
                        "Native image support",
                        "Good performance"
                    ),
                    cons = listOf(
                        "Newer ecosystem",
                        "Fewer examples",
                        "Smaller community"
                    ),
                    evaluation = ToTEvaluation(
                        effort = 3, impact = 5, complexity = 2,
                        maintainability = 4, rollbackRisk = 2,
                        totalScore = 16
                    )
                )
            )
            ProjectType.FRONTEND -> listOf(
                StackBranch(
                    framework = "React",
                    pros = listOf(
                        "Large community",
                        "Rich ecosystem",
                        "Hiring pool",
                        "Well-documented"
                    ),
                    cons = listOf(
                        "Boilerplate",
                        "Learning curve",
                        "Bundle size"
                    ),
                    evaluation = ToTEvaluation(
                        effort = 2, impact = 5, complexity = 2,
                        maintainability = 4, rollbackRisk = 1,
                        totalScore = 14
                    )
                ),
                StackBranch(
                    framework = "SvelteKit",
                    pros = listOf(
                        "No runtime overhead",
                        "Simpler concepts",
                        "Better DX",
                        "Small bundle"
                    ),
                    cons = listOf(
                        "Smaller ecosystem",
                        "Fewer libraries",
                        "Less known"
                    ),
                    evaluation = ToTEvaluation(
                        effort = 3, impact = 5, complexity = 1,
                        maintainability = 5, rollbackRisk = 1,
                        totalScore = 15
                    )
                )
            )
        }

        return frameworks.maxByOrNull { it.evaluation.totalScore }
            ?: throw IllegalStateException("No viable framework found")
    }
}
```

## Best Practices

### 1. Branch Quality

- Generate diverse, well-thought-out branches
- Each branch should be viable
- Avoid trivial alternatives
- Consider both short-term and long-term impacts

### 2. Evaluation Criteria

Use objective, measurable criteria:
```
✓ Use scoring rubrics (1-5 scale)
✓ Document justification for each score
✓ Consider multiple dimensions (effort, impact, risk)
✓ Update criteria as understanding evolves
```

### 3. Pruning Strategy

```
✓ Set minimum score threshold
✓ Remove branches that clearly won't work
✓ Keep at least 2-3 branches for comparison
✓ Document pruning reasons
```

### 4. Depth of Exploration

```
✓ Explore enough to evaluate (3-5 steps per branch)
✓ Don't over-explore (time-bound)
✓ Focus on key decision points
✓ Use LLM for initial exploration, human for final decisions
```

### 5. Visualization

```
✓ Visualize decision tree (Mermaid diagrams)
✓ Track branch states
✓ Show evaluation scores
✓ Highlight selected branch
```

### 6. Integration with Other Patterns

```
✓ ToT for high-level decisions, ReAct for execution
✓ ToT for architecture, iterative-refinement for implementation
✓ Use rag-memory to gather information for branches
✓ Tool orchestration for branch exploration steps
```

## Testing Strategies

### Unit Tests

```kotlin
class TreeOfThoughtsTest {
    @Test
    fun `generate branches creates multiple approaches`() {
        val tot = TreeOfThoughts()
        val branches = tot.generateBranches("Optimize API")
        
        assertThat(branches).hasSizeGreaterThan(2)
        assertThat(branches).allMatch { it.evaluation.totalScore > 0 }
    }

    @Test
    fun `evaluate branches sorts by score`() {
        val tot = TreeOfThoughts()
        tot.generateBranches("Test")
        tot.exploreBranch("branch-1", 2)
        tot.exploreBranch("branch-2", 2)
        
        val branches = tot.branches
        assertThat(branches[0].evaluation.totalScore)
            .isGreaterThanOrEqualTo(branches[1].evaluation.totalScore)
    }
}
```

### Integration Tests

```kotlin
class ToTDecisionServiceTest {
    @Test
    fun `selects highest scoring branch`() = runTest {
        val service = ToTDecisionService(mockLLMClient())
        val result = service.makeDecision("Test problem")
        
        assertThat(result.decision.evaluation.totalScore)
            .isGreaterThan(0)
        assertThat(result.decision.isSelected).isTrue()
    }

    @Test
    fun `times out after specified limit`() = runTest {
        val service = ToTDecisionService(mockLLMClient())
        val result = service.makeDecision("Test", timeLimitMs = 1000)
        
        assertThat(result.timeElapsedMs).isLessThan(2000)
    }
}
```

## Performance Considerations

### Optimization Strategies

1. **Limit Branch Count**
   - Start with 3-5 branches
   - Increase if needed

2. **Early Pruning**
   - Filter obvious non-viable branches quickly
   - Avoid deep exploration of bad branches

3. **Caching**
   - Cache branch evaluations
   - Reuse evaluated branches for similar problems

4. **LLM Rate Limiting**
   - Batch LLM calls
   - Use smaller models for initial exploration
   - Reserve large model for final selection

5. **Parallel Exploration**
   - Explore branches in parallel (thread-safe)
   - Don't wait for slow branches

## Common Patterns

### Pattern 1: Incremental Branching

```kotlin
// Start simple, add complexity as needed
val initialBranches = generateSimpleBranches(problem)
var branches = initialBranches

while (branches.size < targetBranches && !isTimeExhausted) {
    val newBranch = generateEnhancedBranch(branches.last())
    branches.add(newBranch)
}
```

### Pattern 2: Pruning on Evaluation

```kotlin
// Prune as you go
fun evaluateAndPrune(branches: List<ToTBranch>, threshold: Int): List<ToTBranch> {
    return branches
        .map { it withEvaluation(quickEvaluate(it)) }
        .filter { it.evaluation.totalScore >= threshold }
}
```

### Pattern 3: Branch Selection Heuristics

```kotlin
// Choose based on team expertise
fun selectByTeamExpertise(
    branches: List<ToTBranch>,
    expertise: Map<String, Double>
): ToTBranch {
    return branches.maxByOrNull { branch ->
        branch.evaluation.totalScore * expertise[branch.name] ?: 0.0
    } ?: branches.first()
}
```

## Integration with MCP

```kotlin
class McpToTProvider {
    fun getContextForToT(problem: String): ToTContext {
        return ToTContext(
            problem = problem,
            domainKnowledge = loadDomainKnowledge(problem),
            constraints = loadConstraints(problem),
            alternatives = loadAlternativeApproaches(problem),
            examples = loadSuccessExamples(problem),
            metrics = loadPerformanceMetrics(problem)
        )
    }
}

data class ToTContext(
    val problem: String,
    val domainKnowledge: List<String>,
    val constraints: List<String>,
    val alternatives: List<String>,
    val examples: List<String>,
    val metrics: PerformanceMetrics
)
```

## Troubleshooting

### Branches Not Diverging

**Problem:** All branches are too similar

**Solution:**
- Use domain-specific prompts
- Enforce diversity in generation
- Include contrarian viewpoints
- Reference competitive alternatives

### Too Many Branches

**Problem:** Decision paralysis

**Solution:**
- Set hard limit on branch count (5-7)
- Apply aggressive pruning
- Focus on critical branches
- Use heuristics for initial selection

### Evaluation Inconsistent

**Problem:** Scores vary widely between raters

**Solution:**
- Standardize evaluation criteria
- Use reference examples
- Provide clear scoring rubrics
- Consider using LLM for standardization

### Time-Consuming

**Problem:** ToT takes too long

**Solution:**
- Reduce branch count
- Limit exploration depth
- Use faster LLM model
- Cache evaluations
- Pre-select promising branches

## Summary

Tree-of-Thoughts (ToT) provides:
- **Structured exploration** of multiple solution paths
- **Transparent decision-making** with visual representation
- **Systematic evaluation** of alternatives
- **Flexible integration** with other patterns (ReAct, RAG, etc.)
- **Real-world applicability** across many domains

By complementing ReAct's linear approach with ToT's branching exploration, agents can make better decisions in complex, uncertain situations while maintaining transparency and traceability.

---

*End of tree-of-thoughts skill*
