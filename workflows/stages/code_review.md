# Stage reference: Code Review

> Loaded on demand by the `/team` interpreter for the `code_review` stage.
> Governance (classification, interpreter loop, gates, DoD) lives in `commands/team.md`.
> This file holds only the prompt templates / criteria for running the stage.

---

**🚫 Delegate, don't DIY.** Your first action for this stage is the Task call(s). Do NOT read code / run git / grep yourself "to give the agent context" — the agent gathers its own context. Recon-before-delegate is how the orchestrator absorbs the task and the subagent never runs.

### PHASE 6: CODE REVIEW (Parallel — static review only)

**Sequencing note (v3.0):** This is a *static, code-level* review. It runs **code-reviewer**
(+ **security-tester** when `scope.has_security`, + **devops** when `scope.has_infra`) — and
**deliberately NOT `qa` or `manual-qa`**. Runtime verification is now a separate, *sequenced*
pipeline that runs on the FIXED code:

```
code_review → review_fixes → manual_qa (skip_if !has_ui) → qa_tests → summary
```

Reviewing statically here, then verifying at runtime after fixes, means manual-qa and the
automated tests exercise the code that actually ships — not a pre-fix snapshot.

**Goal**: Find code-level defects — correctness, quality, conventions, security.

**Actions**:

1. Launch **review agents IN PARALLEL** based on scope:

   ```
   Agent (code-reviewer):
   "Review the implementation for:
    - Correctness & edge-case handling
    - Code quality (simplicity, DRY, elegance)
    - Project conventions compliance
    - Maintainability
    Report issues with a confidence score (0-100). Only report confidence >= 80.
    Write findings to the review artifact (schema `review`)."

   Agent (security-tester): [only if scope.has_security]
   "Review for security vulnerabilities (OWASP Top 10), input validation,
    authn/authz, secret handling. Confidence >= 80 only."

   Agent (devops): [only if scope.has_infra]
   "Review Docker/K8s/CI-CD config, env vars, deployment impact."
   ```

2. Consolidate findings by severity (only confidence >= 80 is recorded):
   - **CRITICAL** (90-100): must fix
   - **HIGH** (80-89): should fix
   - **MEDIUM** (70-79): consider

3. **Emit the normalized verdict** — write `.work-state/artifacts/review.json` (schema `review`).
   The verdict is **derived mechanically from findings, never eyeballed**:

   | condition | verdict |
   |-----------|---------|
   | any unresolved **CRITICAL** finding | `reject` |
   | else any **HIGH** or **MEDIUM** finding | `needs_changes` |
   | no findings | `approve` |

   The stage gate is `verdict != reject`. A missing/unknown verdict is treated as `reject` and
   never auto-approves.

   Each finding carries a `zone` (project scope name) so `review_fixes` can route it to the
   right developer role.

4. Present to user with **numbered findings** (the picker in `review_fixes` references these
   numbers):
   ```
   Code Review — verdict: NEEDS_CHANGES

   CRITICAL (must fix):
   1. [Issue] — [file:line] — conf 95% — zone: backend-kotlin

   HIGH (should fix):
   2. [Issue] — [file:line] — conf 85% — zone: frontend

   MEDIUM (consider):
   3. [Issue] — [file:line] — conf 72% — zone: backend-kotlin
   ```

**Checkpoint** (`fix_decision`): ✋ WAIT for user decision.
Autonomous: fix CRITICAL+HIGH, defer the rest, then re-derive the verdict.

---
