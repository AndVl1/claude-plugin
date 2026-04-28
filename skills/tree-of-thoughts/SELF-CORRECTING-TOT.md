# Self-Correcting Tree-of-Thoughts (SC-ToT)

## Purpose

Enhances Tree-of-Thoughts with self-correction loops and memory integration, enabling agents to learn from decisions, adapt based on outcomes, and improve future reasoning.

## What's New

**Self-Correction Loops:**
- Automatic identification of flawed reasoning
- Correction mechanisms after execution
- Post-execution evaluation and adaptation

**Memory Integration:**
- Learn from successful/corrupted decisions
- Reference past decisions for similar problems
- Adaptive evaluation criteria based on outcomes

**Beads Pattern:**
- Modular correction components
- Chain of responsibility for correction actions
- Reusable correction strategies

## Architecture

```
┌─────────────────────────────────────────┐
│           ToT Decision Engine            │
│  (Tree-of-Thoughts + Self-Correction)    │
└─────────────────────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
┌─────────┐ ┌─────────┐ ┌─────────┐
│ Reason  │ │ Execute │ │ Evaluate│
│ Branch  │ │ Branch  │ │ Branch  │
└─────────┘ └─────────┘ └─────────┘
    │             │             │
    └─────────────┼─────────────┘
                  │
    ┌─────────────▼─────────────┐
    │    Memory Integration      │
    │  (Learn from outcomes)     │
    └───────────────────────────┘
```

## Self-Correction Loop

### The Loop

```
1. Generate Branches
   ↓
2. Explore Branches (Reason + Act)
   ↓
3. Execute Selected Branch
   ↓
4. Evaluate Results
   ↓
5. Identify Errors
   ↓
6. Apply Corrections
   ↓
7. Learn from Outcome (Memory)
   ↓
8. Repeat for complex problems
```

### Example

