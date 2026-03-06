# tool-orchestration Skill

**Pattern:** Beads Pattern (Chain of Responsibility)

**Purpose:** Orchestrate complex sequences of tools/actions using chain-of-responsibility pattern.

**Author:** Klavdii R&D
**Version:** 1.0.0

---

## Overview

The Beads Pattern enables the orchestration of complex multi-step workflows through reusable tool chains. Each "bead" in the chain processes the result of the previous bead before passing it along, creating a clear flow of data transformation.

This pattern is particularly valuable for:
- Multi-step deployment pipelines
- Research tasks requiring multiple data sources
- Complex testing workflows
- Code analysis across multiple files
- Data processing pipelines

---

## Core Concept

```
Input → Bead 1 → Bead 2 → Bead 3 → ... → Bead N → Output
         ↓         ↓         ↓
      Process    Transform  Validate
```

Each bead:
1. **Accepts** the output from previous bead
2. **Processes** or transforms the data
3. **Validates** the result
4. **Passes** to next bead or outputs final result

---

## Tool Chain Definition

```kotlin
// Define tool chain interface
interface ToolChain<T, R> {
    suspend fun execute(input: T): Result<R>
}

// Generic chain result
sealed class Result<out T> {
    data class Success<T>(val value: T) : Result<T>()
    data class Error(val message: String, val cause: Throwable? = null) : Result<Nothing>()
}

// Example: Code Analysis Chain
data class CodeAnalysisInput(
    val file: File,
    val projectPath: String
)

data class CodeAnalysisOutput(
    val syntaxValid: Boolean,
    val complexityScore: Double,
    val issues: List<CodeIssue>,
    val coverage: Double
)

class CodeAnalysisChain(
    private val syntaxChecker: SyntaxChecker,
    private val complexityAnalyzer: ComplexityAnalyzer,
    private val issueDetector: IssueDetector
) : ToolChain<CodeAnalysisInput, CodeAnalysisOutput> {

    override suspend fun execute(input: CodeAnalysisInput): Result<CodeAnalysisOutput> {
        // Bead 1: Syntax Check
        val syntaxCheck = syntaxChecker.check(input.file)
        if (!syntaxCheck.valid) {
            return Result.Error("Syntax errors found", syntaxCheck.error)
        }

        // Bead 2: Complexity Analysis
        val complexity = complexityAnalyzer.analyze(input.file, input.projectPath)

        // Bead 3: Issue Detection
        val issues = issueDetector.detect(input.file, input.projectPath)

        // Bead 4: Calculate Coverage
        val coverage = calculateCoverage(input.file)

        return Result.Success(
            CodeAnalysisOutput(
                syntaxValid = true,
                complexityScore = complexity.score,
                issues = issues,
                coverage = coverage
            )
        )
    }
}
```

---

## Predefined Tool Chains

### Chain 1: Code Analysis → Review → Test Generation

```kotlin
/**
 * Complete code analysis and test generation chain
 */
class CodeQualityChain(
    private val syntaxChecker: SyntaxChecker,
    private val staticAnalyzer: StaticAnalyzer,
    private val complexityAnalyzer: ComplexityAnalyzer,
    private val testGenerator: TestGenerator,
    private val codeReviewer: CodeReviewer
) : ToolChain<File, TestGenerationResult> {

    data class TestGenerationResult(
        val file: File,
        val syntaxValid: Boolean,
        val issues: List<StaticIssue>,
        val complexity: ComplexityMetrics,
        val testCases: List<String>,
        val reviewComments: List<String>,
        val qualityScore: Double
    )

    override suspend fun execute(file: File): Result<TestGenerationResult> {
        // Bead 1: Syntax Check
        val syntax = syntaxChecker.check(file)
        if (!syntax.valid) {
            return Result.Error("Syntax check failed", syntax.error)
        }

        // Bead 2: Static Analysis
        val analysis = staticAnalyzer.analyze(file)

        // Bead 3: Complexity Analysis
        val complexity = complexityAnalyzer.analyze(file)

        // Bead 4: Test Generation
        val tests = testGenerator.generate(file, analysis, complexity)

        // Bead 5: Code Review
        val review = codeReviewer.review(file, analysis, tests)

        // Calculate overall quality score
        val qualityScore = calculateQualityScore(syntax, analysis, complexity, review)

        return Result.Success(
            TestGenerationResult(
                file = file,
                syntaxValid = syntax.valid,
                issues = analysis.issues,
                complexity = complexity,
                testCases = tests,
                reviewComments = review.comments,
                qualityScore = qualityScore
            )
        )
    }

    private fun calculateQualityScore(
        syntax: SyntaxResult,
        analysis: StaticAnalysisResult,
        complexity: ComplexityMetrics,
        review: CodeReviewResult
    ): Double {
        var score = 0.0

        // Syntax score (0-1)
        score += if (syntax.valid) 1.0 else 0.0

        // Issues score (fewer issues = higher score)
        score += maxOf(0.0, 1.0 - (analysis.issues.size * 0.05))

        // Complexity score (lower complexity = higher score)
        score += maxOf(0.0, 1.0 - (complexity.metrics.avgDepth * 0.1))

        // Review score (better review = higher score)
        score += minOf(1.0, review.score * 0.5)

        return score.coerceIn(0.0, 1.0)
    }
}
```

