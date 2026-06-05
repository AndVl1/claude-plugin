# Stage reference: Review Fixes

> Loaded on demand by the `/team` interpreter for the `review_fixes` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

### PHASE 6.5: REVIEW FIXES (Conditional)

**Goal**: Fix issues identified in Phase 6 using specialized developer agents

**When to Run**: User selected (A) or (B) in Phase 6 checkpoint

**CRITICAL: Do NOT fix issues yourself. Delegate to specialized agents.**

**Actions**:
1. **Categorize issues by responsibility zone**:
   - Backend issues (Kotlin, Spring, JOOQ, API) → `developer`
   - Frontend issues (React, TypeScript, Mini App) → `frontend-developer`
   - Mobile issues (KMP, Compose, Decompose) → `developer-mobile`
   - DevOps issues (Docker, K8s, CI/CD) → `devops`
   - Security-specific fixes → appropriate developer agent based on layer

2. **Launch fix agents IN PARALLEL** for each zone with issues:

   ```
   # For BACKEND issues, launch developer agent:
   Agent (developer):
   "Fix the following issues identified during code review:

   Issues to fix:
   1. [Issue description] - [file:line]
   2. [Issue description] - [file:line]

   Context:
   - These are review findings from Phase 6
   - Follow existing codebase patterns
   - Make minimal changes to fix each issue

   Requirements:
   - Fix ONLY the specified issues
   - Do NOT refactor unrelated code
   - Run ./gradlew build after fixes
   - Commit each fix with clear message
   - Report all files modified"

   # For FRONTEND issues, launch frontend-developer agent:
   Agent (frontend-developer):
   "Fix the following issues identified during code review:

   Issues to fix:
   1. [Issue description] - [file:line]
   2. [Issue description] - [file:line]

   Context:
   - These are review findings from Phase 6
   - Follow React/TypeScript conventions
   - Make minimal changes to fix each issue

   Requirements:
   - Fix ONLY the specified issues
   - Do NOT refactor unrelated code
   - Run npm run build after fixes
   - Commit each fix with clear message
   - Report all files modified"

   # For MOBILE issues, launch developer-mobile agent:
   Agent (developer-mobile):
   "Fix the following issues identified during code review:

   Issues to fix:
   1. [Issue description] - [file:line]
   2. [Issue description] - [file:line]

   Context:
   - These are review findings from Phase 6
   - Follow compose-arch patterns strictly
   - Make minimal changes to fix each issue

   Requirements:
   - Fix ONLY the specified issues
   - Do NOT refactor unrelated code
   - Run ./gradlew assemble after fixes
   - Commit each fix with clear message
   - Report all files modified"

   # For DEVOPS issues, launch devops agent:
   Agent (devops):
   "Fix the following issues identified during code review:

   Issues to fix:
   1. [Issue description] - [file:line]

   Context:
   - These are review findings from Phase 6
   - Make minimal changes to fix each issue

   Requirements:
   - Fix ONLY the specified issues
   - Validate configurations
   - Report all files modified"
   ```

3. **Wait for all fix agents to complete**

4. **Verify fixes**:
   - Run builds for affected layers
   - Run tests if applicable

5. **Optional: Quick re-review**
   - For CRITICAL fixes, consider launching `qa` agent for spot-check
   - Only if user explicitly requested verification

**Output**:
```
Review Fixes Complete:

Backend (developer agent):
- Fixed: [issue 1]
- Fixed: [issue 2]
- Files: [list]
- Build: PASS

Frontend (frontend-developer agent):
- Fixed: [issue 1]
- Files: [list]
- Build: PASS

Mobile (developer-mobile agent):
- Fixed: [issue 1]
- Files: [list]
- Build: PASS

All issues addressed. Proceeding to Phase 7.
```

**Checkpoint**: Proceed to Phase 7

---

