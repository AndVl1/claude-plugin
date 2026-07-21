---
name: coordinator
description: Read-only project pulse. Scan work-state, queue, git, and coordinator memory to present a health digest + next-action menu. Triggers on "/pulse", "project pulse", "where are we", "status of the project", "what's next", "take the pulse". Never mutates the repo.
---

# Coordinator — Pulse (read-only)

Take the project's pulse without changing anything. The coordinator is an **overseer above
`/team`**: it observes, catches drift, and **proposes what `/team` to run next** — it never
executes and is never the agent `/team` hands work to.

## Procedure

1. Launch the `coordinator` agent (`subagent_type: coordinator`) — it is read-only.
2. It gathers git status, active `/team` state (classification, stage cursor, open DoD items),
   `.work-state/queue.json`, and coordinator memory in
   `.work-state/coordinator/<project-slug>/` (`vision.md`, `backlog.md`, `decisions.md`,
   tail of `pulse-log.md`).
3. It presents a compact **PULSE** digest and a numbered **next-action menu** (each item a
   concrete `/team …`, `/team-next`, `/queue-analyze`, or manual step; mutating ones flagged).
4. It appends one dated entry to `pulse-log.md` — its only write.

## Guardrails

- Situational awareness only. `/pulse` never edits code/config/state/git.
- Missing `vision.md` → suggest the `vision-bootstrap` skill.
- To act on the pulse, pick a menu item; the pulse itself is inert.

See also: `commands/pulse.md`, `agents/coordinator.md`.