### Chain 2: API Design → Documentation → Testing

```kotlin
/**
 * Complete API design and documentation generation chain
 */
class ApiDesignChain(
    private val apiDesigner: ApiDesigner,
    private val docGenerator: DocumentationGenerator,
    private val testSuiteGenerator: TestSuiteGenerator,
    private val openApiGenerator: OpenApiGenerator
) : ToolChain<ApiRequirements, ApiDeliveryResult> {

    data class ApiDeliveryResult(
        val apiDesign: ApiDesign,
        val documentation: Documentation,
        val testSuite: List<TestCase>,
        val openApiSpec: String,
        val deploymentPlan: DeploymentPlan
    )

    override suspend fun execute(requirements: ApiRequirements): Result<ApiDeliveryResult> {
        // Bead 1: API Design
        val design = apiDesigner.design(requirements)

        // Bead 2: Documentation Generation
        val docs = docGenerator.generate(design)

        // Bead 3: Test Suite Generation
        val tests = testSuiteGenerator.generate(design, docs)

        // Bead 4: OpenAPI Spec Generation
        val openApi = openApiGenerator.generate(design)

        // Bead 5: Deployment Planning
        val deploymentPlan = createDeploymentPlan(design, docs, tests)

        return Result.Success(
            ApiDeliveryResult(
                apiDesign = design,
                documentation = docs,
                testSuite = tests,
                openApiSpec = openApi,
                deploymentPlan = deploymentPlan
            )
        )
    }

    private fun createDeploymentPlan(
        design: ApiDesign,
        docs: Documentation,
        tests: List<TestCase>
    ): DeploymentPlan {
        return DeploymentPlan(
            environment = design.environment,
            endpoints = design.endpoints.map { it.toDeploymentEndpoint() },
            documentationUrl = docs.url,
            testCoverage = tests.map { it.coverage },
            preFlightChecks = listOf("Health check", "Load test", "Security audit")
        )
    }
}
```

### Chain 3: Deployment → Health Check → Rollback

```kotlin
/**
 * Deployment pipeline with health checking and rollback
 */
class DeploymentChain(
    private val builder: DeploymentBuilder,
    private val deployer: DeploymentDeployer,
    private val healthChecker: HealthChecker,
    private val rollbackHandler: RollbackHandler
) : ToolChain<Application, DeploymentResult> {

    data class DeploymentResult(
        val application: Application,
        val build: BuildResult,
        val deployment: DeploymentResult,
        val healthCheck: HealthCheckResult,
        val success: Boolean
    )

    override suspend fun execute(application: Application): Result<DeploymentResult> {
        try {
            // Bead 1: Build & Package
            val build = builder.build(application)
            if (!build.success) {
                return Result.Error("Build failed", build.error)
            }

            // Bead 2: Deploy to Target
            val deployment = deployer.deploy(build.packagePath, application)
            if (!deployment.success) {
                return Result.Error("Deployment failed", deployment.error)
            }

            // Bead 3: Health Check
            val health = healthChecker.check(deployment.url, application.environment)

            // Bead 4: Decision & Rollback
            val result = if (health.ok) {
                DeploymentResult(
                    application = application,
                    build = build,
                    deployment = deployment,
                    healthCheck = health,
                    success = true
                )
            } else {
                // Rollback on health check failure
                rollbackHandler.rollback(deployment)
                DeploymentResult(
                    application = application,
                    build = build,
                    deployment = deployment.copy(success = false),
                    healthCheck = health,
                    success = false
                )
            }

            return Result.Success(result)
        } catch (e: Exception) {
            return Result.Error("Deployment failed", e)
        }
    }
}
```

---

## Tool Chain DSL

Define reusable chains in a dedicated file:

