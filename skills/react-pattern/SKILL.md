---
name: react-pattern
description: Implement ReAct (Reasoning + Acting) pattern for agentic workflows
tags: [agent-pattern, reasoning, acting, workflow, planning]
version: 1.0.0
---

# ReAct Pattern Skill

## Purpose

Implement the **ReAct (Reasoning + Acting)** pattern for agentic workflows. ReAct enables agents to reason about tasks step-by-step, breaking complex problems into manageable components through iterative reasoning and action execution.

## What is ReAct?

**ReAct** is a pattern where an agent:
1. **Reasons** about the current state and next steps
2. **Acts** (performs actions/tools)
3. **Observes** the results
4. **Repeats** until task is complete

This creates a clear reasoning trace visible to humans and other agents, making the decision-making process transparent.

## When to Use

- **Multi-Step Reasoning Tasks** - Tasks requiring multiple levels of analysis
- **Tool Selection** - Choosing which tool to use based on context
- **Problem Decomposition** - Breaking complex problems into sub-problems
- **Exploratory Tasks** - Tasks with uncertain or evolving requirements
- **Debugging** - Systematically finding and fixing issues
- **Research** - Deep-diving into specific topics

## The ReAct Pattern

### Cycle Components

#### 1. Thought (Reasoning)

Agent thinks about:
- Current goal
- Available actions/tools
- Expected outcomes
- Potential alternatives

```
Thought: I need to check the current state of the project
Action: git status
Observation: No changes, all tests passing
Thought: The code is ready for deployment
Action: deploy production
```

#### 2. Action (Execution)

Agent performs a specific action:
- Calls a tool/function
- Executes a command
- Accesses a resource
- Makes a decision

```
Actions:
- `git_status()` - Get repository status
- `analyze_code()` - Static analysis
- `run_tests()` - Execute test suite
- `deploy()` - Deploy application
- `check_metrics()` - Monitor performance
```

#### 3. Observation (Result)

Agent observes the result:
- Success/failure
- Data returned
- Side effects
- Error messages

```
Observations:
- "Working tree clean"
- "Build successful"
- "Deployment failed: database connection timeout"
```

#### 4. Iterate

Based on observation, the agent decides next steps.

### ReAct Framework Example

```kotlin
data class ReActStep(
    val thought: String,
    val action: ReActAction,
    val observation: String,
    val isComplete: Boolean = false
)

data class ReActAction(
    val type: ActionType,
    val name: String,
    val params: Map<String, Any>
)

enum class ActionType {
    TOOL_CALL,
    DECISION,
    DONE
}
```

## ReAct Workflow

### 1. Initialize ReAct

```kotlin
fun initializeReAct(goal: String): ReActContext {
    return ReActContext(
        goal = goal,
        steps = mutableListOf(),
        currentAction = null,
        context = emptyMap()
    )
}
```

### 2. Execute ReAct Cycle

```kotlin
fun executeReActStep(
    context: ReActContext,
    tools: List<Tool>
): ReActContext {
    // 1. Reason: Generate thought based on current state
    val thought = generateThought(context)
    context.currentAction = generateAction(thought, tools)

    // 2. Act: Execute the action
    val observation = executeAction(context.currentAction)

    // 3. Observe: Analyze the result
    context.steps.add(ReActStep(thought, context.currentAction, observation))

    // 4. Check completion
    val isComplete = checkCompletion(context, observation)
    context.isComplete = isComplete

    return context
}
```

### 3. Generate Thought

```kotlin
fun generateThought(context: ReActContext): String {
    val goal = context.goal
    val steps = context.steps
    val lastObservation = steps.lastOrNull()?.observation ?: "Initial state"

    return when {
        steps.isEmpty() -> "I need to accomplish: $goal"
        steps.size == 1 -> "First, I'll gather information about the current state. Observation: $lastObservation"
        steps.size >= 2 -> "Based on previous observations, I need to take action: $goal"
        else -> "Let me think about what I've learned so far..."
    }
}
```

### 4. Generate Action

```kotlin
fun generateAction(thought: String, tools: List<Tool>): ReActAction {
    val goalKeywords = listOf("check", "analyze", "run", "deploy", "test", "debug")
    val thoughtLower = thought.lowercase()

    return when {
        thoughtLower.contains("git") -> ReActAction(
            type = ActionType.TOOL_CALL,
            name = "git_status",
            params = emptyMap()
        )
        thoughtLower.contains("build") -> ReActAction(
            type = ActionType.TOOL_CALL,
            name = "build_project",
            params = emptyMap()
        )
        thoughtLower.contains("test") -> ReActAction(
            type = ActionType.TOOL_CALL,
            name = "run_tests",
            params = emptyMap()
        )
        thoughtLower.contains("deploy") -> ReActAction(
            type = ActionType.TOOL_CALL,
            name = "deploy_production",
            params = emptyMap()
        )
        else -> ReActAction(
            type = ActionType.DECISION,
            name = "Continue thinking",
            params = mapOf("reasoning" to "Need more information")
        )
    }
}
```

