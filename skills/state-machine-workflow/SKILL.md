# state-machine-workflow Skill

**Pattern:** GoT (Graph of Thoughts)

**Purpose:** Implement graph-of-thought workflows with explicit state transitions.

**Author:** Klavdii R&D
**Version:** 1.0.0

---

## Overview

The GoT (Graph of Thoughts) pattern enables complex workflows through explicit state machines with defined transitions. Each workflow has:
- **States**: Clear phases or stages in the process
- **Transitions**: Rules for moving between states
- **Conditions**: Validations before allowing transitions
- **Actions**: Operations performed during transitions

This pattern is particularly valuable for:
- Complex feature development with branching decisions
- Multi-phase research with parallel tracks
- Code review workflows with manual approvals
- Testing workflows with pass/fail/fix loops
- Approval-based workflows

---

## Core Concept

```
State 1 → Transition 1 → State 2
  ↓              ↓
  └─ Condition 1 ─→ Transition 2 → State 3
```

**Key Elements:**
- **State**: Current phase in the workflow
- **Transition**: Move from one state to another
- **Condition**: Validation before transition
- **Action**: Operation performed during transition
- **Guard**: Prevents invalid transitions

---

## State Machine Implementation

```kotlin
// Define state enum
enum class WorkflowState {
    INIT,
    ANALYZING,
    DESIGNED,
    IMPLEMENTING,
    REVIEWING,
    TESTING,
    APPROVED,
    FINALIZED
}

// Define transition interface
sealed class WorkflowTransition {
    abstract val from: WorkflowState
    abstract val to: WorkflowState
    abstract val condition: WorkflowCondition
    abstract val action: suspend (Context) -> Result

    data class StandardTransition(
        override val from: WorkflowState,
        override val to: WorkflowState,
        override val condition: WorkflowCondition,
        override val action: suspend (Context) -> Result
    ) : WorkflowTransition()

    data class ConditionalTransition(
        override val from: WorkflowState,
        override val to: WorkflowState,
        override val condition: WorkflowCondition,
        override val action: suspend (Context) -> Result
    ) : WorkflowTransition()
}

// Define transition condition
typealias WorkflowCondition = suspend (Context) -> Boolean

// Define workflow context
data class WorkflowContext(
    val state: WorkflowState,
    val data: MutableMap<String, Any>,
    val metadata: MutableMap<String, Any>,
    val error: Error? = null
)

// Define workflow error
data class Error(
    val message: String,
    val state: WorkflowState? = null,
    val cause: Throwable? = null
)

// Define workflow result
sealed class WorkflowResult {
    data class Success(val context: WorkflowContext) : WorkflowResult()
    data class Error(val error: Error) : WorkflowResult()
    data class Canceled(val message: String) : WorkflowResult()
    data class Blocked(val reason: String) : WorkflowResult()
}

// Define state machine
class StateMachine(
    private val transitions: List<WorkflowTransition>
) {
    private var currentContext: WorkflowContext? = null

    suspend fun execute(initialState: WorkflowState): WorkflowResult {
        currentContext = WorkflowContext(
            state = initialState,
            data = mutableMapOf(),
            metadata = mutableMapOf()
        )

        while (true) {
            val context = currentContext ?: return WorkflowResult.Error(
                Error("No context available")
            )

            val transition = findTransition(context.state)
                ?: return WorkflowResult.Canceled("No transition from ${context.state}")

            // Check condition
            if (!transition.condition(context)) {
                return WorkflowResult.Blocked(transition.reason ?: "Transition not allowed")
            }

            // Execute action
            val result = transition.action(context)
            if (result is Result.Error) {
                return WorkflowResult.Error(
                    Error(result.message, context.state, result.cause)
                )
            }

            // Update state
            context.state = transition.to

            // Check if final state
            if (transition.to == getFinalState()) {
                return WorkflowResult.Success(context)
            }
        }
    }

    private fun findTransition(fromState: WorkflowState): WorkflowTransition? {
        return transitions.find { it.from == fromState }
    }

    private fun getFinalState(): WorkflowState = FINAL_STATES.first()

    companion object {
        private val FINAL_STATES = setOf(
            WorkflowState.FINALIZED,
            WorkflowState.APPROVED
        )
    }
}

// Result type
sealed class Result {
    data class Success(val context: WorkflowContext) : Result()
    data class Error(val message: String, val cause: Throwable? = null) : Result()
}
```

