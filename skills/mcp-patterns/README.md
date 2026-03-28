# MCP Patterns Skill

Comprehensive guide to Model Context Protocol (MCP) patterns for AI agent context management and external resource access.

## What is MCP?

Model Context Protocol (MCP) is a standard for enabling AI agents to access and work with external contexts, tools, and resources in a structured, portable way.

## Patterns Included

1. **Context Provider** - Structured context sharing between agents and sessions
2. **Resource Access** - External resource management (files, APIs, databases)
3. **Tool Integration** - Expose tools as MCP operations
4. **Context-aware Workflow** - Workflows with automatic context loading
5. **Context Chain** - Sequential MCP operations with context propagation
6. **Dynamic Context Loading** - Task-based context granularity
7. **Context Synchronization** - Multi-agent context sync

## Quick Start

```kotlin
// Load context for a session
val contextProvider = McpContextProvider(...)
val context = contextProvider.getContextForSession("session-123")

// Get optimized context (recent workouts only)
val optimizedContext = contextProvider.getOptimizedContext("session-123")

// Update context incrementally
contextProvider.updateContext("session-123", ContextUpdate.AddWorkout(workout))

// Get delta for synchronization
val delta = contextProvider.calculateDelta(primary, secondary)
```

## Integration

See integration examples in:
- `Claude Plugin`: Use this skill as a reference for MCP patterns
- `hypothesis-004`: Example implementation of McpContextProvider

## Resources

- [MCP Protocol Specification](https://modelcontextprotocol.io)
- [Agent Orchestration Patterns](https://docs.anthropic.com/claude/docs/agent-workflows)

## Version

v1.0.0 | Last Updated: 2026-03-29
