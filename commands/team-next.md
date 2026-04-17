---
description: Execute one autonomous iteration - pick next pending task from queue, run /team, close it
argument-hint: (no args; reads .work-state/queue.json)
---

# Team Next — Single Autonomous Iteration

Runs exactly **one** task from the queue end-to-end, then exits. Designed to be wrapped
by `/loop` for continuous autonomous execution.

**Do not use interactively for ad-hoc work** — that's what `/team` is for.

---

## Preconditions

1. `gh` authenticated (`gh auth status`). If not → abort with clear error, do not schedule next wakeup.
2. Working tree clean OR only `.work-state/` changes (abort if uncommitted code present —
   autonomous runs must start from a clean base).

---

## Steps

### 0. Sync + quick analysis (auto, non-interactive)

**0a. Sync.** Invoke `/queue-sync` via the Skill tool, using meta (`repo`, `label`) from
`.work-state/queue.json` or defaults. Refreshes cache, does not touch in-progress/done.
If sync fails (network/auth) — proceed with existing cache; only abort if cache missing.

**0b. Quick analysis.** For every task with `status=pending` and no `ready` flag yet:

Run a **lightweight, non-interactive** classification (do NOT ask the user anything here —
this must be safe to run inside `/loop`):

1. **Phase 0 classify** on issue title+body: type (FEATURE/BUG_FIX/...), complexity, confidence.
2. **Lite code scan** — grep the repo for keywords from title/body; identify likely-touched
   files/modules. Use Explore agent if scope is broad.
3. **For BUG_FIX** — always mark `ready: true` unless destructive/security. Missing
   repro steps or stacktrace is **not** a blocker: the bug itself IS the task, and
   `/team` Phase 2 (`diagnostics`) + Phase 2.5 (diagnostics ↔ `manual-qa` debug loop)
   are designed exactly for forming a hypothesis when repro is unknown. The autonomous
   loop must take such bugs into work, not punt them to the human.

Decide per task:

| Condition | Action |
|-----------|--------|
| Confidence HIGH, scope clear | `ready: true`, write `vibe-report/issue-<id>-context.md` with classification + scope + acceptance criteria inferred from body |
| BUG_FIX (with or without repro) | `ready: true` — `/team` will run diagnostics + manual-qa to form hypothesis |
| Destructive / schema migration / security-sensitive | `needs-human`, reason in context file |
| Confidence LOW **and not a BUG_FIX** (unclear feature requirements) | `needs-human`, reason = list of concrete questions |

Write results back to `queue.json`. Commit the queue + context files as a single
`chore(queue): auto-analysis <date>` commit, so the audit trail survives.

**Key invariant**: step 0 never asks the user and never runs interactive tools. Anything
that requires human input lands in `needs-human` for an explicit `/queue-analyze` later.

### 1. Pick

Read `.work-state/queue.json`. Find the **first** task matching:
- `status == "pending"`
- `ready == true` (analysis complete — no blocking questions)
- no label in `["blocked", "needs-human", "wip"]`
- not marked `stale: true`

If none found → print a terminal summary and **exit without scheduling next wakeup**:

```
queue empty: 0 ready tasks.
  Pending (not analyzed): N  → run /queue-analyze
  Needs-human:             M  → see vibe-report/ for reasons
  Done this run:           K
```

This is the termination condition for `/loop`. Do NOT call `/queue-analyze` automatically —
it requires human interaction; the loop is expected to halt gracefully when ready tasks run out.

### 2. Lock

Immediately, before doing any work:

1. Update the task in `.work-state/queue.json`: `status: "in-progress"`, `started_at: <now>`.
2. In GitHub: `gh issue edit <id> --add-label in-progress`
3. Post a comment: `gh issue comment <id> --body "Autonomous run started (team-next)"`
4. Create a feature branch: `git checkout -b feat/issue-<id>-<slug>` (slug from title).

Commit the queue.json lock change **before** starting real work, so a crash mid-task leaves a visible trail.

### 3. Delegate to /team

Invoke `/team` via the Skill tool with the autonomous prefix:

```
[AUTONOMOUS issue=#<id> url=<url>]

<issue title>

<issue body>
```

The `[AUTONOMOUS ...]` prefix tells `/team` Phase 0 to:
- skip **user-input** checkpoints (questions, approvals) — but NOT verification phases
- auto-approve architect design (pick first option)
- stop and mark task `needs-human` if classification confidence is LOW **for a FEATURE**
  (for BUG_FIX, LOW confidence means "run diagnostics + manual-qa to investigate", not punt)
- run **Phase 2.5 (diagnostics ↔ manual-qa debug loop) MANDATORILY** for every BUG_FIX,
  even if not tagged as "needs verification" — this is how hypothesis is formed
- run **Phase 6 verification MANDATORILY** — `manual-qa` post-fix check for BUG_FIX,
  tests + lint for every task. Autonomous mode means "no human in loop", it does NOT
  mean "skip QA". Never open a PR without verification evidence.
- create a **draft PR** at the end instead of waiting for review

