---
name: coordinator-yolo
description: Autonomous night mode — user is away. Each /loop tick runs coordinator-yolo for ONE task through the regular /team, inside an isolated yolo branch. Never main, never push. Triggers on "/team-yolo", "yolo mode", "run autonomously overnight". Explicit opt-in; stop with coordinator-yolo-stop.
user_invocable: true
---

# coordinator-yolo

**Autonomous night mode.** The user is away — the coordinator moves the project forward toward the
long-term vision, but in a sandbox: one task per tick via the regular `/team`, all changes only in a
yolo branch off main, no questions.

**Not a whole-feature swallow.** The coordinator is an overseer, not the doer. Per tick it takes
**one** task and runs the normal `/team` on it. Cadence is the `/loop` interval.

## Argument

`$ARGUMENTS` — pulse interval (`10m`, `15m`, `30m`). Empty → `10m`.

## Steps

1. Read the methodology in `agents/coordinator-yolo.md`.
2. **Preconditions** (else do NOT start): `coordinator/<slug>/vision.md` exists (else `/pulse` /
   vision-bootstrap first); `git status --short` clean; build + test known.
3. **Cut the branch off main:**
   ```bash
   SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
   TS=$(date +%Y%m%d-%H%M)
   git checkout main && git checkout -b "yolo/$SLUG-$TS"
   ```
4. **Run the interval loop** — each tick = one task via `coordinator-yolo`, which runs the regular
   `/team`:
   ```
   /loop <interval> Task(subagent_type: "coordinator-yolo",
     prompt: "one autonomous yolo tick in yolo/<slug>-<ts>: pick the single highest-leverage
              task from vision/backlog, run the regular /team on it (autonomous), validate
              build+tests, commit to the yolo branch or roll back")
   ```
5. Tell the user: started, branch name, interval, how to stop (`/coordinator-yolo-stop`).

## Rails (hard)

- yolo branch off main only. Never: main, merge, push, force, prod-deploy, destructive git.
- One task per tick; each validated (build+test) before an atomic commit; red → rollback + log.
- No `AskUserQuestion` — decisions autonomous, logged with "why".
- Respect `vision.md` anti-scope. DoD still applies (each task runs the normal `/team`).

## Stop

`/coordinator-yolo-stop` — halts the loop and produces the report.
