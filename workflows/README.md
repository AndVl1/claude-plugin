# Workflow Profiles

Declarative workflow definitions consumed by the `/team` interpreter. Each profile is a
JSON file describing an **ordered list of stages**. The interpreter does not "decide" the
workflow from prose — it resolves a profile from the classification, then walks the stages
mechanically. Same classification → same stage sequence.

> **Why this exists**: previously the entire workflow lived as prose in `commands/team.md`
> and the orchestrator interpreted it freely, so borderline tasks took different paths on
> different runs. Profiles turn the workflow into **data** (harnest-style stage taxonomy).
> See `vibe-report/determinism-research-2026-06-06.md` for the rationale (P1).

## Files

| File | Purpose |
|------|---------|
| `_schema.json` | JSON Schema for a profile (stage taxonomy, fields). |
| `artifacts-schema.json` | Typed handoff contracts written to `.work-state/artifacts/<id>.json` (P2). |
| `<name>.json` | One profile per workflow. |
| `stages/<id>.md` | Per-stage prompt templates / criteria, **loaded on demand** by the interpreter (P9). The file name equals the stage `id`. Keeps `commands/team.md` lean — it holds only governance; the "how" of each stage is read only when that stage runs. |

## Stage taxonomy (`stage.type`)

Borrowed from harnest. Every stage is exactly one of:

| type | meaning |
|------|---------|
| `orchestrator` | Main context performs it directly (no subagent). E.g. discovery, summary, clarifying questions. |
| `single` | Exactly one subagent. Role resolved via `.claude/team.config.json` or file scope. |
| `consilium` | N subagents in parallel (`roles[]`). E.g. exploration, architecture options, review. |
| `bash` | Deterministic shell step, no model. |
| `none` | Placeholder / skip. |

## Profile resolution (deterministic)

Classification (`type` + `complexity`) selects exactly one profile. Profiles are tested in
**selection order** below; the **first** profile whose `match` passes wins. A `match` passes
when `classification.type ∈ match.type` AND (`classification.complexity ∈ match.complexity`
OR `match.complexity` is absent).

**Selection order:**

1. `full-feature`
2. `debug-cycle`
3. `bug-fix`
4. `standard`
5. `lightweight`
6. `research`
7. `review`
8. `emergency`

Resulting table (every Type × Complexity resolves):

| Type | QUICK | MEDIUM | COMPLEX | CRITICAL |
|------|-------|--------|---------|----------|
| FEATURE | lightweight | standard | full-feature | full-feature |
| REFACTOR | lightweight | standard | full-feature | full-feature |
| OPS | lightweight | standard | standard | standard |
| BUG_FIX | bug-fix | debug-cycle | debug-cycle | debug-cycle |
| INVESTIGATION | research | research | research | research |
| REVIEW | review | review | review | review |
| HOTFIX | emergency | emergency | emergency | emergency |

**Fallback**: if no profile matches (e.g. a custom type), the interpreter uses `standard`.

**Autonomous override**: in autonomous mode, every `BUG_FIX` uses `debug-cycle` regardless
of complexity (the diagnostics ↔ manual-qa loop is how a hypothesis is formed without a human).

This table is mirrored in `hooks/validate-state.sh` (P5) — the classification gate blocks
launching agents if `team-state.json`'s `workflow` does not match its `classification`.

## Interpreter contract (how `/team` walks a profile)

1. **Classify** the request → emit a structured `CLASSIFICATION` block → write
   `.work-state/team-state.json` **before launching any agent** (P5 gate).
2. **Resolve** the profile from the table above; load `workflows/<name>.json`.
3. For each stage in order:
   - **skip** if `skip_if` evaluates true.
   - **read** every artifact id in `consumes` from `.work-state/artifacts/<id>.json` and
     thread relevant content into subagent prompts (no pasted prose — P2).
   - **run** per `type`: orchestrator (inline), single (one Task), consilium (parallel Tasks),
     bash (shell), none (skip). For `consilium`, apply `conditional[]` against scope flags to
     adjust the roster.
   - **resolve roles → agents → model** via `.claude/team.config.json` (P6), falling back to
     built-in defaults.
   - **checkpoint**: interactive → stop and wait; autonomous → apply `autonomous` decision + log.
   - **gate**: do not mark the stage `done` until the gate condition holds.
   - **write** the `produces` artifact to `.work-state/artifacts/<id>.json`.
   - **loop**: if the stage has a `loop`, repeat `back_to` until `until` or `max_iterations`.
   - **advance** `stage_cursor` in `team-state.json` and mirror progress into `team-state.md`.

