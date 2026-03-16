---
name: context-persistence
description: Patterns for persisting and restoring agent context between sessions - use when building long-running agents, resuming work, or maintaining state across sessions
---

# Context Persistence Skill

Enable agents to remember, resume, and maintain context across sessions with structured persistence patterns.

## When to Use

- Long-running projects spanning multiple sessions
- Resuming interrupted work
- Maintaining user preferences and history
- Building agents that learn from past interactions
- Multi-turn conversations with state

## Core Concepts

### What to Persist

1. **Conversation State**
   - Recent messages and decisions
   - User preferences
   - Active tasks and goals

2. **Project Context**
   - File changes and decisions
   - Architecture decisions
   - Code patterns used

3. **Working Memory**
   - Current focus area
   - Pending questions
   - Next steps

4. **Long-term Memory**
   - Lessons learned
   - Common patterns
   - User preferences

## Persistence Patterns

### Pattern 1: Checkpoint Files

```markdown
# .claude/checkpoint.md

## Current Task
- Implementing user authentication
- Status: In progress (60%)
- Last action: Added JWT validation

## Context
- Using Spring Security 6.x
- JWT tokens with 24h expiry
- Refresh tokens stored in Redis

## Next Steps
1. Add refresh token endpoint
2. Implement token revocation
3. Add rate limiting

## Decisions Made
- 2026-03-15: Chose JWT over sessions (scalability)
- 2026-03-15: Redis for token blacklist (performance)

## Questions/Pending
- [ ] Confirm: Should we support multiple sessions?
- [ ] Review: Token expiry time appropriate?
```

### Pattern 2: Session State JSON

```json
{
  "sessionId": "abc123",
  "started": "2026-03-17T02:00:00Z",
  "lastActivity": "2026-03-17T03:45:00Z",
  "context": {
    "project": "training-tracker",
    "branch": "feature/auth",
    "files": ["AuthController.kt", "JwtService.kt"],
    "tests": ["AuthControllerTest.kt"]
  },
  "state": {
    "phase": "implementation",
    "progress": 0.6,
    "blockers": []
  },
  "memory": {
    "recentDecisions": [
      {"date": "2026-03-17", "decision": "Use JWT", "reason": "Scalability"}
    ],
    "pendingQuestions": [
      "Should we support multiple sessions?"
    ]
  }
}
```

### Pattern 3: Daily Notes

```markdown
# memory/2026-03-17.md

## Morning Session (02:00-04:00)

### Work Done
- Fixed markdown parser for workout data
- Deployed ai-insights to VPS
- Created error-recovery skill

### Decisions
- Chose exponential backoff for retries
- Using circuit breaker for LLM calls

### Learnings
- VPS has x86_64, RPi is arm64 - need separate builds
- OpenRouter returns JSON, need parsing

### For Next Session
- [ ] Fix OpenRouter response parsing
- [ ] Add frontend deployment
- [ ] Test AI insights with real data
```

### Pattern 4: Long-term Memory

```markdown
# MEMORY.md

## User Preferences
- Prefers TypeScript over JavaScript
- Likes detailed explanations with code examples
- Uses Telegram for notifications

## Project Patterns
- Kotlin/Spring Boot for backend
- React/Vite for frontend
- KMP for mobile
- Telegram bots with KTgBotAPI

## Lessons Learned
1. Always check architecture before building Docker images
2. Test API endpoints after deployment
3. Use semantic commit messages

## Technical Decisions
- 2026-02-21: Kotlin/Spring Boot for backend
- 2026-02-25: React/Vite for frontend
- 2026-03-07: OpenRouter for LLM calls

## Known Issues
- hypothesis-004: OpenRouter parsing incomplete
- training-tracker: Edit bug on VPS
```

## Implementation Patterns

### Session Manager

```kotlin
class SessionManager(
    private val storage: SessionStorage
) {
    suspend fun saveCheckpoint(session: Session) {
        val checkpoint = Checkpoint(
            taskId = session.currentTask?.id,
            context = session.context,
            state = session.state,
            timestamp = Instant.now()
        )
        storage.save("checkpoint-${session.id}", checkpoint)
    }
    
    suspend fun restore(sessionId: String): Session? {
        val checkpoint = storage.load<Checkpoint>("checkpoint-$sessionId")
            ?: return null
        
        return Session(
            id = sessionId,
            currentTask = checkpoint.taskId?.let { Task(it) },
            context = checkpoint.context,
            state = checkpoint.state
        )
    }
}
```

### Memory Store

```kotlin
class MemoryStore(
    private val basePath: Path = Path.of(".claude/memory")
) {
    suspend fun remember(key: String, value: Any) {
        val file = basePath.resolve("$key.json")
        file.writeText(Json.encodeToString(value))
    }
    
    suspend fun recall(key: String): Any? {
        val file = basePath.resolve("$key.json")
        if (!file.exists()) return null
        return Json.decodeFromString<Any>(file.readText())
    }
    
    suspend fun appendToDaily(entry: String) {
        val today = LocalDate.now().format(DateTimeFormatter.ISO_DATE)
        val file = basePath.resolve("$today.md")
        file.appendText("\n$entry")
    }
}
```

