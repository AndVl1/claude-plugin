# Stage reference: Automated Tests

> Loaded on demand by the `/team` interpreter for the `qa_tests` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

**🚫 Delegate, don't DIY.** Your first action for this stage is the Task call to the `qa` agent.

### PHASE 6.8: AUTOMATED TESTS — encode observed behavior as regression tests

**Why sequenced (v3.0):** tests are written **after** manual QA so they encode what was actually
observed working (`manual_qa.evidence`), not a guess made against unverified code. This is the
last runtime stage before summary.

**Gate** (`manual_qa.verdict == PASS || !scope.has_ui`): only write/accept tests once manual QA
passed. If the task has no UI, `manual_qa` was skipped and this gate degrades to true — tests are
written directly against the implementation.

**Input**: `manual_qa` (evidence + verdict) when present, plus `implementation` / `architecture`.

**Actions**:

1. Launch the qa agent:
   ```
   Agent (qa):
   "Write automated regression tests for the shipped change.

    Inputs:
    - manual_qa.evidence (if present) — each observed behavior becomes a test case
    - implementation.files_touched — the code under test

    Requirements:
    - encode the manually-observed behavior as durable tests (unit/integration/e2e as fits)
    - cover the acceptance criteria and any regressions manual-qa flagged
    - run the test suite; report pass/fail
    - do NOT rewrite production code — if a test reveals a defect, report it as a finding

    Produce the `qa_tests` artifact (schema `qa_tests`):
    - tests_added: files/cases added or updated
    - build_status: pass | fail | n/a
    - based_on_manual_qa: true on the has_ui path
    - coverage_note: what is and isn't covered"
   ```

2. Write `.work-state/artifacts/qa_tests.json`.

**Feeds**: `summary` consumes `qa_tests`.

---