---

## Feature Development State Machine

```kotlin
/**
 * Feature Development Workflow
 *
 * States:
 * 1. INIT - Feature idea received
 * 2. ANALYZING - Requirements analysis
 * 3. DESIGNED - Architecture designed
 * 4. IMPLEMENTING - Code written
 * 5. REVIEWING - Code review in progress
 * 6. TESTING - Testing phase
 * 7. APPROVED - Ready for merge
 * 8. FINALIZED - Merged and deployed
 */

class FeatureDevelopmentStateMachine(
    private val developerSkill: DeveloperSkill,
    private val qaSkill: QASkill,
    private val workflowOrchestrator: WorkflowOrchestrator
) : StateMachine(buildFeatureTransitions()) {

    // Build transitions
    private fun buildFeatureTransitions(): List<WorkflowTransition> {
        return listOf(
            // INIT → ANALYZING
            WorkflowTransition.StandardTransition(
                from = WorkflowState.INIT,
                to = WorkflowState.ANALYZING,
                condition = { ctx -> ctx.metadata["requirementsReceived"] == true },
                action = { ctx ->
                    // Analyze requirements
                    val analysis = workflowOrchestrator.analyzeRequirements(ctx.data)
                    ctx.data["requirementsAnalysis"] = analysis
                    Result.Success(ctx.copy(state = WorkflowState.ANALYZING))
                }
            ),

            // ANALYZING → DESIGNED
            WorkflowTransition.StandardTransition(
                from = WorkflowState.ANALYZING,
                to = WorkflowState.DESIGNED,
                condition = { ctx -> ctx.data["requirementsApproved"] == true },
                action = { ctx ->
                    // Design architecture
                    val design = workflowOrchestrator.designArchitecture(ctx.data)
                    ctx.data["architecture"] = design
                    Result.Success(ctx.copy(state = WorkflowState.DESIGNED))
                }
            ),

            // DESIGNED → IMPLEMENTING
            WorkflowTransition.StandardTransition(
                from = WorkflowState.DESIGNED,
                to = WorkflowState.IMPLEMENTING,
                condition = { ctx -> ctx.data["designApproved"] == true },
                action = { ctx ->
                    // Implement feature
                    val implementation = developerSkill.implementFeature(ctx.data)
                    ctx.data["implementation"] = implementation
                    Result.Success(ctx.copy(state = WorkflowState.IMPLEMENTING))
                }
            ),

            // IMPLEMENTING → REVIEWING
            WorkflowTransition.StandardTransition(
                from = WorkflowState.IMPLEMENTING,
                to = WorkflowState.REVIEWING,
                condition = { ctx -> ctx.data["implementationComplete"] == true },
                action = { ctx ->
                    // Trigger code review
                    Result.Success(ctx.copy(state = WorkflowState.REVIEWING))
                }
            ),

            // REVIEWING → TESTING
            WorkflowTransition.StandardTransition(
                from = WorkflowState.REVIEWING,
                to = WorkflowState.TESTING,
                condition = { ctx -> ctx.data["reviewApproved"] == true },
                action = { ctx ->
                    // Start testing
                    Result.Success(ctx.copy(state = WorkflowState.TESTING))
                }
            ),

            // TESTING → APPROVED
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.TESTING,
                to = WorkflowState.APPROVED,
                condition = { ctx ->
                    ctx.data["testsPassed"] == true && ctx.data["allRequirementsMet"] == true
                },
                action = { ctx ->
                    Result.Success(ctx.copy(state = WorkflowState.APPROVED))
                }
            ),

            // TESTING → FINALIZED (if approved by stakeholder)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.TESTING,
                to = WorkflowState.FINALIZED,
                condition = { ctx -> ctx.data["stakeholderApproved"] == true },
                action = { ctx ->
                    // Merge and deploy
                    val merge = developerSkill.mergeAndDeploy(ctx.data)
                    ctx.data["deploymentUrl"] = merge.url
                    Result.Success(ctx.copy(state = WorkflowState.FINALIZED))
                }
            ),

            // REVIEWING → IMPLEMENTING (if revision needed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.REVIEWING,
                to = WorkflowState.IMPLEMENTING,
                condition = { ctx -> ctx.data["revisionRequested"] == true },
                action = { ctx ->
                    // Apply revisions
                    val revisions = developerSkill.applyRevisions(ctx.data)
                    ctx.data["revisionsApplied"] = revisions
                    Result.Success(ctx.copy(state = WorkflowState.IMPLEMENTING))
                }
            ),

            // TESTING → IMPLEMENTING (if tests failed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.TESTING,
                to = WorkflowState.IMPLEMENTING,
                condition = { ctx -> ctx.data["testsFailed"] == true },
                action = { ctx ->
                    // Fix bugs
                    val fixes = developerSkill.fixBugs(ctx.data)
                    ctx.data["bugsFixed"] = fixes
                    Result.Success(ctx.copy(state = WorkflowState.IMPLEMENTING))
                }
            ),

            // APPROVED → FINALIZED (if merge successful)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.APPROVED,
                to = WorkflowState.FINALIZED,
                condition = { ctx -> ctx.data["mergeSuccessful"] == true },
                action = { ctx ->
                    // Deploy
                    val deployment = workflowOrchestrator.deploy(ctx.data)
                    ctx.data["deploymentUrl"] = deployment.url
                    Result.Success(ctx.copy(state = WorkflowState.FINALIZED))
                }
            )
        )
    }
}
```

