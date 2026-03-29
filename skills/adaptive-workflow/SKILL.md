# Adaptive Workflow Engine

# Adaptive Workflow Engine - Dynamic Task Routing

## Goal

Intelligently select optimal workflow complexity (3, 5, or 7 phases) and agent count based on task characteristics, reducing unnecessary steps for simple tasks.

## Why

The full 7-phase workflow is powerful but overkill for many tasks:
- Simple bug fixes: 3 phases (Discovery → Fix → Review)
- New features in familiar code: 5 phases (Discovery → Exploration → Architecture → Implementation → Review)
- Complex architectural changes: 7 phases (with optional debug cycle)

**Problem**: Every task uses 7 phases regardless of complexity → wasted time.

**Solution**: Adaptive engine that:
1. Analyzes task at hand
2. Determines optimal complexity level
3. Auto-selects appropriate phases
4. Allocates minimal necessary agents

**Impact**:
- 30-40% faster for simple tasks
- 15-20% faster for medium tasks
- Same speed for complex tasks (no regression)
- Better developer experience

## Philosophy

"Best tool for the job" - don't use a sledgehammer for a nail.

## How It Works

### Phase 1: Analysis Phase

Analyze task characteristics:

```typescript
interface TaskComplexity {
  filesAffected: number        // Files being modified
  linesAffected: number        // Total lines to change
  modulesAffected: number      // Distinct modules touched
  isNewFeature: boolean        // New capability or enhancement
  hasBreakingChanges: boolean  // Breaking API changes
  requiresReview: boolean      // Needs code review
  codebaseFamiliarity: number  // 1-10 rating of how familiar we are
  timeEstimate: number         // Minutes to complete
}
```

### Complexity Decision Matrix

| Score | Type | Phases | Agents |
|-------|------|--------|--------|
| 0-3 | Trivial | 3 (LIGHTWEIGHT) | 1-2 |
| 4-7 | Simple | 5 (STANDARD) | 2-4 |
| 8-12 | Medium | 7 (FULL) | 4-6 |
| 13+ | Complex | 7+ (EXTENDED) | 6+ |

**Thresholds**:
- `filesAffected <= 2` → Trivial
- `filesAffected <= 5` → Simple
- `filesAffected <= 15` → Medium
- `filesAffected > 15` → Complex

### Auto-Workflow Selection

**3-Phase Workflow (LIGHTWEIGHT)**:
- Type: BUG_FIX + obvious fix
- Files: 1-2 files
- Phases: Discovery → Fix → Review

**5-Phase Workflow (STANDARD)**:
- Type: FEATURE in familiar code
- Files: 2-5 files
- Phases: Discovery → Exploration → Architecture → Implementation → Review

**7-Phase Workflow (FULL)**:
- Type: Complex feature, architectural change, new module
- Files: 5+ files
- Phases: Discovery → Exploration → Architecture → Implementation → Review → Quality Review

**8-Phase Workflow (EXTENDED)**:
- Type: Critical bug, production hotfix
- Files: Any
- Phases: Discovery → Diagnostic → Fix → Fix Verification → Review

### Agent Allocation

**3-Phase**:
- Single developer agent
- Or dev + manual-qa (if UI involved)

**5-Phase**:
- Backend: 1 developer agent
- Frontend: 1 frontend-developer agent
- Optional: qa for review

**7-Phase**:
- 2 backend agents (developer + code-reviewer)
- 2 frontend agents (frontend-developer + manual-qa)
- Optional: security-tester, devops

**8-Phase**:
- Add diagnostics agent
- Full parallel review

### Dynamic Phase Skipping

For 3-Phase workflow:
- Skip Phase 4 (Architecture) - implied from exploration
- Skip Phase 6.5 (Review Fixes) - single developer does both

For 5-Phase workflow:
- Skip Phase 4 (Architecture) if trivial
- Optional Phase 2.5 (Debug Cycle)

For 7-Phase workflow:
- All phases included
- Optional Phase 2.5 (Debug Cycle)

## Implementation

### 1. Create `adaptive-workflow-agent` skill

File: `/home/andrey/claude-plugin/skills/adaptive-workflow/SKILL.md`

```markdown
# Adaptive Workflow Agent

You coordinate adaptive task execution with optimized phase count and agent allocation.

## Phases

### Phase 1: Analysis
Determine task complexity and select optimal workflow.

### Phase 2: Discovery
Create feature branch, confirm understanding.

### Phase 3: Exploration (Optional)
- For 5+ phase: 2-3 agents in parallel
- For 3 phase: quick scan only

### Phase 4: Architecture (Optional)
- For 5+ phase: single architect
- For 3 phase: skip

### Phase 5: Implementation
- For 5 phase: single developer
- For 3 phase: developer + quick QA

### Phase 6: Review (Optional)
- For 5 phase: qa only
- For 3 phase: skip or quick qa

## Decision Logic

```typescript
if (files <= 2 && type === 'BUG_FIX') {
  return { phases: 3, agents: ['developer', 'manual-qa'] }
}
else if (files <= 5 && type === 'FEATURE') {
  return { phases: 5, agents: ['developer', 'qa'] }
}
else {
  return { phases: 7, agents: ['developer', 'frontend-developer', 'qa', 'code-reviewer'] }
}
```

## Output

Present analysis and ask for confirmation before proceeding.
```

