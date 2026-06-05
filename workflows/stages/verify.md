# Stage reference: Debug Cycle / Verify

> Loaded on demand by the `/team` interpreter for the `verify` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

### PHASE 2.5: DEBUG CYCLE (Optional - BUG_FIX/INVESTIGATION only)

**Goal**: Iteratively fix and verify bugs with diagnostics ↔ manual-qa loop

**When to Use**:
- BUG_FIX tasks where fix needs verification
- Complex bugs with unclear reproduction
- User requests "fix and verify" or "debug cycle"

**Skip if**: Simple bug with obvious fix, or user prefers quick fix without verification

**Actions**:

1. **Diagnostics proposes fix** (from Phase 2):
   - Root cause identified
   - Fix proposed as diff
   - Verification checklist created

2. **User approves fix** → Developer applies changes:
   ```
   Agent (developer):
   "Apply the fix proposed by diagnostics:
    [paste diff or description]

    Run build to verify compilation."
   ```

3. **Manual QA verifies** (launch manual-qa):
   ```
   Agent (manual-qa):
   "Verify bug fix using diagnostics handoff:

    ## Handoff from Diagnostics
    [paste handoff section]

    Execute verification checklist.
    Test for regressions.
    Provide verdict: PASS or FAIL."
   ```

4. **Evaluate verdict**:

   **If PASS**:
   ```
   Bug fix verified. Proceeding to Phase 6.

   Files changed: [list]
   Verified by: manual-qa
   ```
   → Skip to Phase 6

   **If FAIL**:
   ```
   Agent (diagnostics):
   "Re-analyze bug with new evidence from manual-qa:

    ## Handoff from Manual QA
    [paste handoff section]

    Refine diagnosis and propose new fix."
   ```
   → Repeat from step 2

**Cycle Limit**: Maximum 3 iterations. If still failing, escalate to user for decision.

**Output**:
```
DEBUG CYCLE COMPLETE

Iterations: [N]
Final Status: PASS / ESCALATED

Fix Summary:
- Root Cause: [description]
- Solution: [description]
- Files Modified: [list]

Verification:
- Manual QA: PASS
- Evidence: [screenshots, logs]

Ready for Phase 6: Quality Review
```

**Checkpoint**: On PASS → proceed to Phase 6. On FAIL after 3 iterations → ask user.

---