---

## Testing Workflow State Machine

```kotlin
/**
 * Testing Workflow
 *
 * States:
 * 1. INIT - Test plan created
 * 2. UNIT_TESTING - Unit tests running
 * 3. INTEGRATION_TESTING - Integration tests running
 * 4. E2E_TESTING - End-to-end tests running
 * 5. APPROVED - All tests passed
 * 6. FINALIZED - Tests verified
 */

class TestingStateMachine(
    private val unitTestRunner: UnitTestRunner,
    private val integrationTestRunner: IntegrationTestRunner,
    private val e2eTestRunner: E2ETestRunner
) : StateMachine(buildTestTransitions()) {

    private fun buildTestTransitions(): List<WorkflowTransition> {
        return listOf(
            // INIT → UNIT_TESTING
            WorkflowTransition.StandardTransition(
                from = WorkflowState.INIT,
                to = WorkflowState.UNIT_TESTING,
                condition = { ctx -> true },
                action = { ctx ->
                    val results = unitTestRunner.runTests(ctx.data["codeBase"])
                    ctx.data["unitTestResults"] = results
                    Result.Success(ctx.copy(state = WorkflowState.UNIT_TESTING))
                }
            ),

            // UNIT_TESTING → INTEGRATION_TESTING (if passed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.UNIT_TESTING,
                to = WorkflowState.INTEGRATION_TESTING,
                condition = { ctx ->
                    val results = ctx.data["unitTestResults"] as TestResults
                    results.passed && results.failed == 0
                },
                action = { ctx ->
                    val results = integrationTestRunner.runTests(ctx.data["codeBase"])
                    ctx.data["integrationTestResults"] = results
                    Result.Success(ctx.copy(state = WorkflowState.INTEGRATION_TESTING))
                }
            ),

            // UNIT_TESTING → FINALIZED (if failed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.UNIT_TESTING,
                to = WorkflowState.FINALIZED,
                condition = { ctx ->
                    val results = ctx.data["unitTestResults"] as TestResults
                    results.failed > 0
                },
                action = { ctx ->
                    ctx.data["testStatus"] = "FAILED - Unit tests failed"
                    Result.Success(ctx.copy(state = WorkflowState.FINALIZED))
                }
            ),

            // INTEGRATION_TESTING → E2E_TESTING (if passed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.INTEGRATION_TESTING,
                to = WorkflowState.E2E_TESTING,
                condition = { ctx ->
                    val results = ctx.data["integrationTestResults"] as TestResults
                    results.passed && results.failed == 0
                },
                action = { ctx ->
                    val results = e2eTestRunner.runTests(ctx.data["codeBase"])
                    ctx.data["e2eTestResults"] = results
                    Result.Success(ctx.copy(state = WorkflowState.E2E_TESTING))
                }
            ),

            // INTEGRATION_TESTING → FINALIZED (if failed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.INTEGRATION_TESTING,
                to = WorkflowState.FINALIZED,
                condition = { ctx ->
                    val results = ctx.data["integrationTestResults"] as TestResults
                    results.failed > 0
                },
                action = { ctx ->
                    ctx.data["testStatus"] = "FAILED - Integration tests failed"
                    Result.Success(ctx.copy(state = WorkflowState.FINALIZED))
                }
            ),

            // E2E_TESTING → APPROVED (if passed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.E2E_TESTING,
                to = WorkflowState.APPROVED,
                condition = { ctx ->
                    val results = ctx.data["e2eTestResults"] as TestResults
                    results.passed && results.failed == 0
                },
                action = { ctx ->
                    ctx.data["testStatus"] = "PASSED - All tests passed"
                    Result.Success(ctx.copy(state = WorkflowState.APPROVED))
                }
            ),

            // E2E_TESTING → FINALIZED (if failed)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.E2E_TESTING,
                to = WorkflowState.FINALIZED,
                condition = { ctx ->
                    val results = ctx.data["e2eTestResults"] as TestResults
                    results.failed > 0
                },
                action = { ctx ->
                    ctx.data["testStatus"] = "FAILED - E2E tests failed"
                    Result.Success(ctx.copy(state = WorkflowState.FINALIZED))
                }
            )
        )
    }
}

// Test results data class
data class TestResults(
    val passed: Int,
    val failed: Int,
    val skipped: Int,
    val durationMs: Long,
    val errors: List<Error> = emptyList()
)

// Error data class
data class Error(
    val message: String,
    val location: String,
    val stackTrace: List<String> = emptyList()
)
```