```kotlin
// skills/koog/tools/orchestration/ToolChain.kt

package koog.tools.orchestration

/**
 * DSL for defining tool chains
 */
class ToolChainDSL<T, R> {
    private val beads = mutableListOf<ToolBead<T, R>>()
    private var errorHandler: ((T, Exception) -> ToolBead<T, R>)? = null

    fun bead(name: String, action: suspend (T) -> Result<R>): ToolChainDSL<T, R> {
        beads.add(ToolBead(name, action))
        return this
    }

    fun errorHandler(handler: (T, Exception) -> ToolBead<T, R>): ToolChainDSL<T, R> {
        errorHandler = handler
        return this
    }

    fun build(): ToolChain<T, R> {
        return object : ToolChain<T, R> {
            override suspend fun execute(input: T): Result<R> {
                return executeBeads(input, beads)
            }
        }
    }

    private suspend fun executeBeads(
        input: T,
        beads: List<ToolBead<T, R>>,
        index: Int = 0
    ): Result<R> {
        if (index >= beads.size) {
            return Result.Error("No beads defined")
        }

        val bead = beads[index]
        return try {
            bead.action(input)
        } catch (e: Exception) {
            errorHandler?.invoke(input, e) ?: Result.Error(bead.name, e)
        }
    }
}

/**
 * Individual bead in a tool chain
 */
data class ToolBead<T, R>(
    val name: String,
    val action: suspend (T) -> Result<R>
)

// Usage Example
val analysisChain = ToolChainDSL<String, AnalysisResult>()
    .bead("Syntax Check") { input ->
        checkSyntax(input)
    }
    .bead("Static Analysis") { input ->
        analyzeStatic(input)
    }
    .bead("Complexity Check") { input ->
        analyzeComplexity(input)
    }
    .errorHandler { input, e ->
        // Custom error handling
        Result.Error("Analysis failed", e)
    }
    .build()
```

---

## Skill Integration

Add tool chain execution to skills:

```markdown
## Tool Orchestration Example

For complex deployments:

1. **Define Chain**: Use ToolChain DSL or predefined chain
2. **Execute Chain**: Call execute() method
3. **Handle Results**: Check success/failure
4. **Rollback on Error**: Trigger rollback automatically

### Example in deploy.sh

```bash
# Define chain
CHAINS=(
    "build"
    "deploy"
    "health-check"
    "monitor"
)

# Execute chain
for chain in "${CHAINS[@]}"; do
    if ! execute_chain "$chain"; then
        echo "Chain failed at step: $chain"
        trigger_rollback
        exit 1
    fi
done
```

### Example in KMP Mobile App

```kotlin
// Execute deployment chain
val result = deploymentChain.execute(application)

when (result) {
    is Result.Success -> {
        showSuccess(result.value.success)
    }
    is Result.Error -> {
        showError(result.message)
        handleRollback(result.cause)
    }
}
```

---

## Common Tool Chains

### Build & Deploy Chain

```kotlin
class BuildAndDeployChain(
    private val builder: ProjectBuilder,
    private val deployer: EnvironmentDeployer,
    private val healthChecker: HealthChecker,
    private val rollbackHandler: RollbackHandler
) : ToolChain<BuildConfig, DeploymentResult> {

    override suspend fun execute(config: BuildConfig): Result<DeploymentResult> {
        // Build
        val build = builder.build(config)
        if (!build.success) return Result.Error("Build failed", build.error)

        // Deploy
        val deploy = deployer.deploy(build.artifact, config.environment)
        if (!deploy.success) return Result.Error("Deploy failed", deploy.error)

        // Health Check
        val health = healthChecker.check(deploy.url, config.environment)
        if (!health.ok) {
            rollbackHandler.rollback(deploy)
            return Result.Error("Health check failed", health.error)
        }

        return Result.Success(DeploymentResult(
            build = build,
            deployment = deploy,
            health = health
        ))
    }
}
```

### Research Analysis Chain

```kotlin
class ResearchAnalysisChain(
    private val dataCollector: DataCollector,
    private val dataProcessor: DataProcessor,
    private val analysisEngine: AnalysisEngine,
    private val reportGenerator: ReportGenerator
) : ToolChain<ResearchRequest, ResearchReport> {

    override suspend fun execute(request: ResearchRequest): Result<ResearchReport> {
        // Collect Data
        val data = dataCollector.collect(request)
        if (!data.success) return Result.Error("Data collection failed", data.error)

        // Process Data
        val processed = dataProcessor.process(data.value)
        if (!processed.success) return Result.Error("Data processing failed", processed.error)

        // Analyze
        val analysis = analysisEngine.analyze(processed.value)
        if (!analysis.success) return Result.Error("Analysis failed", analysis.error)

        // Generate Report
        val report = reportGenerator.generate(request, analysis.value)

        return Result.Success(report)
    }
}
```

---

## Error Handling Patterns

### Continue on Error

```kotlin
/**
 * Chain that continues even if a bead fails
 */
