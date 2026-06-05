# Changelog

## 1.11.0 — Deterministic workflows

Make `/team` execution deterministic by turning the workflow from prose into data.

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
