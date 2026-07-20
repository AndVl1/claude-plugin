# Changelog

## 3.0.0 — Sequenced review pipeline, DoD fan-in, coordinator loop — **BREAKING**

One release covering the plugin overhaul: the review pipeline is resequenced (breaking), the
Definition of Done becomes multi-source, hook block-messaging is fixed, and a strategic
coordinator layer (pulse + autonomous yolo loop) is added on top of `/team`.

### Sequenced review pipeline (BREAKING)
Splits the single parallel `review` consilium (which mixed static review, `qa`, and `manual-qa`
at once, against pre-fix code) into an ordered pipeline so manual QA and automated tests exercise
the code that actually ships:

```
code_review → review_fixes → manual_qa (skip_if !has_runtime) → qa_tests → summary
```

- **`code_review`** — static only: `code-reviewer` (+ `security-tester` if `scope.has_security`,
  + `devops` if `scope.has_infra`). No `qa`/`manual-qa`. Produces `review`.
- **`manual_qa`** — single `manual-qa`, `skip_if !scope.has_runtime`, runs **after** `review_fixes`
  on the fixed code. **Not UI-only** — `scope.has_runtime` gates it (skipped only for pure
  docs/config) and `scope.has_ui` selects the *mode*: `ui` (drive agent-browser for web /
  claude-in-mobile for the app) else `runtime`
  (run the app, hit endpoints, read logs). New `manual_qa` artifact (`verdict` PASS/FAIL, `mode`,
  `evidence[]`, `dod_additions[]`, `regressions[]`). Gate `manual_qa.verdict != FAIL`.
- **`qa_tests`** — single `qa`, runs **after** `manual_qa`, encodes `manual_qa.evidence` into
  automated regression tests. New `qa_tests` artifact. Gate
  `manual_qa.verdict == PASS || !has_runtime`.
- **`feature_spec`** artifact (optional, 8 sections) — `full-feature` discovery may produce it;
  `manual-qa` consumes `acceptance_criteria`.
- Numbered-issue picker in `review_fixes` (`fix_selection`), default preselect CRITICAL+HIGH.
- Profiles rewired: `full-feature`, `standard` (+`has_infra` parity), `lightweight` (qa_tests, no
  manual_qa for QUICK), `bug-fix` (+manual_qa), `debug-cycle` (+qa_tests). `review`/`emergency`
  keep their `review` stage.
- Agents: `manual-qa` produces `manual_qa` (was a string in `debug`); `qa` owns `qa_tests`.

**Migration**: projects with custom `workflows/*.json` referencing a single `review` stage must
migrate. `review`/`emergency` unchanged. For feature/bug profiles, replace the `review` consilium
with `code_review` and add `manual_qa` + `qa_tests` before `summary`:
```sh
jq '(.stages[] | select(.id=="review")).id = "code_review"' profile.json
# then hand-add manual_qa (skip_if !scope.has_runtime) + qa_tests; drop qa/manual-qa from code_review.
```
Tooling reading `debug.manual_qa_log` should read the `manual_qa` artifact instead.

### Multi-source Definition of Done fan-in
- `dod` schema: items gain optional `id` (`<source>-<n>`) + `source`; the object gains a
  `contributions` audit map and `updated_at`.
- APPEND/CLOSE convention documented in `commands/team.md` (§ Multi-source fan-in) and in the
  contributing stage files + agents (architect, code-reviewer, qa, manual-qa, developers;
  analyst/tech-researcher via exploration). Sequential DoD writes — no races.

### Hook block-messaging + routing hardening
- **All blocking hook messages go to stderr** — `exit 2` feeds only stderr back to Claude; stdout
  on a block was silently dropped. Fixed in `dod-gate.sh`, `safety-guard.sh`, `validate-state.sh`,
  and the inline chrome/mobile guards.
- `dod-gate.sh`: branch mismatch → warn + **archive** stale state to `.work-state/archive/`
  (created first); `pause.kind` validated against a whitelist (warn, never block).
- `.manual-qa-active` marker **lazy-created** for the manual-qa agent (PreToolUse env probe on
  `CLAUDE_AGENT_TYPE`); non-manual-qa callers still blocked; `SubagentStop` cleans it up;
  `SessionStart` pre-creates `.work-state/archive/`.
- `has_ui` / `has_runtime` documented as interpreter built-ins (not config globs). `has_runtime`
  gates `manual_qa`; `has_ui` selects the mode (ui vs runtime) within it.

