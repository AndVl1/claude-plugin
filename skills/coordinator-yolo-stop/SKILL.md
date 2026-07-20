---
name: coordinator-yolo-stop
description: Halt a running autonomous yolo loop and produce a final report. Triggers on "stop yolo", "halt the loop", "/team-yolo stop", "end yolo", "abort autonomous run". Safe to invoke at any time.
---

# Coordinator — Yolo Stop (halt + report)

Cleanly halt the autonomous yolo executor and hand back to the human.

## Procedure

1. Signal the `coordinator-yolo` run to stop after its current iteration (do NOT interrupt
   mid-commit — let the in-flight atomic commit finish or roll back so the branch is never left
   broken).
2. Ensure the working tree is on a clean checkpoint: last green commit, or a completed rollback.
3. Write a final summary to `.work-state/coordinator/<slug>/yolo-log.md`:
   - tasks completed (with commit SHAs),
   - rollbacks (with reasons),
   - escalations / unfinished tasks,
   - the `yolo/<slug>-<date>` branch name.
4. Report the summary to the user and optionally open a **draft** PR for review. Merging is the
   user's.

## Guardrails

- Never force-stop in a way that leaves an uncommitted broken tree.
- This is a separate skill from `coordinator-yolo` (start/tick) on purpose — stopping must be a
  first-class, always-available action.

See also: `skills/coordinator-yolo/SKILL.md`, `agents/coordinator-yolo.md`.
