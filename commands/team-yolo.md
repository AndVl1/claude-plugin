---
description: Start the autonomous night loop - each /loop tick runs coordinator-yolo for ONE task through the regular /team, on an isolated yolo branch, rollback on red. Never main, never push.
argument-hint: [pulse interval, e.g. 10m — default 10m]
---

# Team Yolo — Autonomous Night Loop (explicit opt-in)

Starts the coordinator's autonomous mode: an interval loop where **each tick handles exactly one
task by running the regular `/team` pipeline** (autonomous), on a throwaway branch, committing
atomically and rolling back on red.

> ⚠️ **High autonomy, sandboxed blast radius.** Runs code changes + commits without asking. Only
> start it when you mean it. It cannot push, merge, or touch main.

## Not a whole-feature swallow

The coordinator is an **overseer**, not the doer. It does **not** absorb a feature and implement it
inline. Per tick it picks **one** highest-leverage task from the vision/backlog and runs the normal
`/team` on that single task — the same deterministic classification → stages → DoD flow you'd
trigger by hand. Cadence is the `/loop` interval; one tick = one task.

## What it does

1. **Confirm opt-in** and the pulse interval (`$1`, default **10m**).
2. **Preconditions** (else do NOT start): `coordinator/<slug>/vision.md` exists (run `/pulse` /
   vision-bootstrap first if not); `git status --short` is clean; build + test commands are known.
3. **Cut the branch:**
   ```bash
   SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
   TS=$(date +%Y%m%d-%H%M)
   git checkout main && git checkout -b "yolo/$SLUG-$TS"
   ```
4. **Start the interval loop** — each tick delegates ONE task to the `coordinator-yolo` agent,
   which runs the regular `/team` for it, validates, and commits or rolls back:
   ```
   /loop <interval> Task(subagent_type: "coordinator-yolo",
     prompt: "one autonomous yolo tick in branch yolo/<slug>-<ts>: pick the single
              highest-leverage task from vision/backlog, run the regular /team on it
              (autonomous), validate build+tests, commit to the yolo branch or roll back")
   ```
5. **Tell the user**: mode started, branch name, interval, how to stop (`/coordinator-yolo-stop`).

## Rails (enforced)

- yolo `yolo/*` branch only; the branch-guard hooks block commits/push to main/production.
- One task per tick; atomic commits = rollback checkpoints; never leave a red tree.
- Each task runs the normal `/team` — DoD still applies (autonomous skips *checkpoints*, not *QA*).
- No `AskUserQuestion` (user is away); never pushes / merges / `gh pr merge`.

## Stopping

Run **`/coordinator-yolo-stop`** (or say "stop yolo") to halt the `/loop` and get the report.