The prose phase descriptions in `commands/team.md` remain as a **STAGE REFERENCE (fallback)** —
the detailed prompt templates and review criteria live there. Profiles drive *which* stages
run and *in what order*; the reference supplies the *how* for each stage type.

## Definition of Done (acceptance gate)

Profiles with an implementation phase produce a `dod` artifact early (exploration / discovery /
diagnose) and put `gate: dod_complete` on the `summary` stage. The DoD fixes acceptance criteria
*before* code, each with a verification method and (on close) proof. See the **DEFINITION OF
DONE** section in `commands/team.md` for the policy and per-type minimums.

Enforcement is two-layered and **never wedges the session**:
- **Primary**: the `dod_complete` gate (interpreter) and `root_cause_documented` gate (BUG_FIX,
  before implementation).
- **Backstop**: `hooks/dod-gate.sh` (Stop) reads `.work-state/artifacts/dod.json` (typed, not
  prose). It blocks (exit 2) **only at a done-claim** — `pause.kind == "done"` or
  `stage_cursor == "summary"` — with unmet or evidence-less items.

Stop is always allowed (no DoD enforcement) when: `pause.kind` ∈
`background_wait | user_checkpoint | needs_human | failed`; the workflow is
`research` / `review` / `emergency`; the state is stale (`branch` ≠ current); or
`.work-state/.dod-override` exists. `research`/`review`/`emergency` profiles intentionally
omit the `dod`/`dod_complete` stages.

## Scope flags (used by `conditional` and `${scope.*}`)

Resolved from touched/planned files against `.claude/team.config.json` `scope_map`. Run
**`/init-team`** to generate that file for your project — it detects the stacks and maps each to
the best available agent, including agents from other installed plugins (e.g. `rust-agents` for a
Rust repo). This is the former P3. Without a config, the interpreter falls back to inferring
scope from file globs using the built-in defaults below:

> **`scope_map` precedence — first match wins.** Entries are evaluated top-to-bottom; the first
> glob that matches a file decides its scope. Order specific paths above generic extensions. In
> particular `mobile` is listed **above** `backend-kotlin`: a KMP file like
> `shared/src/commonMain/Foo.kt` matches both `**/commonMain/**` (mobile) and `**/*.kt`
> (backend-kotlin), and resolves to **mobile** only because mobile comes first. So `**/*.kt`
> routes to `backend-kotlin` only when the file is **not** under a mobile source set (e.g. a
> Spring `src/main/kotlin`). `scope` names are free-form (project-defined by `/init-team`).

| flag | true when |
|------|-----------|
| `scope.has_security` | touches `**/auth/**`, `**/security/**`, `**/*crypto*`, or auth/secret logic |
| `scope.has_ui` | scope includes `frontend` or `mobile` |
| `scope.has_infra` | touches Docker/K8s/CI/CD/Helm |
| `${scope.dev_agent}` | `developer-backend` \| `developer-go` \| `frontend-developer` \| `developer-mobile` per dominant scope |

## Custom agents (project / user / other plugins)

A role resolves to a concrete agent via `.claude/team.config.json` `roles` (then the built-in
default). The resolved value is passed verbatim as the Task `subagent_type`, so it can be **any
registered agent**:

- project agent `.claude/agents/<name>` → bare `<name>`
- user agent `~/.claude/agents/<name>` → bare `<name>`
- another plugin's agent → `<plugin>:<name>`
- this plugin's agent → `fullstack-team:<name>` or the bare default

```jsonc
// .claude/team.config.json
{
  "roles": {
    "backend-kotlin": "my-jvm-backend",   // project agent
    "security-tester": "acme-sec:pentester"  // another plugin's agent
  },
  "models": { "my-go-backend": "opus" },
  "roster_overrides": {                  // add agents to a stage without forking a profile
    "review": { "add": ["my-a11y-agent"] }
  }
}
```

`roster_overrides[<stage id>]` is applied by the interpreter **after** the profile's
`conditional[]` rules: `replace` sets the whole roster, otherwise `add`/`remove` adjust it.
New role keys beyond the built-in set are allowed — reference them from a custom profile or a
roster override. Note: a hook cannot verify an agent exists, so a wrong name fails at the Task
call (not at a gate).

## Adding a custom profile

1. Copy an existing profile, give it a unique `name` (= filename).
2. Define `match` (or leave it unmatched and select it explicitly).
3. Order stages; set `consumes`/`produces` to existing artifact ids (or add new ones to
   `artifacts-schema.json`).
4. Validate: `jq empty workflows/<name>.json` and check against `_schema.json`.