**Expected return from `/team`** (structured):
- `status`: `success` | `needs-human` | `failed`
- `branch`: feature branch name
- `files_touched`: list
- `verification`: `{ tests_passed: bool, manual_qa_log: <path>, screenshots: [<paths>] }`
- `summary`: what was done, what agents ran
- `needs_human_reason` (if applicable)

### 3.5. Gate before close

Before proceeding to step 4, validate `/team`'s return:

| Check | Failure action |
|-------|---------------|
| Branch has ≥1 commit (real code change) | Abort step 5a → 5b with reason "no code changes" |
| For BUG_FIX: `manual_qa_log` exists and documents reproduction attempt | Abort → 5b "no manual-qa verification" |
| For BUG_FIX (fixed): `manual_qa_log` confirms post-fix verification | Abort → 5b "fix not verified" |
| `tests_passed == true` or explicit "no tests applicable" rationale | Abort → 5b "tests failed or skipped without rationale" |
| Visual task: screenshots present | Abort → 5b "visual change without screenshots" |

This gate catches the common failure where `/team` exits early (e.g., treats verification
as a "user checkpoint" and skips it). `/team-next` is responsible for the output
contract; don't trust `/team` to self-regulate.

If `/team` returns with a `needs-human` signal (ambiguous feature requirements, destructive
change, security-sensitive), go to step 5b instead of 5a.

### 4. Write report

`vibe-report/issue-<id>-<YYYY-MM-DD>.md` with:
- task title + link
- branch name, PR URL
- summary of what `/team` did (files touched, agents run)
- any warnings/skipped steps

**Visual tasks — screenshots are MANDATORY.**

A task is "visual" if it changes any of:
- UI components (Compose, React, HTML/CSS)
- layout, styling, theming, copy shown to users
- user-visible flows (navigation, forms, error states)
- anything labelled `ui`, `frontend`, `mobile`, `design`

For visual tasks, the report MUST include:
- **Before** screenshot (from `manual-qa` reproduction OR current `main`)
- **After** screenshot (post-fix, captured via `manual-qa` on the feature branch)
- Both golden path AND any affected edge cases (empty, error, loading)

Capture screenshots by invoking `manual-qa` agent against the running app (Chrome for
Mini App / web, Android/iOS simulator for mobile). Save PNGs alongside the markdown in
`vibe-report/issue-<id>-screenshots/`.

If screenshots cannot be captured (no dev env available, credentials missing, headless
CI without browser) → **abort step 5a and go to 5b `needs-human`** with reason
"visual task, screenshots unavailable in autonomous env". Do NOT open a draft PR for a
visual change without visual proof.

**Report publishing is MANDATORY** for every completed task (both success and
needs-human paths). Invoke the `publish-gist-report` skill unconditionally — it
uploads markdown + any PNGs as paired secret gists (two-gist pattern for rendering)
and returns a single URL. The gist URL replaces the local path in PR body and issue
comments. If gist publishing fails (auth, network) → retry once, then fall back to
local path but mark queue.json with `report_publish_failed: true` so the human sees it.

### 5. Close

**5a. Success path:**
- Push branch: `git push -u origin feat/issue-<id>-<slug>`
- **Invoke `publish-gist-report` skill** to upload the report (and any screenshots) and get the gist URL
- Open draft PR linking the issue: `gh pr create --draft --body "Closes #<id>. Report: <gist-url>"`
- Update queue.json: `status: "done"`, `pr_url: <url>`, `report_path: <local-path>`, `report_gist_url: <url>`
- On the issue: `gh issue edit <id> --remove-label in-progress --add-label awaiting-review`
- Comment on the issue with PR link + gist URL.

**5b. Needs-human path:**
- Do NOT push, do NOT open PR. Leave the branch local (human can inspect).
- **Still invoke `publish-gist-report`** to upload the partial report — human needs to
  see what was tried, diagnostics output, manual-qa logs. The gist URL goes into the
  issue comment so the human can read it on GitHub without pulling the branch.
- Update queue.json: `status: "needs-human"`, `report_path: <local>`, `report_gist_url: <url>`.
- On the issue: `gh issue edit <id> --remove-label in-progress --add-label needs-human`
- Comment on the issue with the reason + gist URL.

### 6. Schedule next iteration (only if inside /loop dynamic mode)

If there are still `pending` tasks in the queue → call `ScheduleWakeup` with:
- `delaySeconds: 60` (stay cache-warm, next task starts quickly)
- `prompt: "/team-next"`
- `reason: "queue has N pending tasks; continuing autonomous run"`

If queue is empty after this iteration → do NOT call `ScheduleWakeup` (loop stops).

---

## Failure handling

If step 3 (`/team`) errors out hard:
- queue.json: `status: "failed"`, `error: <message>`
- GitHub: remove `in-progress`, add `autonomous-failed`, comment with error + report link.
- Do NOT schedule next wakeup (stop the loop, let user investigate).

Never leave a task `in-progress` on exit. Any exit path must set a terminal status.

---

## Guardrails

- One task per invocation. Never process multiple in a single `/team-next` run.
- Never force-push. Never delete branches. Never close issues directly — only PR-merge closes them.
- Never modify the queue cache for tasks other than the current one.
- If working tree dirty at start → abort with clear error. Do not auto-stash.

---

Start now.
