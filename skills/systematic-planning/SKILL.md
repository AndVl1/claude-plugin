---
name: systematic-planning
description: Systematic planning methodology - use to break down complex tasks, create detailed implementation plans, and ensure all aspects are considered before implementation
---

# Systematic Planning Methodology

## Planning Philosophy

Systematic planning is about **thinking before coding**. It ensures you:
- Understand the full scope
- Identify all edge cases
- Plan for testing and deployment
- Minimize rework and regressions
- Document decisions for future reference

## The 5-Step Planning Process

### Step 1: Requirements Analysis

**Goal:** Understand what needs to be built

**Questions to ask:**
1. What is the feature/problem?
2. Who is the user?
3. What problem does it solve?
4. What are the constraints?
5. What are the success criteria?

**Output:** Clear requirements document

```markdown
## Requirements: [Feature Name]

**User:** [Target user]
**Problem:** [Problem statement]
**Solution:** [Proposed solution]
**Constraints:**
- [Constraint 1]
- [Constraint 2]
**Success Criteria:**
- [Criterion 1]
- [Criterion 2]
```

### Step 2: Design

**Goal:** Create a blueprint before implementation

**Components:**
1. **Architecture:** High-level structure
2. **Data Model:** Database schema, API contracts
3. **Component Design:** Class/module structure
4. **API Design:** Endpoints, payloads
5. **Error Handling:** What can go wrong
6. **Testing Strategy:** How to verify correctness

**Output:** Design document

```markdown
## Design: [Feature Name]

### Architecture
```
┌─────────┐
│ Client  │
└────┬────┘
     │
┌────▼────┐
│ Gateway │
└────┬────┘
     │
┌────▼────┐
│ Service │
└─────────┘
```

### Data Model
```
User {
  id: UUID
  name: String
  email: String
  created_at: DateTime
}

Workout {
  id: UUID
  user_id: UUID
  name: String
  exercises: List<Exercise>
  created_at: DateTime
}
```

### API Endpoints
- `POST /api/users` - Create user
- `GET /api/users/:id` - Get user
- `PUT /api/users/:id` - Update user

### Error Handling
- 400 Bad Request - Invalid input
- 404 Not Found - Resource not found
- 500 Internal Server Error - Unexpected error
```

### Step 3: Task Breakdown

**Goal:** Divide the work into manageable pieces

**Principles:**
1. Small, focused tasks
2. Clear dependencies
3. Each task is testable
4. Avoid mixing concerns

**Output:** Task list

```markdown
## Task Breakdown: [Feature Name]

### Phase 1: Setup
- [ ] Initialize project structure
- [ ] Setup build system
- [ ] Configure database connection
- [ ] Setup testing framework

### Phase 2: Core Implementation
- [ ] Create User entity
- [ ] Create UserRepository
- [ ] Create UserService
- [ ] Create UserController
- [ ] Implement user creation endpoint
- [ ] Implement user retrieval endpoint

### Phase 3: Testing
- [ ] Write unit tests for UserService
- [ ] Write integration tests for UserController
- [ ] Write E2E tests for user flow

### Phase 4: Documentation
- [ ] Update API documentation
- [ ] Write developer guide
- [ ] Create user guide (if applicable)
```

### Step 4: Implementation Plan

**Goal:** Order the tasks for implementation

**Guidelines:**
1. Start with independent tasks
2. Build on top of working foundation
3. Test each phase before proceeding
4. Keep implementation simple and clean

**Output:** Implementation order

```markdown
## Implementation Order: [Feature Name]

**Day 1: Foundation**
1. Setup project
2. Create User entity
3. Create UserRepository
4. Run tests

**Day 2: Core Logic**
1. Create UserService
2. Implement user endpoints
3. Write tests
4. Debug and fix

**Day 3: Testing & Polish**
1. Integration tests
2. E2E tests
3. Documentation
4. Code review
```

### Step 5: Review & Iteration

**Goal:** Verify everything before finishing

**Checklist:**
- [ ] All requirements met?
- [ ] All tests passing?
- [ ] Documentation updated?
- [ ] No breaking changes?
- [ ] Performance acceptable?
- [ ] Security reviewed?

**Output:** Final review document

