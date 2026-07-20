---
name: coordinator-yolo
description: Start and tick an autonomous yolo loop - pick task, run /team, verify, atomic-commit on a yolo branch, roll back on red. Triggers on "/team-yolo", "yolo mode", "run autonomously", "start the yolo loop", "just do the backlog". Explicit opt-in only; high blast radius.
---

# Coordinator — Yolo (start + tick)

Drive the project forward unattended, on a throwaway branch, with atomic commits and rollback on
red. **Explicit opt-in only** — this changes code and commits without per-step approval.

## Start

1. Confirm the iteration cap (default 5) and optional focus.
2. Launch the `coordinator-yolo` agent (`subagent_type: coordinator-yolo`).
3. It creates/switches to `yolo/<slug>-<date>` (never main/production).

## Tick (per iteration)

**pick task → `/team` (autonomous) → verify build+tests+DoD → atomic commit.**
On red: fix once, else `git reset --hard`/`revert` to the last green. Log each iteration to
`.work-state/coordinator/<slug>/yolo-log.md`.

## Rails (hard)

- Dedicated `yolo/*` branch only; branch-guard hooks block main/production commits+push.
- Atomic commits are rollback checkpoints — never leave the branch broken.
- DoD still applies (autonomous skips checkpoints, not QA); the Stop DoD gate still guards.
- Never push / merge / `gh pr merge`. A draft PR at the end is fine.

## Stop

Escalate + halt on needs-human tasks, repeated red, ambiguity, or the cap. To stop early, use the
`coordinator-yolo-stop` skill.

See also: `commands/team-yolo.md`, `agents/coordinator-yolo.md`.
