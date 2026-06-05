# Stage reference: Codebase Exploration

> Loaded on demand by the `/team` interpreter for the `exploration` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

**🚫 Delegate, don't DIY.** Your first action for this stage is the Task call(s). Do NOT read code / run git / grep yourself "to give the agent context" — the agent gathers its own context. Recon-before-delegate is how the orchestrator absorbs the task and the subagent never runs.

### PHASE 2: CODEBASE EXPLORATION (Parallel)

**Goal**: Deeply understand relevant code and patterns

**Actions**:
1. Launch **2-3 agents IN PARALLEL**, each exploring different aspects:

   ```
   Agent 1 (analyst):
   "Find features similar to [feature] and trace their implementation.
    Return list of 5-10 essential files to read."

   Agent 2 (tech-researcher):
   "Map the architecture and abstractions for [area].
    Return list of 5-10 essential files to read."

   Agent 3 (analyst):
   "Analyze the current implementation of [related feature].
    Return list of 5-10 essential files to read."
   ```

2. After ALL agents return:
   - **Read all identified files** to build deep context
   - Synthesize findings into comprehensive summary

3. **For BUG_FIX/INVESTIGATION tasks**, launch **diagnostics agent** instead:
   ```
   Agent (diagnostics):
   "Investigate the error: [error description/stacktrace].
    Run 5-phase diagnostic workflow:
    1. Static analysis of relevant code
    2. System commands (build, logs, tests)
    3. Add temporary debug instrumentation
    4. Runtime analysis
    5. Localize root cause with proposed fix"
   ```

**Output**:
- Architecture patterns found (for features)
- Similar features and their approaches
- Key files and their purposes
- Integration points
- Technology decisions
- **For bugs**: Root cause analysis and proposed fix

**Checkpoint**: Present findings, proceed to Phase 3 (or Phase 2.5 for bugs)

---

