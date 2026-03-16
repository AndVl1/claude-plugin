---
name: code-review-checklist
description: Systematic code review checklist for quality assurance - use before committing code, during PR reviews, or when improving code quality
---

# Code Review Checklist Skill

Ensure code quality with systematic review checklists covering security, performance, maintainability, and best practices.

## When to Use

- Before committing changes
- During pull request reviews
- Improving existing code quality
- Onboarding new team members
- Post-incident reviews

## Quick Checklist

### 🔴 Critical (Must Check)

- [ ] **Security**: No hardcoded secrets, proper input validation
- [ ] **Tests**: New code has tests, existing tests pass
- [ ] **Breaking Changes**: API contracts maintained, migrations safe
- [ ] **Error Handling**: Errors caught, meaningful messages
- [ ] **Resource Cleanup**: Connections closed, memory freed

### 🟡 Important (Should Check)

- [ ] **Performance**: No N+1 queries, efficient algorithms
- [ ] **Code Style**: Follows project conventions
- [ ] **Documentation**: Complex logic explained
- [ ] **Logging**: Appropriate level, no sensitive data
- [ ] **Dependencies**: No unnecessary additions

### 🟢 Nice to Have (Consider)

- [ ] **Refactoring**: Opportunities identified
- [ ] **Type Safety**: Maximize type coverage
- [ ] **Immutability**: Prefer immutable data
- [ ] **Naming**: Clear, self-documenting names

## Language-Specific Checklists

### Kotlin/Spring Boot

```markdown
## Kotlin Checklist

### Coroutines
- [ ] Proper scope usage (viewModelScope, lifecycleScope)
- [ ] Exception handling with try/catch or CoroutineExceptionHandler
- [ ] Cancellation handling (isActive checks, non-cancelable blocks)
- [ ] Dispatcher selection (IO, Default, Main)

### Null Safety
- [ ] Minimize !! usage
- [ ] Prefer ?.let over null checks
- [ ] Use requireNotNull for preconditions
- [ ] Document nullable returns

### Spring
- [ ] @Transactional on service methods
- [ ] Proper exception handling (@ControllerAdvice)
- [ ] Validation annotations on DTOs
- [ ] OpenAPI documentation

### Testing
- [ ] Unit tests for business logic
- [ ] Integration tests for controllers
- [ ] MockK for mocking
- [ ] Testcontainers for DB tests
```

### React/TypeScript

```markdown
## React Checklist

### Components
- [ ] Props typed with interface/type
- [ ] useCallback for event handlers
- [ ] useMemo for expensive computations
- [ ] Proper dependency arrays

### State Management
- [ ] State colocated with usage
- [ ] Derived state computed, not stored
- [ ] Server state with React Query/SWR
- [ ] URL state for filters/pagination

### Performance
- [ ] No unnecessary re-renders
- [ ] Lazy loading for routes
- [ ] Image optimization
- [ ] Bundle size checked

### Accessibility
- [ ] Semantic HTML
- [ ] ARIA labels where needed
- [ ] Keyboard navigation
- [ ] Color contrast sufficient
```

### SQL/Database

```markdown
## SQL Checklist

### Query Performance
- [ ] Indexes on join/where columns
- [ ] No SELECT *
- [ ] Pagination for large results
- [ ] EXPLAIN ANALYZE for complex queries

### Data Integrity
- [ ] Foreign key constraints
- [ ] NOT NULL where appropriate
- [ ] CHECK constraints for validation
- [ ] Proper data types

### Migrations
- [ ] Backward compatible
- [ ] Rollback plan
- [ ] Data migration strategy
- [ ] Downtime consideration
```

## Review Categories

### 1. Security Review

```markdown
## Security Checklist

### Authentication & Authorization
- [ ] Auth checks on all protected endpoints
- [ ] Role-based access control
- [ ] Session management secure
- [ ] Token expiration handled

### Input Validation
- [ ] All user input sanitized
- [ ] SQL injection prevented (parameterized queries)
- [ ] XSS prevented (output encoding)
- [ ] CSRF tokens where needed

### Secrets Management
- [ ] No secrets in code
- [ ] Environment variables for config
- [ ] Secrets rotated regularly
- [ ] Logging doesn't expose secrets

### Data Protection
- [ ] PII encrypted at rest
- [ ] HTTPS enforced
- [ ] Audit logging for sensitive operations
- [ ] GDPR compliance checked
```

### 2. Performance Review

