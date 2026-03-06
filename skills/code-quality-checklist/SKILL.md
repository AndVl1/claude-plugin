---
name: code-quality-checklist
description: Comprehensive code quality checklist - use when refactoring, reviewing code, improving maintainability, fixing technical debt, or setting code quality standards
---

# Code Quality Checklist Skill

## Overview

This skill provides a comprehensive checklist for code quality improvements. Use it when:
- Refactoring existing code
- Reviewing PRs
- Improving code maintainability
- Fixing technical debt
- Setting code quality standards

## Core Principles

1. **Readability first** — Code should be easy to understand
2. **Minimal changes** — Only modify what's necessary
3. **Consistency** — Follow existing patterns and conventions
4. **Testability** — Ensure new code is testable
5. **Documentation** — Add docs where needed

## Checkpoint Categories

### 1. Naming Conventions ✅
- [ ] Variable/Function names are descriptive and follow camelCase/snake_case
- [ ] Constants are UPPER_SNAKE_CASE
- [ ] Class names are PascalCase
- [ ] Booleans start with `is`, `has`, `can`
- [ ] Collections end with `s` or `List`
- [ ] No magic numbers or strings (use constants)

### 2. Code Structure ✅
- [ ] One responsibility per function/method
- [ ] Functions are short (< 20 lines typical)
- [ ] Classes are focused and cohesive
- [ ] Proper indentation and spacing
- [ ] Import statements are sorted and grouped

### 3. Error Handling ✅
- [ ] All exceptions are caught and handled appropriately
- [ ] Error messages are descriptive
- [ ] No swallowing exceptions (empty catch blocks)
- [ ] Proper use of try-catch-finally
- [ ] Resource cleanup (try-with-resources, finally blocks)

### 4. Type Safety ✅
- [ ] Proper use of nullable types (Kotlin: `?`, Java: `@Nullable`)
- [ ] Null checks before use
- [ ] Avoid implicit type conversions
- [ ] Use generic types correctly
- [ ] No raw types (Java)

### 5. Performance ✅
- [ ] No unnecessary loops or computations
- [ ] Database queries are optimized (indexes, pagination)
- [ ] Caching where appropriate
- [ ] String operations are efficient (avoid repeated concatenation)
- [ ] No N+1 query problems
- [ ] Memory leaks avoided (proper resource cleanup)

### 6. Security ✅
- [ ] Input validation on all user inputs
- [ ] No SQL injection (use parameterized queries)
- [ ] No XSS vulnerabilities (sanitize HTML/JS)
- [ ] Sensitive data properly protected (.env, credentials)
- [ ] No hardcoded secrets
- [ ] Authentication/Authorization checks in place
- [ ] HTTPS enforced where possible

### 7. Testability ✅
- [ ] Functions have clear input/output contracts
- [ ] Dependencies are injectable (DI)
- [ ] Business logic is separated from UI
- [ ] No hardcoded external dependencies
- [ ] Mockable components
- [ ] Edge cases handled

### 8. Documentation ✅
- [ ] Public APIs have KDoc/JavaDoc comments
- [ ] Complex logic explained
- [ ] Class-level comments for architecture
- [ ] TODO comments where necessary
- [ ] README in each module if complex

### 9. Dependency Management ✅
- [ ] Latest versions used (check `gradle.lockfile`, `package-lock.json`)
- [ ] No deprecated dependencies
- [ ] Unused dependencies removed
- [ ] Transitive dependencies reviewed
- [ ] License compatibility checked

### 10. Code Smells ✅
- [ ] No duplicate code (DRY principle)
- [ ] No overly complex functions (> 30 lines, high cyclomatic complexity)
- [ ] No God objects (classes doing too much)
- [ ] No dead code (unused imports, functions, variables)
- [ ] No commented-out code (use version control instead)
- [ ] No magic strings/numbers

### 11. Testing ✅
- [ ] Unit tests cover critical paths
- [ ] Edge cases tested
- [ ] Test names are descriptive
- [ ] No tests with hardcoded data
- [ ] Tests are fast (integration tests isolated)
- [ ] Code coverage > 70% (ideally 80-90%)

### 12. API Design (if applicable)
- [ ] RESTful conventions followed
- [ ] Proper HTTP status codes used
- [ ] Consistent response format
- [ ] Versioning strategy defined
- [ ] Rate limiting considered
- [ ] API documentation (Swagger/OpenAPI)

## Usage Workflow

