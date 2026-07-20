---
name: vision-bootstrap
description: Derive the project's vision.md (north star) from existing context - README, CLAUDE.md, git history, coordinator memory, and a short interview. Triggers on "bootstrap vision", "create vision.md", "set the project vision", "no vision.md yet", "define the general line". Run once, then the coordinator keeps it.
---

# Vision Bootstrap

Produce `.work-state/coordinator/<project-slug>/vision.md` — the general line the coordinator and
yolo executor steer by. Run once when it's missing; afterwards it is maintained, not regenerated.

## Procedure

1. Gather context (read-only): project `README.md`, `CLAUDE.md`, recent `git log`, existing
   `.work-state/coordinator/<slug>/` memory (`backlog.md`, `decisions.md`, `pulse-log.md`).
2. Draft a vision from what the project already tells you — do not invent goals the evidence
   doesn't support.
3. Ask the user **2–4 targeted questions** only where the context is genuinely ambiguous (primary
   users, the one outcome that matters most, explicit non-goals, hard constraints).
4. Write `vision.md`:
   ```markdown
   # Vision — <project-slug>

   ## North star
   <one paragraph: what this project is for and who it serves>

   ## Principles
   - <the 3–6 non-negotiables that decide trade-offs>

   ## Non-goals
   - <what this project deliberately will NOT do>

   ## Constraints
   - <tech / time / compliance constraints that bound decisions>
   ```
5. Confirm with the user; refine once. Keep it short — a north star, not a spec.

## Guardrails

- Only writes `vision.md` under the coordinator memory dir. Touches nothing else.
- If a `vision.md` already exists, do not overwrite — offer to refine it instead.

See also: `agents/coordinator.md` (reads `vision.md` every pulse).
