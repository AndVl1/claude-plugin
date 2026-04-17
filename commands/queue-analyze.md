---
description: Interactive batch clarification - resolve needs-human tasks in queue by asking all questions at once
argument-hint: [--only #id,#id] [--skip-repro]
---

# Queue Analyze — Interactive Clarification

Complements the auto `quick analysis` that runs inside `/team-next`. Use this **before**
starting `/loop /team-next` to clear out `needs-human` tasks so the autonomous run has
as much `ready` work as possible.

**This command asks the user questions.** Do not call it from `/loop` or `/team-next`.

---

## Preconditions

1. `.work-state/queue.json` exists (run `/queue-sync` first if not).
2. `gh` authenticated.

---

## Arguments

- `--only <#id,#id>` — only analyze these issue IDs (otherwise all `needs-human` tasks).
- `--skip-repro` — don't attempt bug reproduction via `manual-qa`; just ask questions.

---

## Steps

### 1. Collect candidates

Read `.work-state/queue.json`. Select tasks where:
- `status == "needs-human"`, OR
- `status == "pending"` and no `ready` flag (weren't touched by quick analysis yet)

If `--only` provided, filter by those IDs.

If set is empty → print "nothing to analyze" and exit.

### 2. Attempt reproduction (BUG_FIX tasks only, unless `--skip-repro`)

For each BUG_FIX in the set, launch `manual-qa` agent **in parallel** (one Agent call,
all tasks batched):

```
For issue #<id>: <title>
Body: <body>
Try to reproduce on dev environment. Report:
- reproduced: yes/no
- steps used
- observed vs expected
- logs/screenshots relevant to root cause
```

Write each result to `vibe-report/issue-<id>-reproduce.md`.

If `manual-qa` reproduces the bug cleanly → the task may become `ready` without asking
the user anything (mark `ready: true` in step 5).

If reproduction fails → the task stays in candidates, and step 3 will include a question
like "couldn't reproduce with steps X — what am I missing?".

### 3. Build question batch

For each remaining candidate, generate at most **3 concrete questions** based on its
`needs-human` reason + body analysis. Examples:

- Missing acceptance criteria → "How do we know #42 is done? [options: tests pass / manual check / metric X / Other]"
- Scope ambiguity → "#51 — does this touch mobile too? [yes / no / Other]"
- Failed repro → "#17 reproduce failed on steps X. What's different in your env? [Other text]"
- Destructive action clarification → "#89 requires dropping column Y. Confirm with backup plan? [confirmed / let's migrate instead / needs-human forever]"

**Skip** questions that are already answered in the issue body. Don't re-ask the obvious.

Flatten all questions across all issues into a single list, each tagged with its issue ID.

### 4. Ask the human (single batch)

Use `AskUserQuestion` with the whole batch at once — grouped visually by issue:

```
[#42] Acceptance criteria?      → [tests / manual / metric / Other]
[#42] Breaking API change OK?   → [yes / no / Other]
[#51] Scope includes mobile?    → [yes / no / Other]
[#17] Repro env details?        → [Other text]
```

One round, one interaction. If the user aborts / doesn't answer → leave tasks as they
are (no status change) and exit.

### 5. Apply answers

For each task:
- Write/update `vibe-report/issue-<id>-context.md` with the answers + any repro output.
- If all questions answered AND no destructive/security blocker remains → `ready: true`,
  `status: "pending"` (so `/team-next` picks it up).
- If user chose "needs-human forever" or skipped → leave as `needs-human`.
- If a destructive/security blocker remains → keep `needs-human` with updated reason.

Commit queue + context files: `chore(queue): human-analysis <date>`.

### 6. Summary

Print a compact table:

```
Analyzed: 7 tasks
  → ready:        5  (#42, #51, #63, #64, #72)
  → needs-human:  2  (#17 — repro still unclear, #89 — awaiting DBA signoff)

Ready to run: /loop /team-next
```

---

## Guardrails

- Maximum 3 questions per issue. If a task genuinely needs more → mark it
  `needs-human` with reason "too complex for batch analyze, use /team interactively".
- Never auto-resolve destructive/security tasks without an explicit "confirmed" answer.
- Do not modify tasks outside the analyzed set.
- Do not call `/team` or `/team-next` from here.

---

Start analysis now.
