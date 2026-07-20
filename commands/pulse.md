---
description: Read-only project pulse - coordinator scans work-state, queue, git, and coordinator memory, then presents a health digest and a next-action menu
argument-hint: (no args; reads .work-state/ and coordinator memory)
---

# Pulse — Read-only Project Coordinator

Launch the **`coordinator`** agent (read-only) to take the project's pulse: where things stand,
what's blocked, what's drifting from the vision, and what to do next.

## What it does

1. Delegates to the `coordinator` agent via the Task tool (`subagent_type: coordinator`).
2. The coordinator (read-only — it never mutates code/config/state/git) gathers:
   - git status + current branch,
   - active `/team` state (classification, stage cursor, open DoD items),
   - `.work-state/queue.json` (pending / needs-human),
   - coordinator memory in `.work-state/coordinator/<project-slug>/`
     (`vision.md`, `backlog.md`, `decisions.md`, tail of `pulse-log.md`).
3. Presents a compact **PULSE** digest + a numbered **next-action menu** (each item a concrete
   `/team …`, `/team-next`, `/queue-analyze`, or a manual step — mutating ones flagged).
4. Appends one dated entry to `pulse-log.md` (its only write) so pulses survive compaction.

## When to use

- Start of a session, to reorient.
- After a batch of work, to see what's left and what drifted.
- Before deciding whether to launch `/team-yolo`.

## Notes

- Pure situational awareness. To *act*, pick a menu item — `/pulse` itself changes nothing.
- If `vision.md` is missing, the coordinator will note it and suggest running the
  `vision-bootstrap` skill first.