### 5. Check Completion

```kotlin
fun checkCompletion(context: ReActContext, observation: String): Boolean {
    val goal = context.goal
    val lastObservation = observation.lowercase()

    return when (goal.lowercase()) {
        "deploy" -> lastObservation.contains("success") || lastObservation.contains("deployed")
        "test" -> lastObservation.contains("passing") || lastObservation.contains("100% coverage")
        "build" -> lastObservation.contains("build successful")
        "debug" -> lastObservation.contains("fixed") || lastObservation.contains("resolved")
        else -> lastObservation.contains("complete") || lastObservation.contains("done")
    }
}
```

## Predefined ReAct Workflows

### Workflow 1: Code Deployment

```
Step 1 (Thought): "I need to deploy the application to production. First, I'll check the current git status."
Action: git_status()
Observation: "Working tree clean, no uncommitted changes"

Step 2 (Thought): "Good, no uncommitted changes. Now I'll build the project to ensure everything compiles."
Action: build_project()
Observation: "Build successful"

Step 3 (Thought): "Build succeeded. Now I'll run the tests to verify everything works."
Action: run_tests()
Observation: "All tests passing (100%)"

Step 4 (Thought): "Tests passed. I'll now deploy to production."
Action: deploy_production()
Observation: "Deployment successful, application live at https://example.com"

Step 5 (Thought): "Deployment complete. I'll check the health endpoint to verify it's running."
Action: health_check()
Observation: "Health check passed, response time: 23ms"

Result: ✓ Task Complete
```

### Workflow 2: Bug Investigation

```
Step 1 (Thought): "I need to investigate why the login API is failing. First, I'll check the server logs."
Action: check_logs()
Observation: "Error in login endpoint: NullPointerException at line 42"

Step 2 (Thought): "NullPointerException at line 42. Let me check that line of code."
Action: view_code(path="backend/src/Controller.kt", line=42)
Observation: "Code: val user = userService.findByUsername(username);"

Step 3 (Thought): "The user might be null. I should add a null check."
Action: add_null_check()
Observation: "Added null check, throws proper exception"

Step 4 (Thought): "Now I'll run the tests to verify the fix."
Action: run_tests()
Observation: "All tests passing"

Result: ✓ Bug Fixed
```

### Workflow 3: Feature Implementation

```
Step 1 (Thought): "I need to implement a new feature: user authentication with JWT. First, I'll review the existing auth code."
Action: review_auth_code()
Observation: "Existing code uses session-based auth, JWT not implemented"

Step 2 (Thought): "I'll create a JWT service for token generation and validation."
Action: create_jwt_service()
Observation: "JWT service created with methods: generateToken(), validateToken(), parseToken()"

Step 3 (Thought): "Now I'll update the login endpoint to use JWT."
Action: update_login_endpoint()
Observation: "Login endpoint updated to return JWT token"

Step 4 (Thought): "I'll add the logout endpoint to invalidate tokens."
Action: add_logout_endpoint()
Observation: "Logout endpoint created with blacklist implementation"

Step 5 (Thought): "Finally, I'll test the implementation."
Action: run_tests()
Observation: "All tests passing, coverage: 95%"

Result: ✓ Feature Implemented
```

## ReAct with LLMs

### Prompt Template

```markdown
## Task
${goal}

## Current State
${context}

## ReAct Cycle
1. **Thought**: Think about what you need to do next.
2. **Action**: Execute the action.
3. **Observation**: Note the result.
4. **Repeat** until complete.

## Available Actions
${actionsList}

## Output Format
Thought: [Your reasoning]
Action: [Action name and parameters]
Observation: [Result]
```

### Example LLM Prompt

```markdown
## Task
Check if the deployment is successful

## Current State
Step 1 complete: Checked git status - working tree clean

## ReAct Cycle
1. **Thought**: I need to check if the build was successful
2. **Action**: build_project()
3. **Observation**: [Build result]
4. **Repeat** until complete

## Available Actions
- build_project()
- run_tests()
- deploy_production()
- health_check()
```

## Benefits

### For Agents
1. **Transparent Reasoning** - Human-readable trace of decisions
2. **Systematic Approach** - Avoids guessing, follows logical steps
3. **Error Recovery** - Clear failure points make debugging easier
4. **Adaptability** - Can adjust approach based on observations

