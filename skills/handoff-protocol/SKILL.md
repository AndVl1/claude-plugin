---
name: handoff-protocol
description: Structured context handoff between agents - ensures no information loss during phase transitions
---

# Handoff Protocol Skill

Ensure seamless context transfer between agents during multi-phase workflows.

## Why

When multiple agents work sequentially, critical context gets lost:
- Diagnostics finds root cause → Developer doesn't see the evidence
- Architect designs API → Frontend doesn't see the DTOs
- Code-reviewer finds issues → Developer fixing doesn't see original context

**Solution:** Standardized handoff format that preserves all essential information.

## Handoff Structure

```markdown
## 📦 HANDOFF: [From Agent] → [To Agent]

### Context
- **Phase**: [Current phase number]
- **Task**: [Brief task description]
- **Timestamp**: [ISO timestamp]

### INPUT (What I received)
- Requirements: [Key requirements from previous agent/user]
- Constraints: [Technical/business constraints]
- Files Analyzed: [List of files with brief purpose]

### OUTPUT (What I produced)
- Summary: [2-3 sentence summary of work done]
- Files Modified: [List with what changed in each]
- Files Created: [List with purpose]
- Key Decisions: [Important decisions made]

### HANDOFF (What you need)
- Essential Context: [Must-know information for next agent]
- API Contract: [If applicable - endpoints, DTOs, types]
- Code Patterns: [Patterns to follow from existing code]
- Edge Cases: [Known edge cases to handle]
- Dependencies: [External services/libraries needed]

### METRICS
- Files Changed: [N]
- Lines Added: [N]
- Lines Removed: [N]
- Confidence: [0-100%]
- Time Spent: [N minutes]

### VERIFICATION CHECKLIST
- [ ] Build passes
- [ ] Tests pass (if any)
- [ ] No regressions introduced
- [ ] Code follows project conventions
```

## Usage in Workflows

### Phase 2 → Phase 4 Handoff (Exploration → Architecture)

**From:** tech-researcher/analyst
**To:** architect

```markdown
## 📦 HANDOFF: Exploration → Architecture

### Context
- **Phase**: 2 → 4
- **Task**: Add user notification preferences
- **Timestamp**: 2026-02-27T03:15:00Z

### INPUT
- Requirements: Users should control notification channels
- Constraints: Must work with existing notification service
- Files Analyzed:
  - NotificationService.kt - Sends notifications
  - User.kt - User entity with preferences stub
  - NotificationController.kt - REST API for notifications

### OUTPUT
- Summary: Found existing notification infrastructure, need to add preference layer
- Files Modified: None (exploration only)
- Key Decisions: Reuse NotificationService, add PreferenceService layer

### HANDOFF
- Essential Context: NotificationService uses channel-based routing
- API Contract: 
  - GET /api/v1/users/{id}/preferences → UserPreferencesDto
  - PUT /api/v1/users/{id}/preferences → UserPreferencesDto
- Code Patterns: Repository pattern with JOOQ, Service layer with Spring
- Edge Cases: Handle users with no preferences (use defaults)
- Dependencies: Spring Boot, JOOQ, existing notification module

### METRICS
- Files Changed: 0
- Confidence: 85%
- Time Spent: 8 minutes
```

### Phase 4 → Phase 5 Handoff (Architecture → Implementation)

**From:** architect
**To:** developer

```markdown
## 📦 HANDOFF: Architecture → Backend Implementation

### Context
- **Phase**: 4 → 5
- **Task**: Implement user notification preferences
- **Timestamp**: 2026-02-27T03:25:00Z

### INPUT
- Requirements: Users can toggle email/push/in-app notifications
- Constraints: Must not break existing notification flow
- Files Analyzed: [from Phase 2 handoff]

### OUTPUT
- Summary: Designed preference layer with clean separation
- Files Modified: None (design only)
- Key Decisions:
  - Use separate NotificationPreference entity
  - Add caching for preference lookups
  - Default to enabled for new users

### HANDOFF
- Essential Context: PreferenceService intercepts before NotificationService sends

- API Contract:
```kotlin
// DTO
data class UserPreferencesDto(
    val userId: Long,
    val emailEnabled: Boolean = true,
    val pushEnabled: Boolean = true,
    val inAppEnabled: Boolean = true
)

// Endpoints
GET /api/v1/users/{id}/preferences → UserPreferencesDto
PUT /api/v1/users/{id}/preferences → UserPreferencesDto

