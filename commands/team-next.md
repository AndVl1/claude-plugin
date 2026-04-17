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
3. **For BUG_FIX with a stacktrace or clear error in body** — mark BUG_FIX-ready.
   For BUG_FIX **without** repro steps or stacktrace → mark `needs-human` (reason:
   "no reproduction info"). Do NOT invoke `manual-qa` here — it may require credentials,
   env setup, or screenshots to disambiguate; leave for the explicit analyze step.

Decide per task:

| Condition | Action |
|-----------|--------|
| Confidence HIGH, scope clear, no open questions | `ready: true`, write `vibe-report/issue-<id>-context.md` with classification + scope + acceptance criteria inferred from body |
| Destructive / schema migration / security-sensitive | `needs-human`, reason in context file |
| Confidence LOW or ambiguous requirements | `needs-human`, reason = list of concrete questions (for human to address later) |
| BUG_FIX without repro | `needs-human`, reason = "no repro; run /queue-analyze or update issue" |

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
- skip all user checkpoints
- auto-approve architect design (pick first option)
- stop and mark task `needs-human` if classification confidence is LOW
- create a **draft PR** at the end instead of waiting for review

If `/team` returns with a `needs-human` signal (ambiguous requirements, destructive change,
LOW confidence), go to step 5b instead of 5a.

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

**Report publishing.** For visual tasks (and any report >500 words), publish via the
`publish-gist-report` skill — it uploads markdown + PNGs as paired secret gists and
returns a single URL. Link that URL from the PR body (skill handles GitHub's gist
rendering limits via the two-gist pattern). For small non-visual reports, the local
file path is sufficient.

### 5. Close

**5a. Success path:**
- Push branch: `git push -u origin feat/issue-<id>-<slug>`
- If visual task → invoke `publish-gist-report` skill, capture the gist URL
- Open draft PR linking the issue:
  - Non-visual: `gh pr create --draft --body "Closes #<id>. Report: <path>"`
  - Visual: `gh pr create --draft --body "Closes #<id>. Report (with screenshots): <gist-url>"`
- Update queue.json: `status: "done"`, `pr_url: <url>`, `report_path: <path>`, `report_gist_url: <url>` (if applicable)
- On the issue: `gh issue edit <id> --remove-label in-progress --add-label awaiting-review`
- Comment with PR link (and gist link for visual tasks).

**5b. Needs-human path:**
- Do NOT push, do NOT open PR. Leave the branch local.
- Update queue.json: `status: "needs-human"`, `report_path: <path>` (report explains why).
- On the issue: `gh issue edit <id> --remove-label in-progress --add-label needs-human`
- Comment with reason and report reference.

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
