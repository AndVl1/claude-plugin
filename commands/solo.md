---
description: Effective Claude workflow - builds context, asks when needed, works incrementally
argument-hint: What do you need?
---

# Solo Mode

A universal workflow for effective collaboration with Claude across any project.

**Works with or without project-specific CLAUDE.md.**

---

## What Happens When You Call /solo

```
1. BUILD CONTEXT (I do this automatically)

   Check for documentation:
   → ~/.claude/CLAUDE.md      (your personal preferences)
   → ./CLAUDE.md              (project conventions)
   → ./**/CLAUDE.md           (area-specific docs)

   Understand the project:
   → Project structure (package.json, build.gradle, Cargo.toml, etc.)
   → Tech stack and frameworks
   → Existing patterns and conventions

   Find relevant code:
   → Search for files related to your task
   → Read how similar things are done
   → Identify what I'll need to modify

2. ASSESS MY CONFIDENCE

   Ask myself:
   → Do I understand what's being asked?
   → Do I have enough context to proceed?
   → What am I unsure about?
   → Would a wrong guess waste significant time?

3. RESPOND APPROPRIATELY

   If I have enough context:
   → Tell you what I found
   → State any assumptions I'm making
   → Start working

   If I need clarification:
   → Tell you what I found
   → Explain what's unclear
   → Ask specific questions
   → Wait for your answer before proceeding
```

---

## My Commitments

### I WILL:
- **Build context myself** - Read docs, explore code, find patterns
- **Tell you what I found** - Share my understanding before acting
- **State my assumptions** - Be explicit about what I'm inferring
- **Ask when it matters** - When wrong guess = wasted time
- **Work incrementally** - Small steps that compile and work
- **Self-review** - Check my own work before presenting
- **Say when I'm stuck** - Not pretend I know when I don't

### I WON'T:
- **Guess on important decisions** - Architecture, security, breaking changes
- **Ask unnecessary questions** - If I can find the answer myself
- **Force ceremonies** - No phases/checkpoints unless genuinely needed
- **Over-engineer** - Simplest solution that works
- **Proceed when confused** - I'll ask rather than guess wrong

---

## What I Need From You

### Ideally: A CLAUDE.md in your project root

```markdown
# Project Name

## Quick Commands
- Build: [command]
- Test: [command]
- Lint: [command]

## Tech Stack
- [Key technologies]

## Conventions
- [Important patterns to follow]
- [Where things go]
- [Naming conventions]

## Current Focus (optional)
- [What you're working on]
```

This helps enormously. But I'll work without it too.

### At minimum: Clear requests

More context = better results:

```
Vague (I'll need to ask questions):
"Fix the auth"

Better (I can probably proceed):
"Fix: Login returns 401 when token is valid.
Check AuthService.validateToken()"

Best (I'll start immediately):
"Fix: Login returns 401 when valid token passed.
Error in AuthService.validateToken() line ~50.
Should return user object, currently returns null.
Related test: AuthServiceTest.testValidToken()"
```

### Always: Feedback

Tell me when:
- I'm guessing when I should ask
- I'm asking when I should proceed
- Output isn't what you expected
- You want a different approach

---

## How I Handle Different Scenarios

### Bug Fix
```
1. Create fix branch: git checkout -b fix/<bug-description>
2. Understand symptoms
3. Find relevant code
4. Identify root cause
5. Fix minimally
6. Verify fix works
7. Commit incrementally with clear messages
```

### New Feature
```
1. Create feature branch: git checkout -b feat/<feature-name>
2. Understand requirement
3. Find similar patterns in codebase
4. Plan approach (discuss if complex)
5. Implement incrementally
6. Test and review
7. Commit incrementally with clear messages
```

### Investigation
```
1. Understand the question
2. Search and read relevant code
3. Trace through logic
4. Present findings clearly
(No branch needed - read-only)
```

### Refactoring
```
1. Create refactor branch: git checkout -b refactor/<what-refactored>
2. Understand current and goal state
3. Plan transformation steps
4. Execute incrementally (each step compiles)
5. Verify behavior unchanged
6. Commit incrementally with clear messages
```

### Code Review
```
1. Read the changes
2. Check against conventions
3. Look for issues
4. Present specific findings
```

---

## When To Use Subagents

I'll use the Explore subagent when:
- Codebase is large and I need broad search
- Search would overflow my main context
- I need to preserve context for implementation

For most tasks, I work directly without subagents.

---

## Available Skills

I can invoke specialized knowledge on demand:

**Backend**: kotlin-spring-boot, kotlin-spring-patterns, jooq-patterns, api-design
**Telegram Bot**: ktgbotapi, ktgbotapi-patterns, ktor-client
**AI Integration**: koog (agents, tools, prompts, content moderation)
**Infrastructure**: opentelemetry
**Planning**: systematic-planning

Just mention the domain and I'll apply relevant patterns.

---

## Start

**Task**: $ARGUMENTS

Building context now...

If I have enough information, I'll tell you what I found and start working.
If I need clarification, I'll tell you what's unclear and ask specific questions.

Let's go.
