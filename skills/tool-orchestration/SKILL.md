---
name: tool-orchestration
description: Orchestrate complex sequences of tools/actions using chain-of-responsibility pattern (Beads pattern)
tags: [workflow, tools, patterns, chains, dsl]
version: 1.0.0
---

# Tool Orchestration Skill

## Purpose

Orchestrate complex sequences of tools and actions using the **Beads Pattern** (Chain of Responsibility). This enables reusable, composable workflows with clear input/output contracts.

## When to Use

- **Multi-Step Pipelines** - Deployment, build, test, or monitoring workflows
- **Research Tasks** - Collecting data from multiple sources and analyzing
- **Complex Testing** - Unit → Integration → E2E → Performance testing
- **Code Analysis** - Static analysis → Linting → Security scan → Coverage
- **API Development** - Design → Documentation → Testing → Deployment
- **QA Workflows** - Test planning → Execution → Reporting → Fixes

## The Beads Pattern Concept

**Beads** are reusable building blocks that process data through a chain:

```
Input → Bead1 → Bead2 → Bead3 → ... → Output
       (Transform)  (Filter) (Validate)  (Format)
```

Each bead:
- Has a single responsibility
- Accepts input and produces output
- Can be composed with other beads
- Can fail or continue on errors

## Predefined Tool Chains

### Chain 1: Code Analysis → Review → Test Generation

**Use Case:** Thorough code review with automated tests

```
1. Analyze Code Structure
   - Parse code files
   - Extract dependencies
   - Identify patterns

2. Review Code
   - Static analysis
   - Security scan
   - Code quality check
   - Performance analysis

3. Generate Tests
   - Create unit tests
   - Create integration tests
   - Generate test data
   - Document expected behavior
```

### Chain 2: API Design → Documentation → Testing

**Use Case:** API development with complete documentation and testing

```
1. Design API
   - Define endpoints
   - Specify request/response schemas
   - Document error codes
   - Define authentication

2. Generate Documentation
   - Create OpenAPI/Swagger spec
   - Generate client SDK
   - Create example requests
   - Document usage patterns

3. Test API
   - Create integration tests
   - Test error cases
   - Performance testing
   - Security testing
```

### Chain 3: Deployment → Health Check → Rollback

**Use Case:** Production deployment with safety nets

```
1. Deploy
   - Build artifact
   - Deploy to server
   - Run migration scripts
   - Verify deployment

2. Health Check
   - Verify services started
   - Check database connectivity
   - Test endpoints
   - Monitor logs

3. Rollback (if failed)
   - Stop new version
   - Start previous version
   - Restore database
   - Notify team
```

## DSL for Defining Chains

### Kotlin DSL

```kotlin
val codeAnalysisChain = ToolChainDSL<File, AnalysisResult>()
    .bead("Analyze Structure") { file ->
        analyzeCodeStructure(file)
    }
    .bead("Review Code") { analysis ->
        reviewCode(analysis)
    }
    .bead("Generate Tests") { review ->
        generateTests(review)
    }
    .build()

// Execute
val result = codeAnalysisChain.execute(someFile)
```

### JavaScript/TypeScript DSL

```typescript
const deploymentChain = ToolChainBuilder()
  .bead('Build', (file: File) => build(file))
  .bead('Deploy', (buildResult: BuildResult) => deploy(buildResult))
  .bead('Health Check', (deployResult: DeployResult) => healthCheck(deployResult))
  .bead('Rollback', (checkResult: CheckResult) => rollback(checkResult))
  .build();

// Execute
const result = await deploymentChain.execute(someFile);
```

## Error Handling Patterns

### 1. Continue on Error

Process continues even if a bead fails (collect errors).

```kotlin
val chain = ToolChainDSL()
    .bead("Analyze") { input -> analyze(input) }
    .bead("Review") { input -> review(input) }  // May fail
    .bead("Generate") { input -> generate(input) }  // Still processes
    .onError { error ->
        logger.warn("Bead failed: $error")
        // Continue processing
    }
    .build()
```

### 2. Skip on Error

Skip remaining beads on failure.

```kotlin
val chain = ToolChainDSL()
    .bead("Analyze") { input -> analyze(input) }
    .bead("Review") { input -> review(input) }
    .bead("Generate") { input -> generate(input) }
    .skipOnError()
    .build()
```

### 3. Parallel Processing

Execute beads in parallel where possible.

```kotlin
val chain = ToolChainDSL()
    .bead("Analyze", parallel = true) { input -> analyze(input) }
    .bead("Review", parallel = true) { input -> review(input) }
    .bead("Generate", parallel = true) { input -> generate(input) }
    .build()
```

## Integration Pattern

### Orchestrator Agent

```kotlin
class WorkflowOrchestrator {
    private val codeAnalysisChain = createCodeAnalysisChain()
    private val deploymentChain = createDeploymentChain()

    fun analyzeCode(path: String) {
        val result = codeAnalysisChain.execute(File(path))
        reportResults(result)
    }

    fun deployToProduction() {
        val result = deploymentChain.execute()
        if (result.success) {
            notifySuccess(result)
        } else {
            notifyFailure(result)
        }
    }
}
```

### Custom Chains