```kotlin
class SelfCorrectingToT {
    data class DecisionOutcome(
        val branchId: String,
        val selected: Boolean,
        val success: Boolean,
        val errors: List<String>,
        val metrics: Map<String, Any>,
        val learnedInsights: List<String>
    )

    suspend fun makeDecision(
        problem: String,
        context: Map<String, Any>,
        maxIterations: Int = 3
    ): DecisionResult {
        var currentProblem = problem
        var iterations = 0
        var totalLearnedInsights = emptyList<String>()

        while (iterations < maxIterations) {
            iterations++

            // 1. Generate branches
            val branches = generateBranches(currentProblem)

            // 2. Explore branches
            branches.forEach { exploreBranch(it) }

            // 3. Select and execute branch
            val selectedBranch = selectBestBranch(branches)
            val outcome = executeBranch(selectedBranch, context)

            // 4. Evaluate outcome
            val evaluation = evaluateOutcome(outcome)

            // 5. Apply corrections if needed
            if (evaluation.needsCorrection) {
                totalLearnedInsights += evaluation.correctedInsights

                // Learn from outcome
                memoryStore.store(
                    key = "decision:${problem}:${System.currentTimeMillis()}",
                    value = outcome,
                    partition = 'decisionHistory',
                    metadata = mapOf(
                        'branchId' to selectedBranch.id,
                        'success' to outcome.success,
                        'iterations' to iterations
                    )
                )

                // Update context for next iteration
                currentProblem = outcome.feedback
            } else {
                // Success - learn and exit
                totalLearnedInsights += evaluation.successInsights
                break
            }
        }

        return DecisionResult(
            finalBranch = selectedBranch,
            iterations = iterations,
            learnedInsights = totalLearnedInsights,
            outcome = outcome
        )
    }

    suspend fun executeBranch(
        branch: ToTBranch,
        context: Map<String, Any>
    ): DecisionOutcome {
        val startTime = System.currentTimeMillis()

        // Execute reasoning path
        val reasoningSteps = branch.reasoningPath.mapIndexed { index, step ->
            val action = step.action ?: continue
            executeReasoningStep(step, context)
        }

        // Execute implementation
        val implementation = executeImplementation(branch, context)

        // Evaluate outcome
        val metrics = evaluateMetrics(implementation)
        val success = metrics.all { it.value >= threshold }

        val outcome = DecisionOutcome(
            branchId = branch.id,
            selected = branch.isSelected,
            success = success,
            errors = if (!success) extractErrors(implementation) else emptyList(),
            metrics = metrics,
            learnedInsights = extractInsights(implementation),
            feedback = generateFeedback(success, implementation)
        )

        return outcome
    }

    private fun evaluateOutcome(outcome: DecisionOutcome): OutcomeEvaluation {
        val needsCorrection = outcome.errors.isNotEmpty() ||
                            !outcome.success ||
                            outcome.metrics.values.any { it < threshold }

        val correctedInsights = if (needsCorrection) {
            generateCorrectedInsights(outcome)
        } else {
            emptyList()
        }

        val successInsights = if (outcome.success) {
            generateSuccessInsights(outcome)
        } else {
            emptyList()
        }

        return OutcomeEvaluation(
            needsCorrection = needsCorrection,
            correctedInsights = correctedInsights,
            successInsights = successInsights,
            confidence = calculateConfidence(outcome)
        )
    }

    private fun generateCorrectedInsights(outcome: DecisionOutcome): List<String> {
        val insights = mutableListOf<String>()

        if (outcome.errors.isNotEmpty()) {
            insights.add("Errors detected: ${outcome.errors.joinToString(", ")}")
        }

        if (!outcome.success) {
            insights.add("Branch evaluation was incorrect - need to adjust evaluation criteria")
            insights.add("Consider exploring alternative approaches")
        }

        return insights
    }

    private fun generateSuccessInsights(outcome: DecisionOutcome): List<String> {
        val insights = mutableListOf<String>()

        if (outcome.success) {
            insights.add("Decision was correct - reinforce this pattern")
            insights.add("Use similar reasoning for future similar problems")

            // Store successful decision in memory
            memoryStore.store(
                key = "decision:${outcome.branchId}:${System.currentTimeMillis()}",
                value = outcome,
                partition = 'successDecisions',
                metadata = mapOf(
                    'problem' to outcome.branchId,
                    'success' to true
                )
            )
        }

        return insights
    }

    private fun calculateConfidence(outcome: DecisionOutcome): Double {
        val baseConfidence = if (outcome.success) 0.9 else 0.3
        val errorFactor = outcome.errors.size * 0.1
        val metricFactor = outcome.metrics.values.sum() / outcome.metrics.size.toDouble()

        return maxOf(0.0, baseConfidence - errorFactor + metricFactor)
    }
}

data class OutcomeEvaluation(
    val needsCorrection: Boolean,
    val correctedInsights: List<String>,
    val successInsights: List<String>,
    val confidence: Double
)

data class DecisionResult(
    val finalBranch: ToTBranch,
    val iterations: Int,
    val learnedInsights: List<String>,
    val outcome: DecisionOutcome
)
```

## Memory Integration

### Learning from Decisions

```kotlin
class MemoryIntegratedToT {
    private val memoryStore = RedisMemoryStore()

    suspend fun makeDecisionWithMemory(
        problem: String,
        context: Map<String, Any>
    ): DecisionResult {
        // Retrieve similar past decisions
        val similarDecisions = memoryStore.search(
            query = problem,
            partition = 'decisionHistory',
            topK = 5
        )

        // Learn from similar decisions
        val learnedPatterns = extractPatterns(similarDecisions)

        // Adjust evaluation criteria based on learned patterns
        val adaptedCriteria = adaptEvaluationCriteria(learnedPatterns)

        // Generate branches with learned context
        val branches = generateBranches(problem, context, adaptedCriteria)

        // Execute and learn
        return executeWithLearning(branches, context, problem)
    }

    private fun extractPatterns(decisions: List<Any>): LearnedPatterns {
        val patterns = LearnedPatterns()

        decisions.forEach { decision ->
            if (decision.success) {
                patterns.successfulApproaches.add(decision.branchId)
            } else {
                patterns.failedApproaches.add(decision.branchId)
            }
        }

        return patterns
    }

    private fun adaptEvaluationCriteria(patterns: LearnedPatterns): EvaluationCriteria {
        val criteria = EvaluationCriteria()

        // Adjust based on success rates
        if (patterns.successfulApproaches.isNotEmpty()) {
            criteria.threshold += 0.5 // Increase threshold for known good approaches
        }

        if (patterns.failedApproaches.isNotEmpty()) {
            criteria.weightage['complexity'] *= 1.5 // Increase weight on complexity
        }

        return criteria
    }
}

data class LearnedPatterns(
    val successfulApproaches: List<String> = emptyList(),
    val failedApproaches: List<String> = emptyList(),
    val averageSuccessRate: Double = 0.0
)

data class EvaluationCriteria(
    var threshold: Double = 0.5,
    var weightage: Map<String, Double> = mapOf(
        'effort' to 0.2,
        'impact' to 0.25,
        'complexity' to 0.15,
        'maintainability' to 0.2,
        'rollbackRisk' to 0.2
    )
)
```

