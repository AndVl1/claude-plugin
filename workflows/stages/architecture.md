# Stage reference: Architecture Design

> Loaded on demand by the `/team` interpreter for the `architecture` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

**🚫 Delegate, don't DIY.** Your first action for this stage is the Task call(s). Do NOT read code / run git / grep yourself "to give the agent context" — the agent gathers its own context. Recon-before-delegate is how the orchestrator absorbs the task and the subagent never runs.

### PHASE 4: ARCHITECTURE DESIGN

**Architect count — conditional on complexity (design choice C):**

| complexity | profile | architects |
|-----------|---------|-----------|
| MEDIUM | `standard` | **1** — single `architect`, proposes one design |
| COMPLEX / CRITICAL | `full-feature` | **3** — a parallel consilium of named variants |

The three variants are distinct **roles** — `architect_minimal`, `architect_clean`,
`architect_pragmatic` — that all resolve to the same `architect` agent (see the `roles` map in
`team.config.example.json`). They differ only by the prompt/focus below. Naming them (instead of
repeating `"architect"` three times) makes the consilium self-documenting and lets a project
remap or drop a variant without touching the profile's shape.

**Goal**: Design multiple approaches, let user choose (COMPLEX); or propose one (MEDIUM).

**Actions**:
1. Launch the architect agent(s). For `full-feature`, launch all three variants **IN PARALLEL**:

   ```
   architect_minimal:
   "Design [feature] with MINIMAL CHANGES approach.
    Focus: Smallest change, maximum reuse of existing code.
    Provide: Component design, files to modify, implementation steps."

   architect_clean:
   "Design [feature] with CLEAN ARCHITECTURE approach.
    Focus: Maintainability, elegant abstractions, testability.
    Provide: Component design, files to create/modify, implementation steps."

   architect_pragmatic:
   "Design [feature] with PRAGMATIC BALANCE approach.
    Focus: Speed + quality balance, reasonable abstractions.
    Provide: Component design, files to modify, implementation steps."
   ```

   For `standard` (MEDIUM), launch a single `architect` producing one design (no consilium).

2. Review all approaches
3. Form your recommendation based on:
   - Codebase findings
   - User's constraints
   - Task complexity
   - Team context

4. Present to user:
   ```
   I've designed 3 approaches:

   APPROACH 1: Minimal Changes
   - [Summary]
   - Pros: [...]
   - Cons: [...]
   - Files: [list]

   APPROACH 2: Clean Architecture
   - [Summary]
   - Pros: [...]
   - Cons: [...]
   - Files: [list]

   APPROACH 3: Pragmatic Balance
   - [Summary]
   - Pros: [...]
   - Cons: [...]
   - Files: [list]

   MY RECOMMENDATION: Approach [N] because [reasoning]

   Which approach would you like to use?
   ```

**Checkpoint**: ✋ WAIT for user to choose approach

---


### DoD fan-in (source: architecture)

**Append** technical acceptance criteria to `.work-state/artifacts/dod.json`: performance
budgets, API-contract guarantees, failure modes / degradation behavior. Use
`source: "architecture"` and `id: "architecture-<n>"`; bump `updated_at`. Do not renumber
existing items. See `commands/team.md` § Multi-source fan-in.