```markdown
## Performance Checklist

### Database
- [ ] N+1 queries identified and fixed
- [ ] Indexes reviewed
- [ ] Query execution plans checked
- [ ] Connection pooling configured

### Caching
- [ ] Appropriate cache headers
- [ ] Cache invalidation strategy
- [ ] Cache hit ratio acceptable
- [ ] No cache stampede risk

### Memory
- [ ] No memory leaks
- [ ] Large objects released
- [ ] Stream processing for large files
- [ ] Object pooling where beneficial

### Network
- [ ] Minimize API calls
- [ ] Compression enabled
- [ ] Keep-alive connections
- [ ] CDN for static assets
```

### 3. Maintainability Review

```markdown
## Maintainability Checklist

### Code Organization
- [ ] Single responsibility principle
- [ ] DRY - no code duplication
- [ ] Clear module boundaries
- [ ] Dependency injection used

### Naming & Documentation
- [ ] Self-documenting names
- [ ] Complex logic commented
- [ ] Public APIs documented
- [ ] README up to date

### Testing
- [ ] Unit test coverage > 70%
- [ ] Integration tests for critical paths
- [ ] Edge cases tested
- [ ] Tests are readable

### Error Handling
- [ ] Errors caught at appropriate level
- [ ] User-friendly messages
- [ ] Errors logged with context
- [ ] Graceful degradation
```

## Review Workflow

### Before Commit

```bash
# 1. Run linters
./gradlew ktlintCheck
npm run lint

# 2. Run tests
./gradlew test
npm test

# 3. Check coverage
./gradlew jacocoTestReport
npm run coverage

# 4. Security scan
./gradlew dependencyCheckAnalyze
npm audit

# 5. Self-review checklist
# Go through Quick Checklist above
```

### During PR Review

```markdown
## PR Review Template

### Overview
- What does this PR do?
- Why is it needed?

### Testing
- [ ] Tested locally
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated

### Checklist
- [ ] Security reviewed
- [ ] Performance considered
- [ ] Documentation updated
- [ ] Breaking changes documented

### Questions for Author
1. [Question about approach]
2. [Question about edge case]
3. [Suggestion for improvement]
```

### Post-Merge

```markdown
## Post-Merge Checklist

- [ ] CI/CD pipeline passed
- [ ] Deployed to staging
- [ ] Smoke tests passed
- [ ] Monitors healthy
- [ ] Documentation updated
```

## Common Issues & Fixes

### Issue: N+1 Query

```kotlin
// ❌ Bad: N+1 queries
fun getUsersWithPosts(): List<UserDTO> {
    return userRepository.findAll().map { user ->
        UserDTO(
            user = user,
            posts = postRepository.findByUserId(user.id) // N queries!
        )
    }
}

// ✅ Good: Single query with join
fun getUsersWithPosts(): List<UserDTO> {
    return userRepository.findAllWithPosts()
}
```

### Issue: Missing Null Check

```kotlin
// ❌ Bad: Potential NPE
val name = user.name!!

// ✅ Good: Safe handling
val name = user.name ?: return
// or
user.name?.let { name ->
    // use name
}
```

### Issue: Unhandled Exception

```kotlin
// ❌ Bad: Swallowed exception
try {
    doSomething()
} catch (e: Exception) {
    // Nothing
}

// ✅ Good: Proper handling
try {
    doSomething()
} catch (e: SpecificException) {
    logger.error("Failed to do something", e)
    throw BusinessException("User-friendly message", e)
}
```

## Automation

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running code review checks..."

# Run linters
./gradlew ktlintCheck || exit 1

# Run tests
./gradlew test || exit 1

# Check for secrets
if git diff --cached | grep -E "(password|secret|api[_-]?key)"; then
    echo "⚠️  Potential secrets detected!"
    exit 1
fi

echo "✅ All checks passed"
```

### CI Pipeline

```yaml
# .github/workflows/review.yml
name: Code Review

on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run linters
        run: ./gradlew ktlintCheck
        
      - name: Run tests
        run: ./gradlew test
        
      - name: Check coverage
        run: ./gradlew jacocoTestCoverageVerification
        
      - name: Security scan
        run: ./gradlew dependencyCheckAnalyze
```

## Related Skills

- **iterative-refinement** - For improving code through iteration
- **error-recovery** - For handling review failures
- **systematic-planning** - For planning review process

---

*Good code reviews catch bugs. Great code reviews teach developers.*