### Step 1: Identify Context
```markdown
I'm refactoring [Module/Component] to improve code quality.
Current state: [Brief description]
```

### Step 2: Apply Checklist
Go through the checklist items relevant to your context. Mark what's done, what needs attention.

### Step 3: Prioritize Issues
Focus on:
1. **Security issues** (always highest priority)
2. **Critical bugs or crashes**
3. **Performance bottlenecks**
4. **Major code smells**
5. **Refactoring opportunities**

### Step 4: Create Plan
```markdown
Priority fixes:
1. Fix security issue X (takes 5 min)
2. Refactor function Y to reduce complexity (takes 15 min)
3. Add unit tests for Z (takes 20 min)
```

### Step 5: Execute
Apply fixes systematically. Commit after each major change.

### Step 6: Verify
- Run tests
- Manual review of changed code
- Check for any regressions

## Examples

### Example 1: Fixing a Code Smell

**Before:**
```kotlin
fun processData(items: List<String>): List<String> {
    val result = mutableListOf<String>()
    for (i in items.indices) {
        val item = items[i]
        if (item.isNotEmpty()) {
            result.add(item.toUpperCase())
        }
    }
    return result
}
```

**After (Applying checklist):**
```kotlin
fun processData(items: List<String>): List<String> =
    items
        .filter { it.isNotEmpty() }
        .map { it.uppercase() }

// ✅ Single responsibility
// ✅ Readable pipeline
// ✅ No magic operations
// ✅ Eliminated loop
```

### Example 2: Improving Error Handling

**Before:**
```kotlin
fun findUserById(id: String): User? {
    val stmt = conn.prepareStatement("SELECT * FROM users WHERE id = ?")
    stmt.setString(1, id)
    val rs = stmt.executeQuery()
    if (rs.next()) {
        return User(rs.getString("name"))
    }
    return null
}
```

**After:**
```kotlin
fun findUserById(id: String): User? {
    require(id.isNotEmpty()) { "User ID cannot be empty" }
    
    val stmt = try {
        conn.prepareStatement("SELECT * FROM users WHERE id = ?")
    } catch (e: SQLException) {
        log.error("Failed to create statement", e)
        return null
    }

    return try {
        stmt.setString(1, id)
        val rs = stmt.executeQuery()
        if (rs.next()) {
            User(rs.getString("name"))
        } else {
            log.debug("User not found: $id")
            null
        }
    } catch (e: SQLException) {
        log.error("Failed to query user with id: $id", e)
        null
    } finally {
        try { stmt.close() } catch (e: SQLException) { log.warn("Failed to close statement", e) }
    }
}
```

### Example 3: Improving Security

**Before:**
```kotlin
fun authenticate(username: String, password: String): Boolean {
    val user = db.users.find { it.username == username }
    return user != null && user.password == password
}
```

**After:**
```kotlin
fun authenticate(username: String, password: String): Boolean {
    // ✅ Input validation
    require(username.isNotBlank()) { "Username cannot be empty" }
    require(password.length >= 8) { "Password must be at least 8 characters" }

    // ✅ Use parameterized query to prevent SQL injection
    val user = userRepository.findByUsername(username)

    // ✅ Use password hashing (bcrypt/scrypt)
    return user != null && passwordEncoder.matches(password, user.hashedPassword)
}
```

## Integration with Other Skills

Combine with:
- **workflow-orchestrator**: Use checklist in code review phase
- **systematic-planning**: Include quality improvements in feature planning
- **openrouter-integration**: Use AI assistant to analyze code quality

## Common Patterns

### Refactoring Rule of Thumb
- **If it's working → Refactor first, test after**
- **If it's broken → Fix first, refactor later**
- **If it's complex → Simplify first, then optimize**

### Testing Rule of Thumb
- **Cover happy path first**
- **Then cover edge cases**
- **Finally add integration tests**

### Performance Rule of Thumb
- **Profile before optimizing**
- **Focus on hot paths only**
- **Measure improvement after each change**

## Maintenance

- Review this checklist quarterly
- Add platform-specific checks (e.g., iOS vs Android)
- Update based on common issues found in code reviews
- Consider adding LLM-based quality checks

## References

- [Clean Code](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Effective Java](https://www.amazon.com/Effective-Java-Joshua-Bloch/dp/0134685997)
- [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- [React Best Practices](https://react.dev/learn/thinking-in-react)
- [Spring Boot Best Practices](https://spring.io/guides/gs/spring-boot/)