```kotlin
// Research Chain
val researchChain = ToolChainDSL<SearchQuery, ResearchResult>()
    .bead("Search GitHub") { query ->
        searchGitHub(query)
    }
    .bead("Analyze Repositories") { searchResults ->
        analyzeRepositories(searchResults)
    }
    .bead("Extract Patterns") { analysis ->
        extractPatterns(analysis)
    }
    .bead("Generate Report") { patterns ->
        generateResearchReport(patterns)
    }
    .build()

// Build Chain
val buildChain = ToolChainDSL<Project, BuildResult>()
    .bead("Lint Code") { project ->
        lint(project)
    }
    .bead("Run Tests") { lintResult ->
        runTests(lintResult)
    }
    .bead("Package Application") { testResult ->
        packageApplication(testResult)
    }
    .bead("Create Release") { packageResult ->
        createRelease(packageResult)
    }
    .build()
```

## Real-World Example

### API Development Workflow

#### Chain Definition

```kotlin
val apiDevelopmentChain = ToolChainDSL<ApiDesign, ApiDeployment>()
    .bead("Design API") { design ->
        validateApiDesign(design)
        createEndpointDefinitions(design)
    }
    .bead("Generate Documentation") { endpointDefinitions ->
        generateOpenAPISpec(endpointDefinitions)
        createClientSDK(endpointDefinitions)
    }
    .bead("Create Tests") { docs ->
        generateIntegrationTests(docs)
        createTestData(docs)
    }
    .bead("Deploy to Staging") { tests ->
        deployToStaging(tests)
        runSmokeTests(tests)
    }
    .bead("Verify Deployment") { deployment ->
        verifyApiEndpoints(deployment)
        checkPerformance(deployment)
    }
    .build()
```

#### Execution

```kotlin
val apiDesign = ApiDesign(
    endpoints = listOf(
        ApiEndpoint(
            method = "GET",
            path = "/users/{id}",
            description = "Get user by ID",
            requestSchema = UserRequestSchema(),
            responseSchema = UserResponseSchema()
        )
    )
)

val result = apiDevelopmentChain.execute(apiDesign)
```

#### Output

```kotlin
data class ApiDeployment(
    val openAPISpec: String,
    val clientSDK: File,
    val integrationTests: File,
    val deploymentUrl: String,
    val verificationResults: VerificationResults
)

val verificationResults = VerificationResults(
    endpointsAccessible = true,
    responseTimes: mapOf("/users/1" to 45, "/users/2" to 52),
    testsPassed = true,
    performanceOkay = true
)
```

## Best Practices

### ✅ Do's

```
✓ Define clear input/output contracts
✓ Reuse chains across projects
✓ Document chain purpose and usage
✓ Include error handling
✓ Keep beads single-purpose
✓ Add metrics and logging
✓ Version control chain definitions
✓ Test chains in isolation
```

### ❌ Don'ts

```
✗ Make chains too long (>10 beads)
✗ Mix multiple responsibilities in one bead
✗ Ignore error cases
✗ Hardcode values in beads
✗ Skip documentation
✗ Make chains project-specific
✗ Hardcode execution order
```

## Performance Optimization

### Bead Caching

```kotlin
val cachedChain = ToolChainDSL()
    .bead("Analyze Code", cache = true) { input ->
        analyzeCode(input)
    }
    .bead("Review Code") { input ->
        reviewCode(input)
    }
    .build()
```

### Parallel Processing

```kotlin
val parallelChain = ToolChainDSL()
    .bead("Static Analysis", parallel = true) { input -> staticAnalysis(input) }
    .bead("Dynamic Analysis", parallel = true) { input -> dynamicAnalysis(input) }
    .bead("Security Scan", parallel = true) { input -> securityScan(input) }
    .bead("Generate Report") { results ->
        generateReport(results)
    }
    .build()
```

### Incremental Processing

```kotlin
val incrementalChain = ToolChainDSL()
    .bead("Analyze") { input -> analyze(input) }
    .bead("Filter") { analysis ->
        analysis.filter { isChanged(it) }
    }
    .bead("Only Process Changed") { filtered ->
        processOnlyChanged(filtered)
    }
    .build()
```

## Output Format

When using this skill, document your tool chains:

```markdown
## Tool Orchestration

### Chain: API Development Workflow

**Purpose:** Complete API development with documentation and testing

**Input:** ApiDesign
**Output:** ApiDeployment

**Beads:**
1. Design API - Validates and creates endpoint definitions
2. Generate Documentation - Creates OpenAPI spec and client SDK
3. Create Tests - Generates integration tests and test data
4. Deploy to Staging - Deploys to staging environment
5. Verify Deployment - Tests endpoints and checks performance

**Error Handling:** Skip on critical failures, continue on warnings

**Execution:**
```kotlin
val result = apiDevelopmentChain.execute(apiDesign)
```

**Result:**
- OpenAPI spec: ✅ Generated
- Client SDK: ✅ Generated
- Tests: ✅ 95% coverage
- Staging: ✅ Deployed
- Verification: ✅ Passed
```

## Resources

- [Chain of Responsibility Pattern](https://en.wikipedia.org/wiki/Chain_of_responsibility_pattern)
- [Beads Pattern](https://github.com/anthropics/claude/blob/main/docs/patterns/beads.md)
- [Reactive Extensions](https://reactivex.io/)
- [Functional Programming Patterns](https://en.wikipedia.org/wiki/Functional_programming)
