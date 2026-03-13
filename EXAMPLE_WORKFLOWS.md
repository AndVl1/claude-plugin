# Example Workflows - Workflow Pattern Skills

**Date:** 2026-03-14
**Purpose:** Demonstrate practical usage of iterative-refinement, tool-orchestration, and state-machine-workflow

---

## Example 1: Feature Development with Iteration

**Scenario:** Backend developer implementing user authentication

### Workflow

```markdown
<use skill="state-machine-workflow">
  <workflow>feature-development</workflow>
  <start>INIT</start>
</use>

<use skill="iterative-refinement">
  <phase>1</phase>
  <task>Implement JWT authentication endpoint</task>
</use>
```

### Iteration 1 (Generated)
```kotlin
@RestController
class AuthController @Inject constructor(
    private val authService: AuthService
) : AuthApi {
    override fun login(request: LoginRequest): ResponseEntity<UserResponse> {
        val user = authService.authenticate(request.username, request.password)
        val token = authService.generateToken(user)
        return ResponseEntity.ok(UserResponse(user, token))
    }
}
```

**Self-Review Checklist:**
1. [ ] Functional correctness - ✅ Token generated
2. [ ] Code quality - ✅ Clean code
3. [ ] Integration - ⚠️ Missing password hashing
4. [ ] Documentation - ⚠️ No Swagger docs
5. [ ] Performance - ✅ Standard implementation
6. [ ] Testing - ❌ No unit tests

**Result:** 3/6 met → Refine

---

### Iteration 2 (Refined)
```kotlin
@RestController
class AuthController @Inject constructor(
    private val authService: AuthService,
    private val tokenProvider: TokenProvider
) : AuthApi {
    override fun login(request: LoginRequest): ResponseEntity<UserResponse> {
        // Validate input
        if (request.username.isBlank() || request.password.isBlank()) {
            throw ValidationRestException("Username and password required")
        }

        // Authenticate and hash
        val user = authService.authenticateWithHash(request.username, request.password)
        val token = tokenProvider.generateToken(user)

        // Log activity
        authService.logLoginAttempt(request.username, success = true)

        return ResponseEntity.ok(UserResponse(user, token))
    }
}
```

**Self-Review Checklist:**
1. [ ] Functional correctness - ✅
2. [ ] Code quality - ✅
3. [ ] Integration - ✅ Token provider added
4. [ ] Documentation - ✅ Added Swagger docs
5. [ ] Performance - ✅
6. [ ] Testing - ⚠️ Basic tests

**Result:** 5/6 met → Refine

---

### Iteration 3 (Final)
```kotlin
@RestController
class AuthController @Inject constructor(
    private val authService: AuthService,
    private val tokenProvider: TokenProvider,
    private val rateLimiter: RateLimiter
) : AuthApi {
    override fun login(request: LoginRequest): ResponseEntity<UserResponse> {
        // Validate input
        if (request.username.isBlank() || request.password.isBlank()) {
            throw ValidationRestException("Username and password required")
        }

        // Rate limiting check
        if (!rateLimiter.tryAcquire(request.username)) {
            throw RateLimitRestException("Too many login attempts")
        }

        // Authenticate with hashing
        val user = authService.authenticateWithHash(request.username, request.password)

        // Generate token
        val token = tokenProvider.generateToken(user)

        // Log activity
        authService.logLoginAttempt(request.username, success = true)

        // Cache token (optional)
        tokenProvider.cacheToken(user.id, token)

        return ResponseEntity.ok(UserResponse(user, token))
    }
}
```

**Self-Review Checklist:**
1. [ ] Functional correctness - ✅
2. [ ] Code quality - ✅
3. [ ] Integration - ✅
4. [ ] Documentation - ✅
5. [ ] Performance - ✅ Rate limiting
6. [ ] Testing - ✅ Comprehensive tests

**Result:** 6/6 met → Finalize

**Benefits:**
- 3 iterations vs 10+ without iteration
- Early bug detection (password hashing, rate limiting)
- Comprehensive documentation
- High test coverage
- Production-ready code

---