### Coordinator + autonomous yolo loop
- **Commands**: `/pulse` (read-only digest + next-action menu), `/team-yolo` (autonomous
  pick→`/team`→verify→atomic-commit loop, rollback on red), `/coordinator-stats` (profile-usage
  rollup + new-profile proposals).
- **Agents**: `coordinator` (opus, read-only, green) and `coordinator-yolo` (opus, autonomous,
  red — dedicated `yolo/*` branch, atomic commits, hard rails, never pushes/merges, DoD enforced).
- **Skills**: `coordinator`, `coordinator-yolo`, `coordinator-yolo-stop`, `coordinator-stats`,
  `vision-bootstrap`.
- **`hooks/profile-usage.sh`** (PostToolUse Task) — appends one JSONL activation line per launch
  to `coordinator/<slug>/profile-usage.jsonl`. Best-effort, never blocks.
- `agents/diagnostics.md` two-tier gate expanded: Tier 1 diagnostic auto-permitted, Tier 2
  mutation hard-stops on an explicit bilingual + semantic approval trigger (ambiguity ≠ approval).

### Housekeeping
- Named architect variants `architect_{minimal,clean,pragmatic}` → resolve to `architect` via the
  `roles` map (design choice C: 1 architect for MEDIUM/`standard`, 3 for COMPLEX/`full-feature`).
- Doc drift fixed: `team.md` 13→15 agents + gate example `confidence>=80` → `verdict != reject`;
  `README.md` 14→15 agents, `developer-go` row, full command list.
- `frontend-developer` drops the `kmp` skill; `discovery` description mentions Team-Config mode.
- Note: `team-state.json` has no migrator (session-ephemeral; gates degrade gracefully).

### Verification
- `tests/test-hooks.sh`: 129 → **181** assertions, all passing. Hooks `bash -n` clean, all
  workflow/plugin JSON valid, stage referential integrity intact.

## 2.4.1 — Work-state per-feature subdirs + coordinator/ memory + identity rename

Hoists the orchestrator's per-task state out of `.work-state/`'s root into per-feature
subdirs so parallel tasks (manual-qa on branch A while the implementer runs branch B)
don't trample each other's state and artifacts. Also fixes a three-identifier identity
drift on the Kotlin developer agent.

### Added
- **Per-feature work-state subdirs** (`.work-state/features/<slug>/{state.json,
  team-state.md, artifacts/}`). The orchestrator writes the current task's slug into
  `.work-state/.active-feature` at Step A; the gate hooks resolve state from there,
  falling back to the legacy `.work-state/team-state.json` for projects on the older
  single-state layout. Two layouts, same gates — existing v2.4.x projects keep working
  unchanged. See `commands/team.md` § Work-state directory layout for the full map.
- **`hooks/resolve-state-path.sh`** — single source of truth for the active state file
  path. `dod-gate.sh` and `validate-state.sh` both call it (instead of hard-coding
  `.work-state/team-state.json`) so any future layout change is one edit, not two. Test
  override: `WORK_STATE_DIR` env var.
- **`coordinator/` memory directory convention** at `.work-state/coordinator/<project-slug>/`
  for vision / backlog / decisions / pulse-log / yolo-log / profile-usage.jsonl /
  profile-stats.md — the home of the future read-only coordinator and autonomous yolo
  executor (PR-4 in the audit report). Project-slug = `basename "$(git rev-parse
  --show-toplevel)"`. Not implemented yet, just reserved.

### Changed
- **`developer-backend` → `developer-kotlin` identity** across 4 files (frontmatter,
  `workflows/team.config.example.json` × 2, `workflows/README.md`, `README.md`). The
  Kotlin file is canonical; the older `developer-backend` string was residue from
  before the Go split in 2.3.0 and the `backend-kotlin` scope rename. `/init-team` and
  the interpreter resolve by `subagent_type` string, so callers using the bare name in
  a project's `team.config.json` must rename `developer-backend` → `developer-kotlin`.
  No behavioural change: same agent, same skills, same model. Same goes for `team.md`
  (already used `developer-kotlin`).
- **`hooks/dod-gate.sh` / `hooks/validate-state.sh`** now derive STATE and DOD paths
  via the helper instead of hard-coding `.work-state/team-state.json` and
  `.work-state/artifacts/dod.json`. State and DOD stay co-located (under the same base
  dir) for both layouts.

### Tests
- `tests/test-hooks.sh`: 120 → 129 assertions (+9). New: resolve-state-path empty /
  legacy / active-feature match / active-feature missing-subdir-fallback / feature
  precedence / whitespace-only slug / WORK_STATE_DIR override + dod-gate end-to-end
  through per-feature layout (synthetic done-claim in a per-feature state.json without
  a DoD artifact → blocks, proving the helper is wired into the hook, not just
  isolated).