```markdown
## Review: [Feature Name]

**Requirements Check:**
- [x] All user stories implemented
- [x] Edge cases handled
- [x] Error messages clear

**Testing:**
- [x] Unit tests: 100% coverage
- [x] Integration tests: 100% passing
- [x] E2E tests: All scenarios covered

**Documentation:**
- [x] README updated
- [x] API documentation complete
- [x] Developer guide updated

**Code Quality:**
- [x] No code smells
- [x] Follows best practices
- [x] Clean code principles

**Decision:** APPROVED for deployment
```

## Planning Templates

### Template: New Feature
```markdown
## Planning: [Feature Name]

### Requirements
- [Requirement 1]
- [Requirement 2]
- [Requirement 3]

### Design
[Design document]

### Task Breakdown
[Task list]

### Implementation Order
[Ordered tasks]

### Review Checklist
- [ ] Requirements met
- [ ] Tests passing
- [ ] Documentation complete
- [ ] Code review passed
```

### Template: Bug Fix
```markdown
## Planning: [Bug Fix]

### Bug Description
[Bug details, steps to reproduce]

### Root Cause Analysis
[How you identified the issue]

### Fix Design
[Proposed solution]

### Testing Strategy
- [ ] Test with original bug
- [ ] Test with fix
- [ ] Test edge cases
- [ ] Check for regressions

### Review Checklist
- [ ] Bug fixed
- [ ] No new issues introduced
- [ ] Tests passing
- [ ] Documentation updated
```

### Template: Refactoring
```markdown
## Planning: [Refactoring]

### Objectives
- [Objective 1]
- [Objective 2]
- [Objective 3]

### Current State
[Describe current code]

### Desired State
[Describe improved code]

### Task Breakdown
- [ ] Extract common patterns
- [ ] Improve naming
- [ ] Reduce complexity
- [ ] Add documentation

### Risk Assessment
- [ ] Will this break anything?
- [ ] Do we have tests?
- [ ] What's the rollback plan?

### Review Checklist
- [ ] Same functionality
- [ ] Better code quality
- [ ] Tests still passing
- [ ] Documentation updated
```

## Common Planning Mistakes

### ❌ Don't skip analysis
**Mistake:** Jumping straight to implementation
**Why bad:** Leads to rework, bugs, missed requirements
**Fix:** Spend time understanding the problem

### ❌ Don't make tasks too large
**Mistake:** "Implement authentication" as a single task
**Why bad:** Hard to track progress, risk of getting stuck
**Fix:** Break into smaller subtasks

### ❌ Don't ignore edge cases
**Mistake:** Focusing only on happy path
**Why bad:** User will hit edge cases eventually
**Fix:** Identify and plan for edge cases

### ❌ Don't skip testing
**Mistake:** Testing only at the end
**Why bad:** Harder to debug, slower feedback loop
**Fix:** Test incrementally

### ❌ Don't change requirements mid-planning
**Mistake:** Adding new features while planning
**Why bad:** Messes up estimates, creates scope creep
**Fix:** Document changes and re-plan

## Planning Best Practices

### ✅ DO
- Spend time understanding requirements
- Break tasks into small, clear pieces
- Plan testing before implementation
- Document your plan
- Review and iterate
- Keep testing as you go

### ❌ DON'T
- Skip the planning phase
- Create vague, large tasks
- Focus only on happy path
- Plan without considering constraints
- Ignore testing
- Change requirements without re-planning

## Planning Tools

### Documentation
- Task trackers (Jira, Linear, GitHub Projects)
- Design docs (Notion, Confluence)
- Architecture docs (Mermaid diagrams)

### Checklists
- Requirements checklist
- Design checklist
- Testing checklist
- Review checklist

### Templates
- Feature planning template
- Bug fix planning template
- Refactoring planning template

## Questions to Ask Before Planning

1. **What is the scope?**
   - What needs to be built?
   - What doesn't need to be built?

2. **Who is the audience?**
   - Internal team or external users?
   - What are their technical skills?

3. **What constraints exist?**
   - Time available?
   - Resources available?
   - Technology constraints?

4. **How will we measure success?**
   - What defines a complete feature?
   - What defines quality?

5. **What are the risks?**
   - What could go wrong?
   - What mitigation strategies exist?
