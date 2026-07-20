---
description: Closed-loop profile evolution - roll up profile-usage.jsonl into profile-stats.md and propose new named workflow profiles for recurring shapes
argument-hint: (no args; reads coordinator/<slug>/profile-usage.jsonl)
---

# Coordinator Stats — Profile Evolution

Rolls up the append-only **`profile-usage.jsonl`** telemetry (written by the `profile-usage`
PostToolUse hook on every agent launch) into a human-readable **`profile-stats.md`**, and proposes
new named workflow profiles when a recurring type×complexity shape shows up often enough to deserve
its own tuned profile.

## What it does

1. Reads `.work-state/coordinator/<project-slug>/profile-usage.jsonl` (one JSON line per launch:
   `{ts, workflow, type, complexity, stage, branch}`).
2. Aggregates:
   - activations per `workflow`,
   - `type × complexity` frequency,
   - stage reach (which stages actually run vs. get skipped),
   - recent trend (last N vs. prior).
3. Writes/updates `profile-stats.md` with the rollup.
4. **Proposes** (does not auto-create) new profiles for recurring shapes the current profiles serve
   awkwardly — e.g. "you run FEATURE/MEDIUM with `has_infra` 12× and always add devops; consider a
   `standard-infra` profile" — with a concrete stage sketch for each proposal.

## When to use

- Periodically (e.g. per milestone) to see how the team's workflows are actually being used.
- When a certain kind of task keeps needing manual roster overrides — the stats will show it.

## Notes

- Read-heavy; its only writes are `profile-stats.md` (and it never edits the shipped
  `workflows/*.json`). Adopting a proposal is a deliberate, separate step.
- Empty/missing `profile-usage.jsonl` → report "no telemetry yet" and stop.
