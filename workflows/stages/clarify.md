# Stage reference: Clarifying Questions

> Loaded on demand by the `/team` interpreter for the `clarify` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

### PHASE 3: CLARIFYING QUESTIONS

**Goal**: Resolve ALL ambiguities before design

**CRITICAL: DO NOT SKIP THIS PHASE FOR COMPLEX FEATURES**

**Actions**:
1. Review codebase findings + original request
2. Identify underspecified aspects:
   - Edge cases
   - Error handling
   - Integration points
   - Backward compatibility
   - Performance requirements
   - Security considerations
3. Present ALL questions in organized list

**Example**:
```
Before designing architecture, I need to clarify:

1. SCOPE: Should this integrate with [existing feature] or be standalone?
2. EDGE CASES: What happens when [scenario]?
3. ERROR HANDLING: How should [failure case] be handled?
4. PERFORMANCE: Any latency/throughput requirements?
5. SECURITY: Does this handle sensitive data?

Please answer these before I proceed.
```

**Checkpoint**: ✋ WAIT for user answers. Do not proceed until answered.

---

