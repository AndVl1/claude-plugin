# Stage reference: Diagnostics

> Loaded on demand by the `/team` interpreter for the `diagnose` stage (bug-fix / debug-cycle).
> Governance lives in `commands/team.md`. This file holds the prompt template / criteria.

---

Launch the **diagnostics** agent to find the root cause before any code change.

```
Agent (diagnostics):
"Investigate: [error description / stacktrace / expected-vs-actual].
 Run the 5-phase diagnostic workflow:
 1. Static analysis of relevant code
 2. System commands (build, logs, tests)
 3. Add temporary debug instrumentation
 4. Runtime analysis
 5. Localize root cause with a proposed fix"
```

**Root-cause gate (`root_cause_documented`) — MANDATORY before implementation:**

- Write `diagnosis.root_cause` to `.work-state/artifacts/diagnosis.json`: **what** the root
  cause is and **why** the proposed fix closes it rather than masking the symptom.
- Do at least **2 iterations** of repro/log evidence before proposing the fix.
- This directly answers the "опять мимо" (fix-the-symptom) failure mode. A PreToolUse(Edit)
  reminder nudges this for BUG_FIX tasks.

**Produces**: `diagnosis` (root_cause, evidence, proposed_fix, verification_checklist) and
`dod` (the Definition of Done — for a bug, minimum items: root cause named; repro-before
reproduces; repro-after does not; affected scenario checked in manual-qa). See
`workflows/artifacts-schema.json`.