---

## Visualization

### Mermaid Diagram

```mermaid
stateDiagram-v2
    [*] --> INIT

    INIT --> ANALYZING
    ANALYZING --> DESIGNED
    DESIGNED --> IMPLEMENTING
    IMPLEMENTING --> REVIEWING
    REVIEWING --> TESTING
    TESTING --> APPROVED
    APPROVED --> FINALIZED

    REVIEWING -. revision .-> IMPLEMENTING
    TESTING -. fail .-> IMPLEMENTING
    REVIEWING -. reject .-> INIT
    TESTING -. fail .-> FINALIZED

    FINALIZED --> [*]
    APPROVED --> [*]
```

### State Flow Diagram

```kotlin
/**
 * State flow diagram
 */
class StateFlowDiagram {
    fun generateDiagram(stateMachine: StateMachine): String {
        return """
            State Machine: ${stateMachine::class.simpleName}
            ===================

            States:
            ${stateMachine.getStates().joinToString("\n  ") { "  - ${it.name}" }}

            Transitions:
            ${stateMachine.getTransitions().joinToString("\n") { transition ->
                "  ${transition.from.name} → ${transition.to.name} (${transition.condition})"
            }}

            Final States:
            ${stateMachine.getFinalStates().joinToString("\n  ") { "  - ${it.name}" }}
        """.trimIndent()
    }
}
```

---

## Advanced Patterns

### Parallel States