## 2.4.0 — Review verdicts + safety hooks + /init-team project config

Borrows three patterns from the xpowers/superpowers plugin (deterministic verdicts, fail-closed
guards, soft skill auto-activation) and fixes latent wiring bugs found while auditing this plugin
against it. See `vibe-report/xpowers-analysis-2026-06-20.md` for the comparison.

### Fixed
- **`review_fixes` referenced an undefined `${issue.zone.dev_agent}`** (full-feature + standard):
  the variable was never populated anywhere, so the stage would fail to resolve a developer on
  any CRITICAL/HIGH finding. Resolved to `${scope.dev_agent}` — the variable actually computed
  from the dominant file scope (same one `implementation` uses).
- **Go was not wired into scope routing**: `developer-go` shipped in 2.3.0 but `scope_map` had no
  `**/*.go` entry, so Go tasks misrouted to the Kotlin backend developer. Added a `go` scope
  (`**/*.go`, `go.mod`, `go.sum` → `developer-go`) + `roles.go` + README.
- **Go skills used lowercase `skill.md`** (vs `SKILL.md` everywhere else) — not discovered on
  case-sensitive filesystems (Linux/CI). Renamed all three (`go-patterns`, `go-concurrency`,
  `go-microservices`).
- SessionStart banner said "14 agents" → 15.

### Added
- **Normalized review verdict (P-1)**: the `review` artifact now requires a top-level `verdict`
  (`approve` | `needs_changes` | `reject`) derived **mechanically** from findings (reject = any
  CRITICAL; needs_changes = any HIGH/MEDIUM; approve = none). Every review-stage gate changed from
  the subjective `confidence>=80` to `verdict != reject`. A missing verdict never auto-approves.
- **`hooks/safety-guard.sh` (P-4)**: PreToolUse(Bash) fail-closed guard blocking catastrophic
  `rm -rf` of root/home/cwd-wide paths, `sudo`, recursive `chmod 777`, and history-rewriting
  `git push --force` (allows `--force-with-lease`). Narrowly scoped — `rm -rf build/` and
  `rm -rf node_modules` still pass.
- **`hooks/skill-suggest.sh` (P-5)**: soft UserPromptSubmit auto-activation. On a plain request
  it surfaces the matching workflow + domain skills, but only when it sees BOTH an intent verb
  AND a concrete stack keyword — silent on chit-chat and on `/team` (team-nudge owns that).
