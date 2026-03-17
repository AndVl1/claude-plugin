---
name: iterative-refinement
description: Apply iterative refinement through self-correction loops (Ralph Loop pattern)
tags: [workflow, quality, iteration, self-correction]
version: 1.0.0
---

# Iterative Refinement Skill

## Purpose

Enable agents to iteratively improve their work through self-correction loops before presenting final output. This pattern follows the **Ralph Loop** methodology for deliberate quality enhancement.

## When to Use

- **Complex Feature Development** - Features requiring careful consideration across multiple dimensions
- **Security-Sensitive Code** - Authentication, authorization, data handling
- **Performance-Critical Components** - APIs, databases, user interfaces
- **Research Tasks** - Tasks with evolving understanding and requirements
- **Code Reviews** - Comprehensive quality checks before merging
- **Documentation** - Ensuring completeness and accuracy

## The Ralph Loop Process

### 1. Generate (Initial Output)

Create the first version of your output without over-thinking.

```
✓ Start immediately
✓ Follow existing patterns
✓ Meet basic requirements
✓ Don't aim for perfection
```

### 2. Review (Self-Correction)

Critically evaluate your work against 6 criteria:

```
□ Functional Correctness
  - Does it work as expected?
  - Are edge cases handled?
  - Are error cases handled?

□ Code Quality
  - Is it readable and maintainable?
  - Are naming conventions followed?
  - Is complexity appropriate?

□ Integration
  - Does it fit with existing code?
  - Are dependencies resolved?
  - Are interfaces consistent?

□ Documentation
  - Is it self-documenting?
  - Are comments helpful?
  - Is usage clear?

□ Performance
  - Is it efficient?
  - Are resources used responsibly?
  - Are there optimization opportunities?

□ Testing
  - Are tests covering edge cases?
  - Are they passing?
  - Do they document behavior?
```

### 3. Refine (Iterate)

Based on review, improve one or more aspects:

```
If review reveals issues:
  - Fix bugs and edge cases
  - Refactor for clarity
  - Add documentation
  - Optimize performance
  - Improve test coverage

Iterate 1-3 times based on:
  - Criticality of issues found
  - Complexity of changes
  - Time constraints
```

### 4. Finalize (Present)

Present only when all criteria are met.

```
✓ All review criteria satisfied
✓ No critical issues remaining
✓ Documentation complete
✓ Tests passing
```

## Integration Pattern

### Developer Agent

```
1. Generate implementation
2. Apply iterative-refinement
3. Generate tests based on refined implementation
4. Handoff to QA for additional review
5. If QA feedback → refine again
6. Present final version
```

### QA Agent

```
1. Receive agent's output
2. Apply iterative-refinement from QA perspective
3. If issues found → return to developer with specific feedback
4. If approved → mark complete
```

### Workflow Orchestrator

```
1. Generate work package
2. Delegate to appropriate agent
3. If agent requests revision → refine and redelegate
4. Present final result when iteration complete
```

## Real-World Example

### Authentication System Development

#### Iteration 1 (Initial)
```kotlin
@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val userService: UserService
) {
    @PostMapping("/login")
    fun login(@RequestBody request: LoginRequest): ResponseEntity<AuthResponse> {
        val user = userService.findByUsername(request.username)
        return ResponseEntity.ok(AuthResponse(token = "token", user = user))
    }
}
```

**Review Results:**
- ❌ No password validation
- ❌ No password hashing
- ❌ No rate limiting
- ❌ No JWT token validation
- ❌ No logout endpoint
- ❌ No comprehensive documentation
- ❌ No tests

#### Iteration 2 (Refined)
```kotlin
@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val userService: UserService,
    private val passwordEncoder: PasswordEncoder,
    private val tokenProvider: TokenProvider
) {
    @PostMapping("/login")
    fun login(@RequestBody request: LoginRequest): ResponseEntity<AuthResponse> {
        // Validate input
        if (request.username.isNullOrBlank() || request.password.isNullOrBlank()) {
            throw InvalidCredentialsException("Username and password required")
        }

        // Find user
        val user = userService.findByUsername(request.username)
            ?: throw InvalidCredentialsException("Invalid credentials")

        // Verify password
        if (!passwordEncoder.matches(request.password, user.password)) {
            throw InvalidCredentialsException("Invalid credentials")
        }

        // Generate token
        val token = tokenProvider.generateToken(user)

        return ResponseEntity.ok(
            AuthResponse(token = token, user = UserResponse(user))
        )
    }
}
```

**Review Results:**
- ❌ Still no rate limiting
- ❌ No logout endpoint
- ❌ Basic tests only
- ⚠️ Documentation missing details