```kotlin
/**
 * Workflow with parallel states
 */
class ParallelWorkflowStateMachine : StateMachine(buildParallelTransitions()) {

    private fun buildParallelTransitions(): List<WorkflowTransition> {
        return listOf(
            // START → PARALLEL_ANALYSIS (two parallel tracks)
            WorkflowTransition.StandardTransition(
                from = WorkflowState.INIT,
                to = WorkflowState.PARALLEL_ANALYSIS,
                condition = { ctx -> true },
                action = { ctx ->
                    // Launch parallel analysis tracks
                    ctx.data["track1Results"] = "Analyzed requirements"
                    ctx.data["track2Results"] = "Analyzed architecture"
                    Result.Success(ctx.copy(state = WorkflowState.PARALLEL_ANALYSIS))
                }
            ),

            // PARALLEL_ANALYSIS → MERGE_RESULTS (wait for both tracks)
            WorkflowTransition.ConditionalTransition(
                from = WorkflowState.PARALLEL_ANALYSIS,
                to = WorkflowState.MERGED_RESULTS,
                condition = { ctx ->
                    ctx.data["track1Completed"] == true && ctx.data["track2Completed"] == true
                },
                action = { ctx ->
                    ctx.data["mergedResults"] = mergeTracks(ctx.data)
                    Result.Success(ctx.copy(state = WorkflowState.MERGED_RESULTS))
                }
            ),

            // MERGED_RESULTS → DECISION
            WorkflowTransition.StandardTransition(
                from = WorkflowState.MERGED_RESULTS,
                to = WorkflowState.DECISION,
                condition = { ctx -> true },
                action = { ctx ->
                    Result.Success(ctx.copy(state = WorkflowState.DECISION))
                }
            )
        )
    }

    private fun mergeTracks(data: Map<String, Any>): String {
        // Merge results from parallel tracks
        return "Merged results from both tracks"
    }
}

// Parallel states enum
enum class ParallelWorkflowState {
    INIT,
    PARALLEL_ANALYSIS,
    MERGED_RESULTS,
    DECISION,
    IMPLEMENTING,
    REVIEWING,
    TESTING,
    APPROVED,
    FINALIZED
}
```

### Sub-workflows

```kotlin
/**
 * Workflow with sub-workflows
 */
class SubWorkflowStateMachine : StateMachine(buildSubWorkflowTransitions()) {

    private fun buildSubWorkflowTransitions(): List<WorkflowTransition> {
        return listOf(
            // START → FEATURE_ANALYSIS
            WorkflowTransition.StandardTransition(
                from = WorkflowState.INIT,
                to = WorkflowState.FEATURE_ANALYSIS,
                condition = { ctx -> true },
                action = { ctx ->
                    // Feature analysis sub-workflow
                    val subResult = runSubWorkflow(
                        "Feature Analysis",
                        listOf(
                            "Requirements Review",
                            "Technical Feasibility",
                            "Risk Assessment"
                        )
                    )
                    ctx.data["featureAnalysis"] = subResult
                    Result.Success(ctx.copy(state = WorkflowState.FEATURE_ANALYSIS))
                }
            ),

            // FEATURE_ANALYSIS → DESIGN
            WorkflowTransition.StandardTransition(
                from = WorkflowState.FEATURE_ANALYSIS,
                to = WorkflowState.DESIGN,
                condition = { ctx -> ctx.data["featureAnalysisApproved"] == true },
                action = { ctx ->
                    Result.Success(ctx.copy(state = WorkflowState.DESIGN))
                }
            )
        )
    }

    private suspend fun runSubWorkflow(
        name: String,
        steps: List<String>
    ): String {
        // Execute sub-workflow with its own state machine
        return "$name completed with steps: ${steps.joinToString(", ")}"
    }
}

// Sub-workflow states
enum class SubWorkflowState {
    INIT,
    RUNNING,
    APPROVED,
    REJECTED
}
```

### State Persistence