## Example 2: Deployment with Tool Chains

**Scenario:** DevOps team deploying a new service

### Workflow

```markdown
<use skill="state-machine-workflow">
  <workflow>testing</workflow>
  <start>INIT</start>
</use>

<use skill="tool-orchestration">
  <chain>deployment</chain>
  <input>Service name: payment-service</input>
</use>
```

### Tool Chain Execution

**Chain:** deployment

**Step 1: Build**
```bash
docker build -t payment-service:v1.0 .
docker tag payment-service:v1.0 registry.example.com/payment-service:v1.0
```

**Step 2: Deploy**
```bash
kubectl apply -f k8s/payment-service/deployment.yaml
kubectl apply -f k8s/payment-service/service.yaml
kubectl apply -f k8s/payment-service/configmap.yaml
```

**Step 3: Health Check**
```bash
kubectl wait --for=condition=available --timeout=60s deployment/payment-service
kubectl get pods -l app=payment-service

# Verify health endpoint
curl http://payment-service:8080/health
# Expected: {"status":"UP"}
```

**Step 4: Rollback (if failed)**
```bash
kubectl rollout undo deployment/payment-service
```

**Error Handling Patterns:**
- **Continue:** Proceed to next step even if error
- **Skip:** Skip dependent steps
- **Parallel:** Run multiple steps simultaneously

---

## Example 3: QA Review with Iteration

**Scenario:** QA testing authentication implementation

### Workflow

```markdown
<use skill="iterative-refinement">
  <phase>1</phase>
  <task>Review authentication code</task>
</use>
```

### Iteration 1 (Initial Review)
**Areas Checked:**
1. Functional correctness
2. Code quality
3. Security
4. Performance
5. Documentation
6. Testing

**Results:**
- 2/6 excellent
- 3/6 good
- 1/6 needs work

**Issues Found:**
1. Missing input validation on password
2. No rate limiting
3. No password hashing (wrong review area for QA)

**Result:** 4/6 met → Refine

---

### Iteration 2 (Detailed Review)
**Focused Review:**
- Security patterns
- Edge cases
- Integration points
- Error handling

**Results:**
- 4/6 excellent
- 2/6 good
- 0/6 needs work

**Issues Found:**
1. Password field not masked in logs
2. No rate limiting on endpoint
3. Missing input validation on username
4. Token not revoked on logout (not implemented yet)

**Result:** 6/6 met → Finalize

---

### Iteration 3 (Final Review)
**Comprehensive Security Audit:**
- OWASP Top 10 compliance
- Input validation
- Authentication/Authorization
- Session management
- Data protection
- Logging and monitoring

**Results:**
- 6/6 excellent
- 0/6 needs work
- 0/6 issues

**Final Verdict:** ✅ APPROVED

**Benefits:**
- Early security issues found
- Comprehensive testing coverage
- Clear action items for developers
- High-quality output

---

## Example 4: Mobile Development with Iteration

**Scenario:** Mobile developer implementing user profile screen

### Workflow

```markdown
<use skill="state-machine-workflow">
  <workflow>feature-development</workflow>
  <start>INIT</start>
</use>

<use skill="iterative-refinement">
  <phase>1</phase>
  <task>Implement user profile screen with Compose</task>
</use>
```

### Iteration 1 (Initial Implementation)

**Component:**
```kotlin
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel,
    onEdit: () -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.padding(16.dp)) {
        Text("Profile")
        Text(state.user.name ?: "Guest")
        Button(onClick = onEdit) {
            Text("Edit")
        }
    }
}
```

**Self-Review Checklist:**
1. [ ] Functional correctness - ✅
2. [ ] Code quality - ✅
3. [ ] Integration - ⚠️ Missing navigation
4. [ ] Documentation - ⚠️ No explanations
5. [ ] Performance - ⚠️ No memoization
6. [ ] Testing - ❌ No tests

**Result:** 3/6 met → Refine

---

### Iteration 2 (Refined)