// Service method to add
fun NotificationService.sendIfEnabled(userId: Long, notification: Notification)
```

- Code Patterns:
  - Service layer for business logic
  - JOOQ for database access
  - Cache aside pattern with Caffeine

- Edge Cases:
  - User deleted but preferences exist (cascade delete)
  - Preference check fails (default to enabled)
  - Concurrent preference updates (optimistic locking)

- Dependencies:
  - Spring Boot 3.2
  - JOOQ (existing)
  - Caffeine cache (add to build.gradle)

### METRICS
- Files Changed: 0
- Confidence: 90%
- Time Spent: 12 minutes

### VERIFICATION CHECKLIST
- [ ] Build passes (after implementation)
- [ ] Unit tests for PreferenceService
- [ ] Integration test for API endpoints
```

### Phase 5 → Phase 6 Handoff (Implementation → Review)

**From:** developer
**To:** qa / code-reviewer

```markdown
## 📦 HANDOFF: Implementation → Review

### Context
- **Phase**: 5 → 6
- **Task**: User notification preferences implementation
- **Timestamp**: 2026-02-27T03:45:00Z

### INPUT
- Architecture: PreferenceService layer with caching
- API Contract: [from Phase 4 handoff]

### OUTPUT
- Summary: Implemented preference layer with full CRUD and caching
- Files Modified:
  - NotificationPreference.kt (NEW) - Entity
  - PreferenceService.kt (NEW) - Business logic
  - PreferenceRepository.kt (NEW) - JOOQ repository
  - PreferenceController.kt (NEW) - REST API
  - NotificationService.kt - Added sendIfEnabled method
  - V027__notification_preferences.sql (NEW) - Migration
- Key Decisions:
  - Used Caffeine cache with 5-minute TTL
  - Optimistic locking with version field

### HANDOFF
- Essential Context: Preferences are cached, check cache invalidation logic

- Files to Review:
  - PreferenceService.kt - Core business logic
  - NotificationService.kt - Integration point (sendIfEnabled method)
  - V027__notification_preferences.sql - Database schema

- Test Coverage:
  - PreferenceServiceTest.kt - Unit tests (85% coverage)
  - PreferenceControllerTest.kt - API tests (90% coverage)

- Known Areas for Attention:
  - Cache invalidation on preference update
  - Transaction boundary in updatePreference method
  - Null handling in sendIfEnabled

### METRICS
- Files Changed: 6
- Lines Added: 342
- Lines Removed: 8
- Confidence: 88%
- Time Spent: 25 minutes

### VERIFICATION CHECKLIST
- [x] Build passes
- [x] Unit tests pass
- [x] Integration tests pass
- [x] Code follows project conventions
```

## Integration with Team Workflow

### In team.md, add after each phase:

```markdown
### Phase N Output

After completing Phase N, generate handoff:

<use skill="handoff-protocol">
  from_agent: [current agent]
  to_agent: [next phase agent]
  phase: N
</use>
```

### State File Integration

Add handoff summary to `.claude/team-state.md`:

```markdown
## Phase N Handoff
- From: [agent]
- To: [agent]
- Key Files: [list]
- Confidence: [N%]
- [Link to full handoff]
```

## Benefits

1. **No Context Loss**: All essential information preserved
2. **Faster Onboarding**: Next agent understands task immediately
3. **Better Quality**: Reviewers see implementation context
4. **Traceability**: Clear history of decisions and changes
5. **Debugging**: Easy to trace issues through phases

## Token Efficiency

Handoffs are structured but concise:
- Essential context: 2-3 sentences
- API contracts: Code blocks (not prose)
- Files: List with one-line descriptions
- No redundant explanations

Target: 500-800 tokens per handoff (vs 1500+ for unstructured handoffs)

## Anti-Patterns to Avoid

❌ **Wall of text** - Be concise, use bullet points
❌ **Missing metrics** - Always include confidence and files changed
❌ **No verification** - Checklist ensures quality
❌ **Overspecifying** - Let next agent make appropriate decisions
❌ **Skipping context** - Include constraints and edge cases

## Future Enhancements

1. **Automatic handoff generation** from git diff
2. **Cross-session persistence** for long-running tasks
3. **Handoff compression** for token-critical scenarios
4. **Confidence aggregation** across phases
5. **ML-based context extraction** for large changesets
```