```kotlin
/**
 * State machine with persistence
 */
class PersistentStateMachine(
    private val stateMachine: StateMachine,
    private val storage: StateStorage
) : StateMachine(stateMachine.transitions) {

    override suspend fun execute(initialState: WorkflowState): WorkflowResult {
        // Load from storage if exists
        val loadedState = storage.load()
        if (loadedState != null) {
            currentContext = loadedState
        } else {
            currentContext = WorkflowContext(
                state = initialState,
                data = mutableMapOf(),
                metadata = mutableMapOf()
            )
        }

        while (true) {
            val context = currentContext ?: return WorkflowResult.Error(
                Error("No context available")
            )

            val transition = findTransition(context.state)
                ?: return WorkflowResult.Canceled("No transition from ${context.state}")

            if (!transition.condition(context)) {
                return WorkflowResult.Blocked(transition.reason ?: "Transition not allowed")
            }

            val result = transition.action(context)
            if (result is Result.Error) {
                return WorkflowResult.Error(
                    Error(result.message, context.state, result.cause)
                )
            }

            context.state = transition.to
            storage.save(context) // Persist state

            if (transition.to == getFinalState()) {
                return WorkflowResult.Success(context)
            }
        }
    }
}

interface StateStorage {
    suspend fun save(context: WorkflowContext)
    suspend fun load(): WorkflowContext?
}
```

---

## Using This Skill

### When to Use

**Use state-machine-workflow for:**
- Workflows with 3+ distinct phases
- Complex approval workflows
- Workflows with conditional paths
- Long-running processes needing persistence
- Multi-team workflows

**Avoid using for:**
- Simple linear workflows
- Quick scripts
- Stateless operations

### How to Invoke

```markdown
## In Your Workflow

1. **Define States**: Enumerate all possible states
2. **Define Transitions**: Specify allowed transitions and conditions
3. **Implement Actions**: Define operations for each transition
4. **Execute Workflow**: Run state machine
5. **Monitor Progress**: Track current state and data
6. **Handle Errors**: Process errors and retry

### Example

```kotlin
// Create and execute workflow
val stateMachine = FeatureDevelopmentStateMachine(developer, qa, orchestrator)
val result = stateMachine.execute(WorkflowState.INIT)

when (result) {
    is WorkflowResult.Success -> {
        println("Feature development complete: ${result.context.state}")
        println("Deployment URL: ${result.context.data["deploymentUrl"]}")
    }
    is WorkflowResult.Error -> {
        println("Workflow failed: ${result.error.message}")
        println("Failed at state: ${result.error.state}")
    }
    is WorkflowResult.Blocked -> {
        println("Workflow blocked: ${result.reason}")
    }
}
```
```

---

## Best Practices

### 1. State Design

**Good:**
- Each state has clear purpose
- States are logically grouped
- Minimal number of states
- Easy to understand transitions

**Avoid:**
- Too many states (refine into groups)
- States with similar functions
- Unclear transition purposes

### 2. Transition Rules

**Good:**
- Clear validation conditions
- Logical flow
- Prevents invalid transitions
- Documented constraints

**Avoid:**
- Ambiguous conditions
- Invalid transitions
- Unclear validation logic

### 3. State Persistence

**Good:**
- Save state after each transition
- Load state on restart
- Handle loading errors
- Version state data

**Avoid:**
- No persistence
- Inconsistent save/load
- No error handling

### 4. Error Handling

**Good:**
- Graceful error recovery
- Clear error messages
- Error logging
- Retry mechanisms

**Avoid:**
- Silent failures
- Generic errors
- No recovery

---

## Integration with Other Skills

### With Tool Orchestration

```markdown
## Tool Chains with State Machines

State machines can orchestrate tool chains:

INIT → (run buildChain) → BUILDING
BUILDING → (run healthCheckChain) → READY
READY → (run deployChain) → DEPLOYED

Each state transition is a tool chain execution
```

### With Iterative Refinement

```markdown
## Iteration within State Machine

Within a state, use iterative-refinement:

IMPLEMENTING → (generate code) → (self-review) → (refine) → finalize

States handle overall workflow, iteration handles detailed work
```

---

## References

- **Graph of Thoughts**: Pattern for structured reasoning
- **State Machine Pattern**: Design Patterns GoF
- **Workflow Patterns**: BPMN standards

---

## Change Log

- **v1.0.0** (2026-03-07): Initial implementation
  - Complete GoT Pattern implementation
  - Feature development workflow
  - Testing workflow
  - Advanced patterns (parallel, sub-workflows, persistence)
  - Mermaid visualization support

---

## Contributing

To improve this skill:

1. Add more workflow examples
2. Document common patterns
3. Provide integration examples
4. Share performance optimization tips
