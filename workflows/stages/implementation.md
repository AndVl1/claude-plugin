# Stage reference: Implementation

> Loaded on demand by the `/team` interpreter for the `implementation` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

**🚫 Delegate, don't DIY.** Your first action for this stage is the Task call(s). Do NOT read code / run git / grep yourself "to give the agent context" — the agent gathers its own context. Recon-before-delegate is how the orchestrator absorbs the task and the subagent never runs.

### PHASE 5: IMPLEMENTATION

**Goal**: Build the feature

**DO NOT START WITHOUT USER APPROVAL**

**Actions**:
1. Update state file with chosen approach

2. **Determine implementation scope**:
   - Backend only → Launch developer
   - Frontend only (React/TS) → Launch frontend-developer
   - Frontend only (Kotlin web) → Launch developer-mobile with kotlin-web skill
   - Mobile only → Launch developer-mobile
   - Full-stack (web) → Launch developer + frontend-developer in parallel
   - Full-stack (Kotlin web) → Launch developer + developer-mobile in parallel
   - Full-stack (mobile) → Launch developer + developer-mobile in parallel
   - New mobile project → Launch init-mobile first, then developer-mobile

3. **For BACKEND implementation**, launch **developer agent**:
   ```
   Implement [feature] using [chosen approach].

   Context:
   - Codebase patterns: [from Phase 2]
   - Clarified requirements: [from Phase 3]
   - Architecture: [chosen design from Phase 4]

   Files to modify: [list from architecture]

   Requirements:
   - Follow existing codebase conventions
   - Commit incrementally (small, logical commits)
   - Each commit should compile and tests should pass
   - Use conventional commit messages (feat:, fix:, etc.)
   - Run build after implementation
   - Report all files created/modified
   ```

4. **For FRONTEND implementation**, launch **frontend-developer agent**:
   ```
   Implement [feature] Mini App UI using [chosen approach].

   Context:
   - Component patterns: [from Phase 2]
   - Clarified requirements: [from Phase 3]
   - Architecture: [chosen design from Phase 4]

   Files to modify: [list from architecture]

   Requirements:
   - Follow React/TypeScript conventions
   - Use @telegram-apps/ui components
   - Handle loading, error, empty states
   - Use proper TypeScript types (no 'any')
   - Run npm run build to verify
   - Report all files created/modified
   ```

5. **For MOBILE implementation**, launch **developer-mobile agent**:
   ```
   Implement [feature] for KMP Mobile App using [chosen approach].

   Context:
   - Architecture patterns: [from Phase 2]
   - Clarified requirements: [from Phase 3]
   - Architecture: [chosen design from Phase 4]

   Files to modify: [list from architecture]

   Requirements:
   - Follow compose-arch patterns (Screen/View/Component)
   - Use Decompose for navigation and state
   - Use Metro DI for dependency injection
   - Handle loading, error, empty states
   - Use Value<T> for component state (not StateFlow)
   - Run ./gradlew assemble to verify
   - Report all files created/modified
   ```

6. **For FULL-STACK (web) features**, launch BOTH agents IN PARALLEL:
   ```
   # Launch in parallel (single message with multiple Task tool calls)

   Agent 1 (developer):
   "Implement backend for [feature]..."

   Agent 2 (frontend-developer):
   "Implement Mini App UI for [feature]..."
   ```

   **Integration contract**: Both agents work from Architect's API design:
   - Backend creates endpoints with exact DTOs specified
   - Frontend calls endpoints with exact DTOs specified
   - Both verify against same contract

7. **For FULL-STACK (mobile) features**, launch BOTH agents IN PARALLEL:
   ```
   Agent 1 (developer):
   "Implement backend API for [feature]..."

   Agent 2 (developer-mobile):
   "Implement KMP Mobile UI for [feature]..."
   ```

   **Integration contract**: Same as web - both work from Architect's API design

8. Review implementation (backend, frontend, and/or mobile)
9. Run builds to verify
10. Ensure all changes are committed with meaningful messages

**Output**: Working implementation with all files listed

**Checkpoint**: Proceed to Phase 6

---


### DoD fan-in (close what you verified)

As the developer you mostly **close** items, not append: for every DoD item you personally
verified (compiles, lints, smoke-tested), flip its `status` `pending` → `met` and write concrete
`evidence` (build output, command run). Reference the item by `id`; bump `updated_at`. Only
append a new item if you introduced a criterion nobody else captured. See `commands/team.md`
§ Multi-source fan-in.