### For Humans
1. **Debugging** - Easy to see where the agent got stuck
2. **Trust** - Transparent decision-making builds confidence
3. **Learning** - Can learn patterns from agent reasoning
4. **Verification** - Can validate each step

### For Systems
1. **Reusability** - Patterns can be generalized
2. **Monitoring** - Track reasoning quality and progress
3. **Optimization** - Learn which reasoning paths are most effective
4. **Auto-Iteration** - Can automatically adjust based on outcomes

## Integration Patterns

### ReAct + Tool Orchestration

Use ReAct for high-level reasoning, tool-orchestration for detailed steps:

```
ReAct: "I need to deploy the application"
  ↓
Tool Orchestration: "Execute deployment pipeline"
  ↓
Chain: Build → Test → Deploy → Health Check
```

### ReAct + State Machine

Use ReAct for initial planning, state machine for execution:

```
ReAct: Determine state transitions
  ↓
State Machine: Execute workflow states
  ↓
ReAct: Check completion and finalize
```

### ReAct + Iterative Refinement

Use ReAct for exploration, iterative-refinement for quality:

```
ReAct: Explore possible solutions
  ↓
Iterative Refinement: Improve each solution
  ↓
ReAct: Select and execute best solution
```

## Best Practices

### ✅ Do

- **Think before acting** - Always generate a thought before taking action
- **Observe everything** - Capture all observations, even failures
- **Document reasoning** - Keep a clear log of thoughts
- **Handle errors gracefully** - Use observations to guide error recovery
- **Be specific** - Actions should be precise and actionable
- **Iterate as needed** - Don't be afraid to restart or adjust approach

### ❌ Don't

- **Skip thoughts** - Always reason, never jump straight to action
- **Ignore observations** - Pay attention to all results
- **Over-act** - Don't take actions without clear purpose
- **Repeat actions** - If an observation doesn't change, don't retry the same action
- **Ignore context** - Remember what has happened before
- **Make assumptions** - Use observations to validate assumptions

## Common Patterns

### Pattern 1: Linear ReAct

Straightforward chain of thoughts for well-defined tasks:

```
Thought → Action → Observation → Thought → Action → Observation → Done
```

### Pattern 2: Branching ReAct

Explore multiple options based on observations:

```
Thought → Action → Observation → Thought (choose branch) → Action → Observation → ...
```

### Pattern 3: ReAct with Sub-Tasks

Break large tasks into sub-tasks:

```
Thought (main goal) → Action (create sub-task plan) → Observation
Thought (sub-task 1) → Action → Observation
Thought (sub-task 2) → Action → Observation
...
Thought (final) → Done
```

### Pattern 4: ReAct + Retry

Handle failures gracefully:

```
Thought → Action → Observation (failure) → Thought (analyze) → Action (retry with fix) → Observation (success)
```

## Examples

### Example 1: Simple File Search

```kotlin
val context = initializeReAct("Find all TODO comments in the codebase")

// Step 1
val step1 = ReActStep(
    thought = "I need to search for TODO comments. I'll use grep to find them.",
    action = ReActAction("grep", "find TODO comments"),
    observation = "Found 15 TODO comments in frontend/src/"
)

// Step 2
val step2 = ReActStep(
    thought = "Let me check each TODO to see what needs to be done.",
    action = ReActAction("view_file", "Check first TODO"),
    observation = "TODO: Fix authentication bug (line 42)"
)

// Continue...
```

### Example 2: Complex Debugging

```kotlin
val context = initializeReAct("Debug why the database connection is failing")

// Step 1
ReActStep(
    thought = "I need to check the database configuration first.",
    action = "view_config",
    observation = "Config shows URL: localhost:5432, but server is on port 5433"
)

// Step 2
ReActStep(
    thought = "The port mismatch is the issue. I'll update the configuration.",
    action = "fix_config",
    observation = "Configuration updated, server restarted"
)

// Step 3
ReActStep(
    thought = "Now I'll test the connection.",
    action = "test_connection",
    observation = "Connection successful"
)

// Step 4
ReActStep(
    thought = "Connection working. I'll verify the application is functioning correctly.",
    action = "verify_app",
    observation = "All endpoints responding correctly"
)

// Step 5
ReActStep(
    thought = "Issue resolved. The database connection is now working.",
    action = "done",
    observation = "Debugging complete"
)
```

## Real-World Use Cases

### 1. CI/CD Pipeline Orchestration
```
Thought: "Pipeline failed at the test stage. I need to investigate."
Action: Check test logs
Observation: "Test suite has 3 failing tests"
Thought: "Let me examine the failing tests."
Action: View failing tests
Observation: "Tests are flaky, passing sometimes, failing sometimes"
Thought: "I'll retry the tests to see if it's a transient issue."
Action: Retry tests
Observation: "All tests passing now"
Thought: "Tests are flaky. I'll add retry logic."
Action: Implement retry logic
Observation: "Tests passing consistently"
```

