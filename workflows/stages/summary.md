# Stage reference: Summary

> Loaded on demand by the `/team` interpreter for the `summary` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

### PHASE 7: SUMMARY

**Goal**: Document accomplishments

**Actions**:
1. Mark all todos complete
2. Summarize:
   ```
   FEATURE COMPLETE: [Feature Name]

   What was built:
   - [Key functionality 1]
   - [Key functionality 2]

   Key decisions:
   - [Approach chosen and why]
   - [Trade-offs made]

   Files modified:
   - [file1] - [what changed]
   - [file2] - [what changed]

   Tests:
   - [test files added/modified]

   Suggested next steps:
   - [Recommendation 1]
   - [Recommendation 2]
   ```

3. **Git workflow completion**:
   - All changes should already be committed incrementally during Phase 5
   - Verify all commits are present: `git log --oneline`
   - If on feature branch, offer to:
     - Push branch: `git push origin <branch-name>`
     - Create PR (provide instructions or use `gh pr create`)
   - If accidentally on main (should not happen!), warn user and suggest moving to feature branch

---