- **`/init-team` command (former P3)**: detects the project's stacks and generates
  `.claude/team.config.json`, mapping each scope to the best available agent — **including agents
  from other installed plugins** (e.g. `rust-agents` for a Rust repo). Fixes the misrouting where
  an unmapped stack (`**/*.rs` with no `scope_map` entry) left `${scope.dev_agent}` unresolved and
  the orchestrator grabbed the nearest dev agent. Interactive: detect → propose → confirm
  (`AskUserQuestion`) → write + JSON-validate + dry-run the scope_map. The previously-orphaned
  `discovery` agent gains a `Team-Config Discovery` mode as the engine (and learns that a
  cross-plugin agent's invoke name comes from its `plugin.json` `name`, not the directory).

### Changed
- **`backend` scope renamed to `backend-kotlin`** (disambiguates from `go`, now that both are
  JVM-adjacent). Updated in `team.config.example.json`, schema, and the README example. **Breaking
  for any project config that hard-codes `scope: "backend"`** — rename it to `backend-kotlin`.
- **`scope` / `zone` enums loosened to free strings** in `team.config.schema.json` and
  `artifacts-schema.json`. They previously hard-listed `[backend, frontend, mobile, devops]` —
  which (a) never included `go` and (b) would have rejected the custom scopes `/init-team`
  generates (`rust`, `python`, …). Scope names are now project-defined.
- **`scope_map` precedence documented as first-match-wins** (README + a `_scope_map_order` note in
  the example). `mobile` is ordered above `backend-kotlin` so a KMP `commonMain/*.kt` routes to
  mobile, not the JVM backend; `**/*.kt` reaches `backend-kotlin` only outside mobile source sets.

### Tests
- `tests/test-hooks.sh`: 88 → 120 assertions (safety-guard block/allow matrix, skill-suggest
  fire/silence, verdict-gate normalization, Go scope wiring, `/init-team` + discovery mode,
  backend-kotlin rename + mobile-before-backend precedence invariant).

## 2.2.0 — Stack-aware frontend-developer

Generalizes the `frontend-developer` agent from a hardcoded React/TS Mini App role into a single
stack-aware frontend that detects the stack first and reads the matching skill. The team config
already mapped one `frontend` role covering `.tsx`/`.jsx` and `src/jsMain`, so no new agents were
split out — splitting into react/vue/angular agents would have produced empty shells (Angular and
standalone Vue/TS have no skill).

### Changed
- **`agents/frontend-developer.md` rewritten as a stack router**: Step 0 stack detection (React/TS,
  Vue/TS, Angular, Telegram Mini App, Kotlin/JS + React/Vue) → read the matching skill as the
  source of truth. Honest fallback for un-skilled stacks (Vue/TS, Angular) via Context7/DeepWiki,
  with an instruction to flag the missing skill.
- **Slimmed the inline React patterns** that duplicated the `react-vite` skill; kept cross-cutting
  policy (i18n, in-app dialogs, no-`any`, naming, output format).
- **Compose WASM removed from the frontend zone** — canvas Compose sharing `commonMain` +
  `compose-arch` belongs to `developer-mobile`; `wasmJs` tasks are flagged for re-route.
  `commands/team.md` agent table + specializations updated to match the new zone boundary.
- **`workflows/team.config.example.json`** frontend `scope_map` glob extended with `**/*.vue` and
  `**/*.ts` so Vue and plain-TS files route to the frontend role.

### Added
- **KMP shared-logic section** in the agent (references `kmp` + `kotlin-web`, no duplication):
  Kotlin/JS consumes `commonMain` directly; TS frontends share via the API contract
  (generated types / OpenAPI), not by re-deriving business rules client-side.

## 2.1.2 — Orchestrator role boundary

Strengthens 2.1.1's delegate-don't-DIY rule, which two real runs proved insufficient. In both
(cc-proxy and chatkeep) the orchestrator classified correctly, then did the **entire**
investigation/implementation inline (dozens of `Bash`/`Read`/`ssh`/`Edit` calls) and launched
agents only afterward to rubber-stamp a diagnosis it had already reached — the consilium became
decorative. Root cause of the slip: `discovery` is an `orchestrator`-type stage, and "you do it
inline (no subagent)" read as a blank cheque for unbounded inline work.

### Changed
- **New `ORCHESTRATOR ROLE BOUNDARY` section in `commands/team.md`** — frames the orchestrator
  as a **router, not the executor**, with an explicit allowed tool surface (git plumbing,
  `.work-state/**` + config + stage files, `Task`/`AskUserQuestion`/`TodoWrite`) and an explicit
  forbidden set (reading app source to understand behavior, codebase search, builds/tests/repros,
  prod ssh, DB queries, log spelunking, **all** code edits — those belong to an agent). Includes a
  5-point **smell test** ("on your 3rd domain `Bash`/`Read` with no `Task` launched → stop and
  delegate") and the two real anti-patterns by name.
- **`orchestrator`-type stages are now scoped to *orientation, not investigation*** (Step C + a
  scope-ceiling banner in `workflows/stages/discovery.md`): discovery = branch + read state/config
  + filename-level skim to route. The moment you need a root cause / deep app logic / prod / build
  / repro → that is the delegated `exploration`/`diagnose` stage.
- **HARD RULE 3** reworded to close the loophole: investigation/implementation must not be
  smuggled into an `orchestrator` `discovery` stage.

### Added
- **`team-nudge.sh` emits the absolute plugin-assets root** on `/team`. The `workflows/...`
  profile/stage/schema files live in the plugin dir (the plugin cache at runtime), not the
  user's CWD, so a bare `Read workflows/stages/<id>.md` doesn't resolve and the model had to
  hunt the cache. Markdown bodies don't interpolate `${CLAUDE_PLUGIN_ROOT}`, but hook processes
  get it — so the nudge prints `📂 Plugin assets root: <abs>` and the model reads lazily from
  there. No copying into `~/.claude` (rejected: drift on plugin updates, two sources of truth,
  unsupported by Claude Code) — single source of truth stays the plugin itself. team.md's STAGE
  REFERENCE documents the resolution rule.

### Notes
- Still prompt discipline, not hook-enforced — a guard hook cannot distinguish the orchestrator's
  `Bash` from a subagent's own `Bash`. A counter-based PreToolUse *nudge* (warn after N inline
  domain calls on a delegated stage) is the candidate next step if the boundary keeps slipping.
- Tests now 88 assertions (role-boundary governance + plugin-root emission); CI watches
  `commands/team.md`.

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
