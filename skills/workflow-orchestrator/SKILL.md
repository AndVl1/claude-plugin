---
name: workflow-orchestrator
description: Task planning and workflow orchestration patterns - use to plan multi-step tasks, create workflows, coordinate agents, and manage complex development processes
---

# Workflow Orchestrator Patterns

## Workflow Types

### 1. Linear Workflow (Sequential)
最适合线性任务，每个步骤依赖前一步完成

**Pattern:**
```markdown
## Task Plan (Linear Workflow)

### Step 1: Setup
- [ ] Initialize repository
- [ ] Install dependencies
- [ ] Configure environment

### Step 2: Core Implementation
- [ ] Create base structure
- [ ] Implement core functionality
- [ ] Add basic tests

### Step 3: Refinement
- [ ] Optimize performance
- [ ] Improve error handling
- [ ] Add logging

### Step 4: Deployment
- [ ] Build Docker image
- [ ] Deploy to staging
- [ ] Run integration tests

**When to use:**
- New features from scratch
- Small bug fixes
- Simple refactoring

---

### 2. Branching Workflow (Parallel)
需要并行开发多个功能或多个模块

**Pattern:**
```markdown
## Task Plan (Branching Workflow)

### Branch A: Backend API
- [ ] Design API endpoints
- [ ] Implement controllers
- [ ] Write unit tests
- [ ] Update documentation

### Branch B: Frontend UI
- [ ] Create component library
- [ ] Build main views
- [ ] Add state management
- [ ] Implement routing

### Branch C: Testing
- [ ] Create test suites
- [ ] Run integration tests
- [ ] Fix bugs
- [ ] Document issues

**When to use:**
- Split feature development
- Parallel API and UI implementation
- Team collaboration
```

---

### 3. Iterative Workflow (Ralph Loop)
渐进式优化，每次迭代改进

**Pattern:**
```markdown
## Task Plan (Iterative Workflow)

### Iteration 1: MVP
- [ ] Basic functionality
- [ ] Simple UI
- [ ] Manual testing
- [ ] Deploy to staging

### Iteration 2: Enhancement
- [ ] Add error handling
- [ ] Improve UX
- [ ] Automated tests
- [ ] Performance baseline

### Iteration 3: Optimization
- [ ] Optimize critical paths
- [ ] Add caching
- [ ] Load testing
- [ ] Documentation

### Iteration 4: Polish
- [ ] Final UX improvements
- [ ] Security audit
- [ ] Production deployment
- [ ] Monitoring setup

**When to use:**
- Complex features
- User feedback loops
- Continuous improvement
- Scalability planning
```

---

### 4. Event-Driven Workflow
基于事件触发的工作流程

**Pattern:**
```markdown
## Task Plan (Event-Driven Workflow)

### Events
1. **User Registration**
   - [ ] Create user account
   - [ ] Send welcome email
   - [ ] Generate welcome message
   - [ ] Add to analytics

2. **Order Placed**
   - [ ] Process payment
   - [ ] Create order record
   - [ ] Update inventory
   - [ ] Send confirmation
   - [ ] Trigger notification

3. **Payment Failed**
   - [ ] Send error notification
   - [ ] Log event for review
   - [ ] Attempt retry
   - [ ] Update status

**When to use:**
- Event-driven architecture
- Microservices
- Async processing
- Real-time updates
```

---

## Task Decomposition Strategy

### From Idea to Implementation

**Example: Create REST API**

```markdown
## Task: REST API for User Management

### Phase 1: Analysis
- [ ] Gather requirements
- [ ] Design data model
- [ ] Define API contract
- [ ] Identify edge cases

### Phase 2: Design
- [ ] Design database schema
- [ ] Plan API endpoints
- [ ] Define error responses
- [ ] Plan validation rules

### Phase 3: Implementation
- [ ] Create entities
- [ ] Implement repositories
- [ ] Build service layer
- [ ] Create controllers
- [ ] Add validation

### Phase 4: Testing
- [ ] Unit tests
- [ ] Integration tests
- [ ] API documentation
- [ ] Load testing

### Phase 5: Deployment
- [ ] Code review
- [ ] CI/CD pipeline
- [ ] Staging deployment
- [ ] Production deployment
```

---

## Coordination Patterns

### 1. Sequential Coordination (Agent Chain)
一个agent做完后，下一个agent继续

```markdown
## Workflow: Code Review Process

**Step 1: Code Analysis (developer)**
- [ ] Review implementation
- [ ] Identify issues
- [ ] Suggest improvements

**Step 2: Security Check (security-tester)**
- [ ] Scan for vulnerabilities
- [ ] Check dependencies
- [ ] Review patterns

**Step 3: Documentation (tech-researcher)**
- [ ] Review code comments
- [ ] Check documentation
- [ ] Suggest improvements
```

### 2. Parallel Coordination (Agent Pool)
多个agent同时工作不同任务

```markdown
## Workflow: Feature Development

**Agent 1 (analyst):** Requirements analysis
**Agent 2 (architect):** System design
**Agent 3 (developer):** Backend implementation
**Agent 4 (frontend-developer):** Frontend implementation
**Agent 5 (qa):** Test preparation