### Context Compression

```kotlin
class ContextCompressor {
    fun compress(messages: List<Message>): String {
        // Extract key information
        val decisions = extractDecisions(messages)
        val actions = extractActions(messages)
        val questions = extractQuestions(messages)
        
        return buildString {
            append("## Decisions\n")
            decisions.forEach { append("- $it\n") }
            
            append("\n## Actions\n")
            actions.forEach { append("- $it\n") }
            
            append("\n## Questions\n")
            questions.forEach { append("- [ ] $it\n") }
        }
    }
    
    private fun extractDecisions(messages: List<Message>): List<String> {
        return messages
            .filter { it.content.contains("decided", "chose", "selected") }
            .map { extractDecisionText(it) }
    }
}
```

## File Structure

```
project/
├── .claude/
│   ├── checkpoint.md      # Current session state
│   ├── session.json       # Session metadata
│   └── memory/
│       ├── 2026-03-17.md  # Daily notes
│       ├── 2026-03-16.md
│       └── long-term.md   # Persistent learnings
├── MEMORY.md              # Long-term memory (in workspace)
└── AGENTS.md              # Agent configuration
```

## Best Practices

### Do's ✅

1. **Save checkpoints regularly** - After significant progress
2. **Use structured formats** - JSON for data, Markdown for notes
3. **Include timestamps** - Know when things happened
4. **Compress old context** - Don't keep everything verbatim
5. **Version control memory** - Track how understanding evolves
6. **Separate concerns** - Daily notes vs long-term memory
7. **Make it readable** - Future you needs to understand it
8. **Include next steps** - Easy to resume work

### Don'ts ❌

1. **Don't persist sensitive data** - No API keys, passwords
2. **Don't save everything** - Be selective about what matters
3. **Don't ignore old context** - Read before starting new session
4. **Don't use complex formats** - Simple is better
5. **Don't forget to clean up** - Archive old sessions

## Resume Protocol

### When Resuming Work

```markdown
## Resume Checklist

1. **Read MEMORY.md** - Long-term context
2. **Read today's notes** - Recent activity
3. **Read checkpoint** - Where we left off
4. **Check git status** - Uncommitted changes
5. **Review next steps** - What was planned
6. **Ask clarifying questions** - If context unclear
```

### Resume Message Template

```markdown
# Session Resume

**Last Session:** 2026-03-16
**Duration:** 2 hours
**Focus:** Authentication implementation

## Completed
- ✅ JWT token generation
- ✅ Token validation
- ✅ Refresh token logic

## In Progress
- 🔄 Token revocation (60%)
- 🔄 Rate limiting (not started)

## Next Steps
1. Complete token revocation
2. Add rate limiting
3. Write integration tests

## Context
- Using Spring Security 6.x
- Redis for token blacklist
- 24h token expiry

**Ready to continue?**
```

## Integration Examples

### Example 1: Agent with Persistence

```kotlin
class PersistentAgent(
    private val sessionManager: SessionManager,
    private val memoryStore: MemoryStore
) {
    suspend fun start(sessionId: String?) {
        val session = sessionId?.let { 
            sessionManager.restore(it) 
        } ?: createNewSession()
        
        // Load context
        val memory = memoryStore.recall("long-term")
        val today = memoryStore.recall(LocalDate.now().toString())
        
        // Process with context
        process(session, memory, today)
        
        // Save checkpoint
        sessionManager.saveCheckpoint(session)
    }
}
```

### Example 2: Claude Code Integration

```markdown
# AGENTS.md - Your Workspace

## Every Session

Before doing anything else:

1. Read `SOUL.md` — this is who you are
2. Read `USER.md` — this is who you're helping
3. Read `memory/YYYY-MM-DD.md` (today + yesterday) for recent context
4. **If in MAIN SESSION**: Also read `MEMORY.md`

Don't ask permission. Just do it.

## Memory

- **Daily notes:** `memory/YYYY-MM-DD.md` — raw logs
- **Long-term:** `MEMORY.md` — curated memories

Capture what matters. Skip the secrets.
```

## Memory Maintenance

### Weekly Review

```markdown
## Memory Review Checklist

- [ ] Review last 7 daily notes
- [ ] Extract significant learnings to MEMORY.md
- [ ] Archive old checkpoints
- [ ] Clean up stale context
- [ ] Update user preferences if changed
- [ ] Remove completed tasks
```

### Monthly Archive

```markdown
## Archive Process

1. Create `archive/2026-03/` directory
2. Move daily notes older than 30 days
3. Compress and summarize in MEMORY.md
4. Keep recent 30 days in active memory
```

## Related Skills

- **iterative-refinement** - For improving outputs over time
- **systematic-planning** - For planning before execution
- **error-recovery** - For handling failures gracefully

---

*Context is king. Persist it wisely.*
