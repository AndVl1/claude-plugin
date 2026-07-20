---
description: Start an autonomous yolo loop - coordinator-yolo picks tasks, runs /team, verifies, atomic-commits on a yolo branch, rolls back on red
argument-hint: [max iterations, default 5] [optional focus]
---

# Team Yolo — Autonomous Loop (explicit opt-in)

Starts the **`coordinator-yolo`** executor: an unattended loop that drives the project forward
without per-step checkpoints — on a throwaway branch, committing atomically, rolling back on red.

> ⚠️ **High autonomy, real blast radius.** This runs code changes and commits without asking at
> each step. Only start it when you mean it. It still cannot push, merge, or touch main.

## What it does

1. Confirms opt-in and the iteration cap (`$1`, default **5**) and optional focus (`$2`).
2. Delegates to the `coordinator-yolo` agent (`subagent_type: coordinator-yolo`), which:
   - creates/switches to a `yolo/<slug>-<date>` branch (never main/production),
   - loops: **pick task → `/team` (autonomous) → verify (build+tests+DoD) → atomic commit**;
     on red, fix once then `git reset --hard`/`revert` to the last green,
   - logs each iteration to `.work-state/coordinator/<slug>/yolo-log.md`,
   - stops at the cap, an empty queue, or an escalation (needs-human / repeated red / ambiguity),
   - optionally opens a **draft** PR at the end. Merging stays with you.

## Safety rails (enforced)

- Dedicated `yolo/*` branch only; the branch-guard hooks block commits/push to main/production.
- Atomic commits = rollback checkpoints; the branch is never left broken.
- DoD still applies — autonomous skips *checkpoints*, not *QA*. The Stop DoD gate still guards.
- Never pushes / merges / `gh pr merge`.

## Stopping

Run the **coordinator-yolo-stop** skill (or say "stop yolo") to halt early. On halt the executor
writes a final `yolo-log.md` summary and hands back.