## Beads Pattern for Corrections

```kotlin
interface CorrectionBead {
    val name: String
    fun canHandle(error: String): Boolean
    fun apply(correctionContext: CorrectionContext): CorrectionResult
}

class ValidationBead : CorrectionBead {
    override val name = "Validation"
    override fun canHandle(error: String): Boolean {
        return error.contains("invalid") || error.contains("fail") || error.contains("error")
    }

    override fun apply(context: CorrectionContext): CorrectionResult {
        return if (context.validated) {
            CorrectionResult(successful = true, message = "Validation passed")
        } else {
            CorrectionResult(
                successful = false,
                message = "Validation failed",
                nextBead = ValidationBead()
            )
        }
    }
}

class RetryBead : CorrectionBead {
    override val name = "Retry"
    override fun canHandle(error: String): Boolean {
        return error.contains("timeout") || error.contains("network") || error.contains("temporal")
    }

    override fun apply(context: CorrectionContext): CorrectionResult {
        val retryCount = context.retryCount + 1

        return if (retryCount < 3) {
            CorrectionResult(
                successful = true,
                message = "Retrying... (attempt $retryCount/3)",
                retryCount = retryCount,
                nextBead = RetryBead()
            )
        } else {
            CorrectionResult(
                successful = false,
                message = "Max retries reached",
                nextBead = ValidationBead()
            )
        }
    }
}

class AlternativeApproachBead : CorrectionBead {
    override val name = "Alternative"
    override fun canHandle(error: String): Boolean {
        return error.contains("unsolvable") || error.contains("impossible")
    }

    override fun apply(context: CorrectionContext): CorrectionResult {
        val alternative = generateAlternativeApproach(context)

        return CorrectionResult(
            successful = true,
            message = "Switching to alternative approach",
            alternativeBranch = alternative
        )
    }
}

class AdaptiveCorrectionChain {
    private val beads = listOf(
        RetryBead(),
        ValidationBead(),
        AlternativeApproachBead()
    )

    fun applyCorrection(error: String, context: CorrectionContext): CorrectionResult {
        return beads.firstNotNullOf { bead ->
            if (bead.canHandle(error)) {
                bead.apply(context)
            } else {
                null
            }
        }
    }
}

data class CorrectionContext(
    val originalError: String,
    val retryCount: Int = 0,
    val validated: Boolean = false,
    val context: Map<String, Any> = emptyMap()
)

data class CorrectionResult(
    val successful: Boolean,
    val message: String,
    val retryCount: Int? = null,
    val nextBead: CorrectionBead? = null,
    val alternativeBranch: ToTBranch? = null
)
```

## Visualizing Self-Correction

```kotlin
class ToTVisualizer {
    fun visualizeToTWithCorrection(
        problem: String,
        outcome: DecisionResult
    ): MermaidDiagram {
        val lines = mutableListOf()

        lines.add("graph TD")
        lines.add("    A[${problem}]")
        lines.add("    A --> B{Generate Branches}")
        lines.add("    B --> C[Explore Branch 1]")
        lines.add("    C --> D{Evaluate}")

        if (outcome.outcome.errors.isNotEmpty()) {
            lines.add("    D --> E{Needs Correction?}")
            lines.add("    E -->|Yes| F[Apply Corrections]")
            lines.add("    F --> C")
            lines.add("    E -->|No| G[Execute]")
        } else {
            lines.add("    D --> G[Execute]")
        }

        lines.add("    G --> H{Success?}")
        lines.add("    H -->|Yes| I[Learn & Exit]")
        lines.add("    H -->|No| J[Identify Errors]")
        lines.add("    J --> K[Learn]")
        lines.add("    K --> C")

        lines.add("    I --> L[Visualization Complete]")
        lines.add("    style I fill:#52c41a,stroke:#389e0d")

        return MermaidDiagram(lines.joinToString("\n"))
    }
}
```