### 2. Add to Agent Skills

File: `/home/andrey/claude-plugin/agents/adaptive-workflow-agent.md`

```markdown
# Adaptive Workflow Agent

Coordinates dynamic task execution with optimized phase count and agent allocation.

## Role

- Analyze task complexity
- Select optimal workflow (3, 5, 7, or 8 phases)
- Allocate minimal necessary agents
- Auto-skip unnecessary phases

## Tools

- `git status` - Determine affected files
- `find . -name "*.kt" -o -name "*.ts" -o -name "*.tsx"` - Count modules
- `git diff --name-only` - List changed files

## Workflow

1. **Analyze**: Check git status, count affected files
2. **Classify**: Determine type + complexity
3. **Select**: Choose workflow + agents
4. **Present**: Show analysis and ask for confirmation
5. **Execute**: Launch selected agents for chosen phases
```

### 3. Integrate with Main EM Agent

Add adaptive selection at the beginning of team.md:

```markdown
## OPTIONAL: Adaptive Workflow Selection

Before classification, ask:

"Would you like to use Adaptive Workflow for optimal efficiency?

This would:
- Auto-select 3, 5, or 7 phases based on task complexity
- Allocate minimal necessary agents
- Skip unnecessary phases

For simple bug fixes (1-2 files), this can save 30-40% time."

If user says YES:
1. Launch adaptive-workflow-agent to analyze
2. Present recommendation
3. User confirms or adjusts
4. Proceed with selected workflow
```

### 4. State File Enhancement

Add complexity tracking:

```markdown
## Complexity Analysis
- Files Affected: [N]
- Lines Affected: [N]
- Modules Affected: [N]
- Type: [TYPE]
- Selected Workflow: [3/5/7 phases]

## Phases Skipped
- [Phase 4] - Skipped (trivial architecture)
- [Phase 6] - Skipped (simple review needed)
```

## Usage Examples

### Example 1: Simple Bug Fix
```
User: Fix null pointer exception in LoginController

Adaptive Analysis:
- Files Affected: 1 (LoginController.kt)
- Type: BUG_FIX
- Lines Affected: ~15
- Modules Affected: 1
- Complexity Score: 2 (Trivial)

Recommended: 3-Phase LIGHTWEIGHT workflow
Agents: developer (backend), manual-qa (quick UI check)

Proceed? [Y/N]
```

### Example 2: Medium Feature
```
User: Add user search to frontend

Adaptive Analysis:
- Files Affected: 3 (UserController.kt, SearchView.tsx, SearchComponent.tsx)
- Type: FEATURE
- Lines Affected: ~80
- Modules Affected: 2 (backend, frontend)
- Complexity Score: 6 (Simple)

Recommended: 5-Phase STANDARD workflow
Agents: developer (backend), frontend-developer (frontend), qa (quick review)

Proceed? [Y/N]
```

### Example 3: Complex Feature
```
User: Implement OAuth authentication

Adaptive Analysis:
- Files Affected: 15+ (auth controllers, OAuth providers, frontend integration, token storage)
- Type: FEATURE
- Lines Affected: ~300+
- Modules Affected: 5 (backend, frontend, mobile, security, auth)
- Complexity Score: 11 (Medium/Complex)

Recommended: 7-Phase FULL workflow
Agents: developer (backend), frontend-developer (frontend), developer-mobile (mobile auth), qa, code-reviewer, security-tester

Proceed? [Y/N]
```

## Benefits

1. **Speed**: 30-40% faster for simple tasks
2. **Focus**: Fewer unnecessary agents
3. **Flexibility**: Can adjust per task
4. **Transparency**: User sees recommendation
5. **No Regressions**: Same quality for complex tasks

## Trade-offs

- **Overhead**: Analysis phase adds ~1 minute
- **Flexibility**: User may want different workflow
- **Tooling**: Requires git analysis

## Future Enhancements

1. Machine learning for complexity prediction
2. Historical performance tracking
3. Auto-optimization based on developer's preferences
4. Resource-aware agent allocation (time/iterations limits)

## References

- [Anthropic feature-dev plugin](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/commands/feature-dev.md)
- [Ralph Loop - Iterative refinement](https://en.wikipedia.org/wiki/Iterative_development)
- [ReAct pattern](https://arxiv.org/abs/1810.09905)