class ContinueOnErrorChain<T, R>(
    private val beads: List<(suspend (T) -> Result<R>)>
) : ToolChain<T, List<R>> {

    override suspend fun execute(input: T): Result<List<R>> {
        val results = mutableListOf<Result<R>>()

        for (bead in beads) {
            try {
                val result = bead(input)
                results.add(result)
            } catch (e: Exception) {
                results.add(Result.Error(bead.toString(), e))
            }
        }

        return Result.Success(results.map { it.getOrNull() })
    }
}
```

### Skip Failed Beads

```kotlin
/**
 * Chain that skips beads that fail
 */
class SkipFailedChain<T, R>(
    private val beads: List<(suspend (T) -> Result<R>)>
) : ToolChain<T, List<R>> {

    override suspend fun execute(input: T): Result<List<R>> {
        val results = mutableListOf<Result<R>>()

        for (bead in beads) {
            try {
                val result = bead(input)
                if (result is Result.Success) {
                    results.add(result)
                }
                // Skip failed beads
            } catch (e: Exception) {
                // Skip and continue
            }
        }

        return if (results.all { it is Result.Success }) {
            Result.Success(results.map { (it as Result.Success).value })
        } else {
            Result.Error("Chain completed with failures", null)
        }
    }
}
```

### Parallel Beads

```kotlin
/**
 * Chain that executes beads in parallel
 */
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll

class ParallelChain<T, R>(
    private val beads: List<(suspend (T) -> Result<R>)>
) : ToolChain<T, Map<String, R>> {

    override suspend fun execute(input: T): Result<Map<String, R>> {
        return try {
            val results = beads.mapIndexed { index, bead ->
                async {
                    index to bead(input)
                }
            }.awaitAll()

            val successful = results.filter { it.second is Result.Success }
            if (successful.size == results.size) {
                Result.Success(
                    successful.associate { (index, result) ->
                        index to (result as Result.Success).value
                    }
                )
            } else {
                Result.Error("Some beads failed", null)
            }
        } catch (e: Exception) {
            Result.Error("Parallel execution failed", e)
        }
    }
}
```

---

## Advanced Patterns

### Conditional Beads

```kotlin
/**
 * Chain with conditional beads based on input
 */
class ConditionalChain<T, R>(
    private val conditionals: List<ConditionalBead<T, R>>,
    private val defaultBead: (suspend (T) -> Result<R>)? = null
) : ToolChain<T, List<R>> {

    data class ConditionalBead<T, R>(
        val condition: (T) -> Boolean,
        val bead: (suspend (T) -> Result<R>)
    )

    override suspend fun execute(input: T): Result<List<R>> {
        val results = mutableListOf<Result<R>>()

        for (conditional in conditionals) {
            if (conditional.condition(input)) {
                results.add(conditional.bead(input))
                break
            }
        }

        if (results.isEmpty() && defaultBead != null) {
            results.add(defaultBead(input))
        }

        return if (results.all { it is Result.Success }) {
            Result.Success(results.map { (it as Result.Success).value })
        } else {
            Result.Error("Chain completed with failures", null)
        }
    }
}
```

### Timeout on Beads

```kotlin
/**
 * Chain with timeout on each bead
 */
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withTimeoutOrNull

class TimeoutChain<T, R>(
    private val beads: List<(suspend (T) -> Result<R>)>,
    private val timeoutMs: Long
) : ToolChain<T, List<R>> {

    override suspend fun execute(input: T): Result<List<R>> {
        val results = mutableListOf<Result<R>>()

        for (bead in beads) {
            val result = withTimeoutOrNull(timeoutMs) {
                try {
                    bead(input)
                } catch (e: Exception) {
                    Result.Error(bead.toString(), e)
                }
            }

            results.add(result ?: Result.Error("Bead timed out", TimeoutCancellationException()))
        }

        return if (results.all { it is Result.Success }) {
            Result.Success(results.map { (it as Result.Success).value })
        } else {
            Result.Error("Chain completed with failures", null)
        }
    }
}
```

---

## Performance Considerations

### Bead Execution Order

1. **Fastest beads first**: Minimize waiting time
2. **Critical beads first**: Ensure critical steps complete
3. **Parallel beads last**: For independent operations

### Resource Management

```kotlin
/**
 * Chain with resource cleanup
 */