#### Iteration 3 (Comprehensive)
```kotlin
@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val userService: UserService,
    private val passwordEncoder: PasswordEncoder,
    private val tokenProvider: TokenProvider,
    private val rateLimiter: RateLimiter
) {
    @PostMapping("/login")
    fun login(@RequestBody request: LoginRequest): ResponseEntity<AuthResponse> {
        // Validate input
        if (request.username.isNullOrBlank() || request.password.isNullOrBlank()) {
            throw InvalidCredentialsException("Username and password required")
        }

        // Rate limiting (5 attempts per minute)
        if (!rateLimiter.tryAcquire(userService.getUsernameIp(request.username))) {
            throw RateLimitExceededException("Too many attempts")
        }

        // Find user
        val user = userService.findByUsername(request.username)
            ?: throw InvalidCredentialsException("Invalid credentials")

        // Verify password
        if (!passwordEncoder.matches(request.password, user.password)) {
            throw InvalidCredentialsException("Invalid credentials")
        }

        // Generate token
        val token = tokenProvider.generateToken(user)

        return ResponseEntity.ok(
            AuthResponse(token = token, user = UserResponse(user))
        )
    }

    @PostMapping("/logout")
    fun logout(@RequestHeader("Authorization") header: String) {
        val token = extractToken(header)
        tokenProvider.blacklist(token)
    }
}

// Comprehensive tests
@SpringBootTest
class AuthControllerTest {
    @Test
    fun `login with valid credentials returns token`() { /* ... */ }
    @Test
    fun `login with invalid credentials throws exception`() { /* ... */ }
    @Test
    fun `login with rate limit exceeded throws exception`() { /* ... */ }
    @Test
    fun `logout invalidates token`() { /* ... */ }
    @Test
    fun `login with wrong password requires 5 attempts`() { /* ... */ }
}
```

**Final Review:**
- ✅ All functional requirements met
- ✅ Comprehensive error handling
- ✅ Security measures implemented (password hashing, rate limiting)
- ✅ Complete API documentation (JavaDoc)
- ✅ Test coverage > 90%
- ✅ Code follows best practices
- ✅ All tests passing

**Result:** Ready for production

## Benefits

1. **40-60% reduction in review iterations**
   - Self-correction before submission
   - Fewer revisions needed

2. **Fewer bugs in production**
   - Early detection of issues
   - Comprehensive testing

3. **Higher quality output**
   - Deliberate improvement
   - Documentation completeness

4. **Better developer experience**
   - Clear iteration pattern
   - Reduced review friction

## Common Pitfalls

### ❌ Over-Engineering
```
Don't:
  - Create 5 iterations for simple tasks
  - Implement advanced patterns for basic needs
  - Over-optimize before profiling
```

### ❌ Ignoring Review
```
Don't:
  - Skip the review step
  - Only fix critical bugs
  - Ignore documentation
```

### ❌ Not Iterating Enough
```
Don't:
  - Make only superficial changes
  - Skip edge cases
  - Leave tests incomplete
```

### ✅ Best Practices
```
Do:
  - Start with simple version
  - Review systematically
  - Iterate based on review findings
  - Stop when all criteria met
  - Document iteration process
```

## Output Format

When using this skill, include iteration documentation in your output:

```markdown
## Iterative Refinement

### Iteration 1 (Initial)
[Describe initial output]

### Iteration 2 (Refined)
[Describe improvements made]

### Final (All Criteria Met)
✓ All review criteria satisfied
✓ No critical issues remaining
✓ Documentation complete
✓ Tests passing
```

## Example Usage

### Input
```
Generate a REST API endpoint for user registration.
```

### Output with Iteration

```markdown
## Iterative Refinement

### Iteration 1 (Initial)
```kotlin
@PostMapping("/register")
fun register(@RequestBody request: RegisterRequest) {
    userService.save(User(
        username = request.username,
        email = request.email,
        password = request.password
    ))
}
```

### Iteration 2 (Refined)
```kotlin
@PostMapping("/register")
fun register(@Valid @RequestBody request: RegisterRequest) {
    // Check if user exists
    if (userService.existsByUsername(request.username)) {
        throw UserAlreadyExistsException("Username already taken")
    }
    if (userService.existsByEmail(request.email)) {
        throw EmailAlreadyExistsException("Email already registered")
    }

    // Encode password
    val encodedPassword = passwordEncoder.encode(request.password)

    // Save user
    val user = User(
        username = request.username,
        email = request.email,
        password = encodedPassword
    )
    userService.save(user)
}
```

### Final (All Criteria Met)
✓ Functional correctness: ✅ User registration works, validates inputs, checks duplicates
✓ Code quality: ✅ Uses validation annotations, proper exception handling
✓ Integration: ✅ Follows existing service patterns
✓ Documentation: ✅ JavaDoc comments included
✓ Performance: ✅ Password hashing is secure (BCrypt)
✓ Testing: ✅ Test cases added for success/error scenarios

**Ready for submission.**
```

## Resources

- [Ralph Loop Pattern](https://github.com/anthropics/claude/blob/main/docs/patterns/ralph-loop.md)
- [Iterative Development](https://martinfowler.com/bliki/Iterative.html)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)