### 2. Code Quality Analysis
```
Thought: "I need to analyze the codebase for security issues."
Action: Run security scan
Observation: "Found 5 medium-severity issues"
Thought: "Let me examine each issue."
Action: View security report
Observation: "Issue 1: SQL injection vulnerability in query builder"
Thought: "I'll fix this by using parameterized queries."
Action: Apply fix
Observation: "Fix applied, scan re-run"
Observation: "All issues resolved"
```

### 3. API Testing
```
Thought: "I need to test the API endpoints systematically."
Action: Generate test plan
Observation: "Plan: Test all endpoints, validate responses"
Thought: "I'll start with GET endpoints."
Action: Test GET /api/users
Observation: "Response OK, returns array of users"
Thought: "Testing POST /api/users"
Action: Test POST /api/users with valid data
Observation: "Response 201, user created successfully"
Thought: "Testing POST with invalid data"
Action: Test POST with invalid data
Observation: "Response 400, validation error"
Thought: "Testing with valid data again"
Observation: "Still returns 400, issue identified"
Thought: "I'll investigate the validation logic."
Action: View validation code
Observation: "Found bug in validation"
Thought: "I'll fix the validation bug."
Action: Fix validation
Observation: "POST now works correctly"
```

## Integration with Claude

### Agent Configuration

```json
{
  "agent": "backend-developer",
  "skills": [
    "react-pattern",
    "iterative-refinement",
    "tool-orchestration",
    "state-machine-workflow"
  ],
  "parameters": {
    "maxReActIterations": 10,
    "minThoughtLength": 50,
    "maxThoughtLength": 200,
    "enableReasoningTrace": true
  }
}
```

### Skill Execution Flow

```markdown
## Task
Implement user authentication with JWT

## Context
- Backend in Kotlin/Spring Boot
- Using existing UserService
- JWT library already configured

## ReAct Pattern

### Thought 1
I need to implement JWT authentication. First, I'll check the existing auth setup to understand the current implementation.

### Action 1
view_code("backend/src/security/AuthSecurityConfig.kt")

### Observation 1
Current implementation uses session-based auth. JWT configuration is missing.

### Thought 2
I'll create a JwtService for token generation and validation.

### Action 2
create_service("JwtService.kt")

### Observation 2
JwtService created with methods: generateToken(), validateToken(), parseToken()

### Thought 3
Now I'll update the login endpoint to use JWT.

### Action 3
update_endpoint("LoginController.kt")

### Observation 3
Login endpoint updated to return JWT token in response

### Thought 4
I'll add a logout endpoint to invalidate tokens.

### Action 4
add_endpoint("LogoutController.kt")

### Observation 4
Logout endpoint created with token blacklist

### Thought 5
I'll run tests to verify the implementation.

### Action 5
run_tests()

### Observation 5
All tests passing, coverage: 95%

### Thought 6
Implementation complete. Let me verify the deployment script.

### Action 6
check_deployment_script()

### Observation 6
Deployment script exists and is configured correctly

### Conclusion
✓ JWT authentication implemented successfully
```

## Advanced Features

### 1. Adaptive ReAct

Agent learns which reasoning paths are most effective:

```kotlin
data class ReActMemory(
    val successfulPaths: List<ReActPath>,
    val failedPaths: List<ReActPath>,
    val commonPatterns: Map<String, Int>
)
```

### 2. ReAct with Sub-Planners

Break complex tasks into sub-plans:

```kotlin
data class ReActPlan(
    val subTasks: List<ReActTask>,
    val estimatedDuration: Duration
)
```

### 3. Multi-Agent ReAct

Coordinate multiple agents:

```kotlin
data class MultiAgentReAct(
    val agents: Map<String, Agent>,
    val coordinationProtocol: CoordinationProtocol
)
```

## Resources

- **ReAct Paper**: [ReAct: Synergizing Reasoning and Acting in Language Models](https://arxiv.org/abs/2210.03629)
- **LangChain ReAct**: [LangChain ReAct Tutorial](https://python.langchain.com/docs/modules/agents/agent_types/react_agent)
- **Thinking Fast and Slow**: Daniel Kahneman
- **Chain of Thought**: Wei et al. (2022)

## Summary

ReAct pattern provides a structured, transparent approach to agentic workflows by combining:
- **Reasoning** - Thinking before acting
- **Acting** - Taking precise actions
- **Observation** - Capturing results
- **Iteration** - Repeating until complete

This creates reliable, debuggable agents that can tackle complex problems systematically.