class ManagedChain<T, R>(
    private val beads: List<Bead<T, R>>,
    private val resourceCleaner: () -> Unit
) : ToolChain<T, R> {

    override suspend fun execute(input: T): Result<R> {
        try {
            var result: Result<R>? = null

            for (bead in beads) {
                result = bead(input)
                if (result is Result.Error) {
                    break
                }
            }

            return result ?: Result.Error("No beads defined", null)
        } finally {
            resourceCleaner()
        }
    }
}
```

### Caching Results

```kotlin
/**
 * Chain with caching between beads
 */
class CachedChain<T, R>(
    private val beads: List<(suspend (T) -> Result<R>)>,
    private val cache: MutableMap<T, R> = mutableMapOf()
) : ToolChain<T, R> {

    override suspend fun execute(input: T): Result<R> {
        return try {
            if (cache.containsKey(input)) {
                Result.Success(cache[input]!!)
            } else {
                var result: Result<R>? = null

                for (bead in beads) {
                    result = bead(input)
                    if (result is Result.Error) break

                    // Cache intermediate results
                    if (result is Result.Success) {
                        cache[input] = result.value
                    }
                }

                result ?: Result.Error("No beads defined", null)
            }
        } catch (e: Exception) {
            Result.Error("Chain execution failed", e)
        }
    }
}
```

---

## Using This Skill

### When to Use

**Use tool-orchestration for:**
- Multi-step workflows with 3+ steps
- Workflows where each step transforms the output of the previous
- Reusable workflow patterns
- Complex data processing
- Automated deployment pipelines

**Avoid using for:**
- Single-step tasks
- Simple transformations
- Quick scripts

### How to Invoke

```markdown
## In Your Workflow

1. **Identify Chain**: Determine which predefined chain to use
2. **Prepare Input**: Gather necessary data for the chain
3. **Execute Chain**: Call execute() method
4. **Handle Results**: Process success/failure
5. **Log Progress**: Track each bead's execution
6. **Clean Up**: Release resources if needed

### Example

```kotlin
// Deploy application
val deployment = deploymentChain.execute(config)
when (deployment) {
    is Result.Success -> {
        showSuccess("Deployed to ${deployment.value.deployment.url}")
    }
    is Result.Error -> {
        showError(deployment.message)
        handleRollback()
    }
}
```
```

---

## Best Practices

### 1. Chain Design

**Good:**
- Each bead has a single responsibility
- Clear input/output contracts
- Error handling at each bead
- Comprehensive documentation

**Avoid:**
- Beads doing too much
- Mixing concerns in beads
- No error handling
- Complex implicit logic

### 2. Naming

**Good:**
- Bead names describe their purpose
- Chain names indicate what it does
- Clear acronyms (if used, define them)

**Avoid:**
- Vague names (e.g., "step1", "process")
- Inconsistent naming

### 3. Error Handling

**Good:**
- Clear error messages
- Errors logged with context
- Automatic rollback on failure
- Graceful degradation

**Avoid:**
- Silent failures
- Generic error messages
- No rollback mechanism

### 4. Performance

**Good:**
- Fast beads execute first
- Parallel beads for independent steps
- Caching for expensive operations
- Resource cleanup

**Avoid:**
- Slow beads first
- No parallelization where possible
- Memory leaks
- No cleanup

---

## Integration with Other Skills

### With Iterative Refinement

```markdown
## Iterative Refinement with Tool Chains

1. **Initial Generation**: Use tool chain to generate initial version
2. **Self-Review**: Review chain output against quality criteria
3. **Refine**: Modify beads based on review findings
4. **Re-run**: Execute chain with modified configuration

Benefits:
- Iterate on chain configuration
- Apply improvements to specific beads
- Track changes in each iteration
```

### With State Machine Workflows

```markdown
## State Machine with Tool Chains

State transitions can execute tool chains:

INIT → (execute buildChain) → BUILDING
BUILDING → (execute healthCheckChain) → READY
READY → (execute deployChain) → DEPLOYED
DEPLOYED → (execute monitorChain) → ACTIVE

Each state transition is a tool chain execution
```

---

## References

- **Chain of Responsibility Pattern**: Design Patterns GoF
- **Tool Chain Pattern**: Unix pipeline concepts
- **Workflow Patterns**: BPMN standards

---

## Change Log

- **v1.0.0** (2026-03-07): Initial implementation
  - Complete Beads Pattern implementation
  - 3 predefined tool chains
  - DSL support
  - Error handling patterns
  - Performance considerations

---

## Contributing

To improve this skill:

1. Add new predefined tool chains for common workflows
2. Document more error handling patterns
3. Provide examples for different technologies
4. Share performance optimization tips
