# Stage reference: Manual QA (on fixed code)

> Loaded on demand by the `/team` interpreter for the `manual_qa` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

**🚫 Delegate, don't DIY.** Your first action for this stage is the Task call to the `manual-qa`
agent. Do NOT open Chrome / drive the device yourself — the manual-qa agent owns the MCP tools
and auto-creates the `.manual-qa-active` marker on its first tool call.

### PHASE 6.7: MANUAL QA — sequenced, on the FIXED code

**Skip when**: `!scope.has_ui` (no frontend/mobile in scope). The interpreter skips this stage
entirely for backend-only / infra-only work.

**Why sequenced (v3.0):** manual QA no longer runs in parallel with code review. It runs **after
`review_fixes`**, so it exercises exactly the code that will ship. Its evidence then feeds the
`qa_tests` stage, which encodes what was manually observed into durable automated tests.

**Input**: the `review` (fixes applied), `implementation`, `architecture`, and — when present —
`feature_spec.acceptance_criteria` (use it as the manual test checklist).

**Actions**:

1. Launch the manual-qa agent:
   ```
   Agent (manual-qa):
   "Manually verify the shipped UI against the acceptance criteria.

    Inputs:
    - feature_spec.acceptance_criteria (if present) — treat each as a pass/fail check
    - architecture + implementation — what changed and where

    For each criterion:
    - drive the real UI (Chrome for Mini App / mobile MCP for the app)
    - capture a screenshot and state WHAT IS VISIBLE on it (inputs, outputs, errors)
    - check console + network for errors
    - check for regressions in adjacent flows

    Produce the `manual_qa` artifact (schema `manual_qa`):
    - verdict: PASS only if every criterion was observed working
    - evidence: array of concrete observations (screenshot path + what's visible)
    - regressions: anything pre-existing that broke (empty if none)
    - dod_additions: UI/visual acceptance criteria to append to dod.json (source: manual_qa)"
   ```

2. Write `.work-state/artifacts/manual_qa.json`.

**Gate** (`manual_qa.verdict != FAIL`): a `FAIL` verdict blocks progress — loop back to
`review_fixes`/implementation with the failing evidence, or escalate to the user. A missing
verdict is treated as FAIL (never auto-pass).

**Feeds**: `qa_tests` consumes `manual_qa.evidence`; `summary` consumes the verdict.

---

### DoD fan-in (source: manual_qa)

**Append** UI-visual acceptance criteria — including *what must be visible on the screenshot* —
via the `manual_qa` artifact `dod_additions[]` (which the orchestrator merges into `dod.json`
with `source: "manual_qa"`), and **close** UI items you verified with the screenshot as evidence.
Bump `updated_at`. See `commands/team.md` § Multi-source fan-in.