**Coordination:**
- [ ] Parallel analysis and design
- [ ] Handoff to developers
- [ ] Continuous integration
- [ ] Final review
```

### 3. Feedback Loop (Ralph Loop)
迭代式改进

```markdown
## Workflow: Bug Fix with Iteration

**Iteration 1:**
- [ ] Analyze bug report
- [ ] Reproduce issue
- [ ] Implement fix
- [ ] Test locally
- [ ] Commit changes

**Iteration 2:**
- [ ] Review code changes
- [ ] Check for regressions
- [ ] Improve error handling
- [ ] Update tests
- [ ] Document the fix

**Iteration 3:**
- [ ] Run full test suite
- [ ] Performance check
- [ ] User acceptance
- [ ] Deploy to staging
```

---

## State Management

### Tracking Progress

```markdown
## Team State

### Current Task
**Feature:** User Authentication
**Branch:** feature/auth
**Status:** In Progress

### Workflow
- [x] Phase 1: Analysis (completed)
- [x] Phase 2: Design (completed)
- [ ] Phase 3: Implementation (in progress)
- [ ] Phase 4: Testing (pending)
- [ ] Phase 5: Deployment (pending)

### Agents
- analyst: ✅ Completed
- architect: ✅ Completed
- developer: 🔄 In progress
- qa: ⏳ Pending
```

---

## Best Practices

### ✅ DO
- Start with clear requirements
- Break tasks into manageable steps
- Use consistent naming
- Document decisions
- Update state regularly
- Communicate blockers

### ❌ DON'T
- Don't skip requirements gathering
- Don't work on multiple large features simultaneously
- Don't skip testing
- Don't make assumptions without validation
- Don't change requirements mid-implementation

---

## Workflow Templates

### Template 1: New Feature
```markdown
## Workflow: Implement New Feature

### Phase 1: Understanding
- [ ] Read requirements
- [ ] Ask clarifying questions
- [ ] Identify edge cases

### Phase 2: Planning
- [ ] Create task breakdown
- [ ] Identify dependencies
- [ ] Plan testing strategy

### Phase 3: Implementation
- [ ] Create feature branch
- [ ] Implement core logic
- [ ] Add error handling
- [ ] Write tests

### Phase 4: Review
- [ ] Self-review code
- [ ] Run tests
- [ ] Fix issues
- [ ] Update documentation

### Phase 5: Integration
- [ ] Merge to main
- [ ] Update changelog
- [ ] Deploy to staging
- [ ] User testing
```

### Template 2: Bug Fix
```markdown
## Workflow: Fix Bug

### Phase 1: Investigation
- [ ] Read bug report
- [ ] Reproduce issue
- [ ] Identify root cause
- [ ] Check existing tests

### Phase 2: Fix Design
- [ ] Plan solution
- [ ] Identify affected areas
- [ ] Plan test coverage

### Phase 3: Implementation
- [ ] Create fix
- [ ] Update tests
- [ ] Run full suite
- [ ] Check for regressions

### Phase 4: Verification
- [ ] Verify fix
- [ ] Test edge cases
- [ ] Document change

### Phase 5: Deployment
- [ ] Code review
- [ ] Deploy to staging
- [ ] Monitor logs
- [ ] Production deploy
```

---

## Common Workflows

### Workflow: API Development
```markdown
## Workflow: REST API Development

1. **API Design**
   - [ ] Define endpoints
   - [ ] Design request/response
   - [ ] Specify validation rules

2. **Implementation**
   - [ ] Create entity
   - [ ] Implement repository
   - [ ] Build service
   - [ ] Create controller

3. **Testing**
   - [ ] Unit tests
   - [ ] Integration tests
   - [ ] API documentation

4. **Deployment**
   - [ ] Build & push
   - [ ] Deploy service
   - [ ] Update documentation
```

### Workflow: Frontend Feature
```markdown
## Workflow: Frontend Feature Development

1. **Planning**
   - [ ] Read requirements
   - [ ] Design component structure
   - [ ] Plan state management

2. **Implementation**
   - [ ] Create components
   - [ ] Implement state logic
   - [ ] Add validation
   - [ ] Style UI

3. **Testing**
   - [ ] Component tests
   - [ ] Integration tests
   - [ ] E2E tests

4. **Deployment**
   - [ ] Build assets
   - [ ] Deploy to CDN
   - [ ] Update docs
```

---

## Tools & Resources

### Planning Tools
- Jira / Linear
- Trello
- Asana
- GitHub Projects

### Workflow Templates
- Kanban boards
- Gantt charts
- Swimlane diagrams

### Documentation
- README.md
- CONTRIBUTING.md
- API documentation
- Architecture docs

---

## Questions to Ask Before Starting

1. **What is the scope?**
   - What needs to be built?
   - What doesn't need to be built?

2. **What are the constraints?**
   - Time available?
   - Resources available?
   - Technology constraints?

3. **What are the dependencies?**
   - External dependencies?
   - Internal dependencies?
   - Team dependencies?

4. **What is the success criteria?**
   - What makes it complete?
   - What defines quality?
   - How will we measure success?

5. **What are the risks?**
   - What could go wrong?
   - What mitigation strategies exist?
   - What are contingency plans?