**Component:**
```kotlin
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel,
    onEdit: () -> Unit,
    onBack: () -> Unit,
    componentContext: ComponentContext
) {
    val state by viewModel.state.collectAsState()
    val coroutineScope = rememberCoroutineScope(componentContext)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(Res.string.profile)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = null)
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
        ) {
            if (state.user != null) {
                Text(
                    text = state.user.name ?: stringResource(Res.string.guest),
                    style = MaterialTheme.typography.headlineSmall
                )
                Text(
                    text = stringResource(Res.string.email_label) + ": " + state.user.email,
                    style = MaterialTheme.typography.bodyMedium
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = {
                    coroutineScope.launch {
                        viewModel.navigateToEdit()
                    }
                },
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(stringResource(Res.string.edit_profile))
            }
        }
    }
}
```

**Self-Review Checklist:**
1. [ ] Functional correctness - ✅
2. [ ] Code quality - ✅
3. [ ] Integration - ✅ Navigation handled
4. [ ] Documentation - ✅ Better structure
5. [ ] Performance - ✅ Memoized
6. [ ] Testing - ⚠️ Basic tests

**Result:** 5/6 met → Refine

---

### Iteration 3 (Final)

**Component:**
```kotlin
@Composable
fun ProfileScreen(
    viewModel: ProfileViewModel,
    componentContext: ComponentContext,
    onEdit: () -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    val coroutineScope = rememberCoroutineScope(componentContext)

    // Memoize to prevent recomposition
    val userData by remember { derivedStateOf { state.user } }

    // Error handling
    if (state.error != null) {
        ErrorScreen(
            message = state.error!!,
            onRetry = { viewModel.loadUserProfile() }
        )
    } else if (state.isLoading) {
        LoadingContent()
    } else if (userData != null) {
        ProfileContent(
            user = userData!!,
            onEditClick = { onEdit() },
            onLogoutClick = {
                coroutineScope.launch {
                    viewModel.logout()
                    onBack()
                }
            }
        )
    } else {
        EmptyState(
            message = stringResource(Res.string.no_user_profile),
            action = { viewModel.loadUserProfile() }
        )
    }
}

@Composable
private fun ProfileContent(
    user: UserProfile,
    onEditClick: () -> Unit,
    onLogoutClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(8.dp))

        // User avatar
        Image(
            painter = painterResource(Res.drawable.ic_user_avatar),
            contentDescription = null,
            modifier = Modifier.size(80.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        // User name
        Text(
            text = user.name ?: stringResource(Res.string.guest),
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(8.dp))

        // User email
        Text(
            text = stringResource(Res.string.email_label) + ": " + user.email,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )

        Spacer(modifier = Modifier.height(32.dp))

        // Edit button
        Button(
            onClick = onEditClick,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(Res.string.edit_profile))
        }

        Spacer(modifier = Modifier.height(8.dp))

        // Logout button
        OutlinedButton(
            onClick = onLogoutClick,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = MaterialTheme.colorScheme.error
            )
        ) {
            Text(stringResource(Res.string.logout), color = MaterialTheme.colorScheme.error)
        }
    }
}
```

**Self-Review Checklist:**
1. [ ] Functional correctness - ✅
2. [ ] Code quality - ✅
3. [ ] Integration - ✅
4. [ ] Documentation - ✅
5. [ ] Performance - ✅
6. [ ] Testing - ✅ Comprehensive

**Result:** 6/6 met → Finalize

**Benefits:**
- 3 iterations vs 10+ without iteration
- Better UX (loading, error, empty states)
- Proper navigation
- High quality UI
- Production-ready code

---

## Key Takeaways

### Iterative Refinement
- **Early detection:** Bugs caught in iteration 1 or 2, not in production
- **Quality improvement:** Each iteration adds checks and improvements
- **Cost-effective:** 3 iterations < 10 iterations

### Tool Orchestration
- **Consistency:** Same patterns for all deployments
- **Error handling:** Standardized error recovery
- **Reusability:** Chains can be reused across projects

### State Machine Workflows
- **Clarity:** Explicit states make progress tracking easy
- **Validation:** Prevents invalid transitions
- **Visualization:** Mermaid diagrams show workflow clearly

---

*End of Examples*
