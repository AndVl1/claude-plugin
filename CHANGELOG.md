# Changelog

## 2.1.1

- **Delegate-don't-DIY discipline** (HARD RULE 3 + a banner in each delegated stage file): for
  `single`/`consilium` stages the Task call is the orchestrator's FIRST action — no reading
  code / git / grep "to give the agent context" (that recon is the agent's job). Fixes the slip
  (seen on a real 2.1.0 run) where the orchestrator said "I'll launch the diagnostics agent"
  then investigated inline and the subagent never ran. Not hook-enforceable — a Bash-guard
  can't tell the orchestrator's Bash from the delegated subagent's own Bash — so it's prompt
  discipline.

## 2.1.0 — Slim interpreter + on-demand stage files (P9)

Addresses two observed problems: the `/team` command file was ~45KB (loaded on every
invocation), and with everything in one prose-heavy file the model tended to **bypass the
workflow** — doing the task inline (git diff / Read / Bash) without classifying, picking a
profile, or writing `team-state.json`, leaving the determinism/DoD gates dormant.

### Changed
- **`commands/team.md` halved** (~45KB → ~26KB). Per-stage prompt templates and review
  criteria moved to `workflows/stages/<id>.md`, **read on demand** by the interpreter. team.md
  now holds only governance (classification, interpreter loop, gates, DoD, state schema).
- **Imperative interpreter**: a blunt "STOP — before ANY tool call, classify and write
  `team-state.json`" up top + HARD RULE 1; consilium parallelism is now a HARD RULE ("launch
  ALL roles in ONE message; announce the roster; never sequential/collapsed"). Alternative-
  workflow prose removed (profiles already encode those).

### Added
- **`workflows/stages/*.md`** — 10 on-demand stage references (discovery, exploration, clarify,
  architecture, diagnose, implementation, verify, review, review_fixes, summary). A test asserts
  every profile stage id has a matching file.
- **`hooks/team-nudge.sh`** (UserPromptSubmit) — on `/team` invocation, injects a reminder to
  run Step A (classify + write `team-state.json` + load profile) before any other tool, and to
  fan out consilium stages in parallel. Skips `/team-next`.
- **Dormant-gates nudge** in `hooks/validate-state.sh` — when agents launch with a
  `team-state.md` but no `team-state.json`, warns that the P4/P5/P8 gates are inactive.
- Tests now 82 assertions; CI watches `hooks/team-nudge.sh`.

## 2.0.1

- Removed the `/solo` command — unused; its role is covered by `/team` (QUICK tasks
  auto-classify to the `lightweight` profile) and `/interview` for clarification.
- Actualized README for 2.0.0 (14 agents, corrected agent table, custom-agent support, DoD /
  classification gates, `jq` requirement).

## 2.0.0 — Deterministic workflows + Definition of Done

Make `/team` execution deterministic by turning the workflow from prose into data.

### Breaking

The `/team` execution model changed and new hooks can **block** flows that previously just
finished — hence the major bump. Specifically:
- A PreToolUse(Task) gate (`hooks/validate-state.sh`) blocks agent launches when
  `team-state.json` lacks a classification or its `workflow` mismatches `type×complexity`.
- A Stop gate (`hooks/dod-gate.sh`) blocks a done-claim when the Definition of Done is unmet.

Both degrade gracefully (no `jq`, or legacy markdown-only state → no enforcement), and have
escape hatches (`workflow_override`, `pause.kind`, `.work-state/.dod-override`). The plugin's
agents/skills surface is unchanged; the 7-phase prose is retained as STAGE REFERENCE and the
`/team-next` return contract is unchanged.

### Added
- **Declarative workflow profiles** (`workflows/*.json`, P1) — 8 profiles (full-feature,
  standard, lightweight, bug-fix, debug-cycle, research, review, emergency) with a stage
  taxonomy (`orchestrator | single | consilium | bash | none`, harnest-style). `_schema.json`
  documents the format; `workflows/README.md` has the resolution table and interpreter contract.
- **Typed handoff artifacts** (`workflows/artifacts-schema.json`, P2) — stages exchange data
  via `.work-state/artifacts/<id>.json` instead of pasted prose; survives compaction, makes
  the inter-stage contract explicit.
- **Machine state** `.work-state/team-state.json` (P4) — classification, stage cursor, and
  monotonic stage status. `team-state.md` remains the human-readable mirror.
- **Per-project config** `.claude/team.config.json` (P6) — role→agent, role→model, and file
  glob→scope mapping resolved deterministically. Schema + example in `workflows/`.
- **State validation hook** `hooks/validate-state.sh` (P4/P5) — PreToolUse(Task) gate that
  blocks agent launches when the classification is missing, the workflow does not match
  `type×complexity`, or stage progress is non-monotonic. Degrades gracefully without `jq`;
  honors `"workflow_override": true`.
- **Definition of Done gate** (P8) — acceptance criteria fixed *before* code, each with a
  verification method and (on close) proof. New `dod` artifact (`workflows/artifacts-schema.json`)
  produced early by exploration/discovery/diagnose; `gate: dod_complete` on summary stages;
  `gate: root_cause_documented` before implementation in bug-fix/debug-cycle. Backstop
  `hooks/dod-gate.sh` (Stop) blocks a done-claim with unmet/evidence-less DoD — but only at the
  finish line, never mid-work, and always allows intentional pauses via `team-state.json`
  `pause.kind` (`background_wait | user_checkpoint | needs_human | failed`). `research`/`review`/
  `emergency` workflows and stale state (branch mismatch) are exempt; `.work-state/.dod-override`
  is the escape hatch. A soft PreToolUse(Edit) reminder nudges BUG_FIX to document the root cause
  before editing code. `team-state.json` gains `branch` and `pause`. Skill triggers (publish-gist,
  etc.) are documented as a standing reminder (not hard-enforceable from a hook). This supersedes
  project-level `team-dod.md` + `dod-guard.sh` (which grepped markdown and could drift).
- Hook + profile test coverage in `tests/test-hooks.sh` (now 74 assertions); CI watches
  `workflows/**`, `hooks/validate-state.sh`, and `hooks/dod-gate.sh`.

- **Custom agents in workflows** — roles resolve to any registered agent (project
  `.claude/agents/`, user `~/.claude/agents/`, or another plugin via `<plugin>:<agent>`), passed
  verbatim as Task `subagent_type`. New `roster_overrides` in `team.config.json` adds/removes/
  replaces a stage's agents without forking `workflows/*.json` (applied after `conditional[]`).
  Resolution order documented: `role → config.roles[role] → built-in default`.

### Changed
- `commands/team.md` — added the authoritative **WORKFLOW INTERPRETER** section (classify &
  gate → resolve config → walk stages). The 7-phase prose is retained as **STAGE REFERENCE**
  (prompt templates / criteria per stage type). Backward-compatible; the `/team` return
  contract consumed by `/team-next` is unchanged.

### Notes
- Scope auto-detection has built-in defaults; a dedicated `/team-scope` command to generate a
  project-specific `scope_map` is planned (P3).
