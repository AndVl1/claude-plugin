# Stage reference: Discovery

> Loaded on demand by the `/team` interpreter for the `discovery` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

### PHASE 1: DISCOVERY

**Goal**: Understand what needs to be built

**Actions**:
1. **Create feature branch** (MANDATORY for FEATURE/REFACTOR tasks):
   - Check current branch: `git branch --show-current`
   - If not on main, switch: `git checkout main && git pull origin main`
   - Create feature branch: `git checkout -b feat/<descriptive-name>`
   - For bug fixes use: `fix/<bug-description>`
   - For refactoring use: `refactor/<what-refactored>`
   - Skip this step only for: INVESTIGATION, REVIEW, HOTFIX (emergency fixes can be on main)

2. Create todo list with all phases

3. If request unclear, ask:
   - What problem are you solving?
   - What should the feature do?
   - Any constraints or requirements?

4. Summarize understanding and confirm

**Output**:
- Feature branch created (if applicable)
- Clear, confirmed feature description

**Checkpoint**: ✋ WAIT for user confirmation before Phase 2

---