## Configuration

```kotlin
data class SelfCorrectingToTConfig(
    val maxIterations: Int = 3,
    val correctionThreshold: Double = 0.5,
    val memoryRetention: Int = 100,
    val enableVisualization: Boolean = true,
    val correctionBeads: List<CorrectionBead> = listOf(
        RetryBead(),
        ValidationBead(),
        AlternativeApproachBead()
    ),
    val evaluationWeights: EvaluationCriteria = EvaluationCriteria()
)
```

## Integration with Existing ToT

```kotlin
class ToTIntegration {
    fun integrateSCToT(
        existingToT: TreeOfThoughts,
        config: SelfCorrectingToTConfig
    ): SelfCorrectingToT {
        val tot = SelfCorrectingToT()

        // Use existing branch generation
        tot.generateBranches = existingToT::generateBranches

        // Use existing exploration
        tot.exploreBranch = existingToT::exploreBranch

        // Add self-correction
        tot.correctExecution = { outcome ->
            // Self-correction logic
        }

        // Add memory integration
        tot.memoryIntegration = { problem, context ->
            // Memory logic
        }

        return tot
    }
}
```

## Performance Considerations

### Optimization Strategies

1. **Limit Corrections**
   - Max 2-3 iterations
   - Fast feedback loops

2. **Caching Corrections**
   - Cache successful corrections
   - Reuse for similar problems

3. **Selective Memory**
   - Only store significant decisions
   - Use memory compression

4. **Bead Parallelism**
   - Execute beads in parallel when possible
   - Async correction chains

### Metrics

```
✓ Average iterations before success
✓ Correction success rate
✓ Memory hit rate
✓ Learning efficiency
✓ Time complexity: O(n × m) where n=branches, m=iterations
```

## Best Practices

1. **Start Simple**
   - Begin with single iteration
   - Add corrections if needed

2. **Progressive Complexity**
   - Increase correction depth as needed
   - Learn from failures

3. **Memory Management**
   - Use memory partitions effectively
   - Implement retention policies

4. **Visualization**
   - Use visualizations for debugging
   - Share with humans for validation

## Use Cases

### Use Case 1: Complex Architecture Decision

```kotlin
suspend fun decideArchitecture(
    project: Project,
    teamExperience: TeamExperience
): ArchitectureDecision {
    val config = SelfCorrectingToTConfig(
        maxIterations = 3,
        enableVisualization = true
    )

    val tot = SelfCorrectingToT(config)

    val decision = tot.makeDecisionWithMemory(
        problem = "Choose architecture for ${project.name}",
        context = mapOf(
            'project' to project,
            'team' to teamExperience,
            'constraints' to project.constraints
        )
    )

    return ArchitectureDecision(
        approach = decision.finalBranch.name,
        iterations = decision.iterations,
        insights = decision.learnedInsights,
        visualization = if (config.enableVisualization) {
            tot.visualizeToTWithCorrection(problem, decision)
        } else null
    )
}
```

### Use Case 2: Debugging Complex Issues

```kotlin
suspend fun debugPerformanceIssue(
    issue: PerformanceIssue,
    system: System
): DebugSolution {
    val config = SelfCorrectingToTConfig(
        maxIterations = 2,
        correctionThreshold = 0.7
    )

    val tot = SelfCorrectingToT(config)

    val solution = tot.makeDecisionWithMemory(
        problem = "Debug ${issue.description}",
        context = mapOf(
            'issue' to issue,
            'system' to system
        )
    )

    return DebugSolution(
        diagnosis = solution.finalBranch.name,
        corrections = solution.outcome.errors,
        learned = solution.learnedInsights
    )
}
```

---

*Last updated: 2026-04-24*
