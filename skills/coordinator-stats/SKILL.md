---
name: coordinator-stats
description: Roll up profile-usage telemetry into profile-stats.md and propose new named workflow profiles for recurring task shapes. Triggers on "/coordinator-stats", "profile stats", "which workflows do we use", "propose a new profile", "workflow usage report".
---

# Coordinator — Profile Stats & Evolution

Close the loop between how workflows are *actually* used and which profiles exist.

## Procedure

1. Read `.work-state/coordinator/<project-slug>/profile-usage.jsonl` (append-only, written by the
   `profile-usage` PostToolUse hook). Each line: `{ts, workflow, type, complexity, stage, branch}`.
   Empty/missing → report "no telemetry yet" and stop.
2. Aggregate:
   - activations per `workflow`,
   - `type × complexity` frequency,
   - stage reach (which stages run vs. are skipped),
   - recent trend (last N vs. prior).
3. Write/update `profile-stats.md` with the rollup (tables, dated).
4. **Propose** (never auto-create) new named profiles for recurring shapes the current profiles
   serve awkwardly — include a concrete stage sketch and the evidence (counts) for each proposal.

## Guardrails

- Only writes `profile-stats.md`. Never edits the shipped `workflows/*.json`.
- Adopting a proposal is a deliberate, separate step by the user.

See also: `commands/coordinator-stats.md`, `hooks/profile-usage.sh`.
