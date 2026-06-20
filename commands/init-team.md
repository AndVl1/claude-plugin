---
description: Detect project stacks + available agents, generate .claude/team.config.json (role→agent + scope_map)
argument-hint: (no args; scans the current project)
---

# Init Team — Project Agent Configuration

Generates a project-specific **`.claude/team.config.json`** so `/team` routes
`${scope.dev_agent}` and consilium roles to the **right agents for THIS project's stacks** —
including agents from **other installed plugins** (e.g. `rust-agents` for a Rust repo).

**The problem it solves.** `${scope.dev_agent}` resolves only from `scope_map`. If no glob
matches a file type (say `**/*.rs`), the scope is unresolved and the orchestrator improvises —
it grabs whatever developer agent exists (often the wrong language). This command writes an
explicit map so routing is deterministic instead of a guess. (This is the previously-planned
P3; see `workflows/README.md`.)

This command is **interactive**: it detects, proposes, asks you to confirm/override, then
writes. It never overwrites an existing config without showing the diff first.

---

## Step 0 — Orientation (orchestrator, inline)

1. Read `.claude/team.config.json` if it exists — treat it as the **starting point** to
   update, not something to clobber. Note which scopes/roles are already mapped.
2. Read the plugin's baseline `${CLAUDE_PLUGIN_ROOT}/workflows/team.config.example.json` —
   the full default shape you will produce (roles, models, scope_map, flags, roster_overrides).

Do NOT scan the codebase yourself here — that is the discovery agent's job (next step). Step 0
is orientation only.

## Step 1 — Detect stacks + discover agents (delegate to `discovery`)

Launch the **`discovery`** agent (one `Task`, `subagent_type: "discovery"`, or the
`config.roles.discovery` override) with the **Team-Config Discovery** brief below. It returns a
structured inventory; you do not investigate inline.

```
Run TEAM-CONFIG DISCOVERY for this repository. Return TWO inventories.

A) DETECTED STACKS — for each language/runtime actually present:
   - language (rust, go, kotlin-jvm, kmp, typescript-web, python, dotnet, ruby, ...)
   - evidence: which manifest(s) / extensions (Cargo.toml, go.mod, build.gradle.kts, pom.xml,
     package.json, pyproject.toml, *.csproj, Gemfile) and a file count
   - proposed scope name + glob patterns (e.g. rust → ["**/*.rs","**/Cargo.toml"])
   - is it the dominant stack?

B) AVAILABLE AGENTS — scan ALL of these agent sources and read each agent's frontmatter:
   - this plugin: ${CLAUDE_PLUGIN_ROOT}/agents/*.md
   - other installed plugins: ~/.claude/plugins/**/agents/*.md
     (marketplaces/*/<plugin>/agents and cache/*/<plugin>/<version>/agents)
   - project agents: .claude/agents/*.md
   - user agents: ~/.claude/agents/*.md

   For EACH agent return: { invoke_name, agent_name, namespace, specialty, source_path }.
   CRITICAL — the invoke_name (what goes into Task subagent_type) is:
     • a bare <name> for project (.claude/agents) and user (~/.claude/agents) agents
     • "<plugin>:<name>" for a plugin agent, where <plugin> is the "name" field in that
       plugin's plugin.json (.claude-plugin/plugin.json or plugin.json one level up from
       agents/) — NOT the directory name. (e.g. dir claude-rust-agents/rust-code → name
       "rust-agents" → invoke "rust-agents:rust-developer".)
   Infer `specialty` from the agent name + description (language, role: dev/architect/
   reviewer/qa/security/devops/diagnostics).

Be factual. List only agents that exist. READ ONLY — do not modify anything.
```

## Step 2 — Propose the mapping (orchestrator)

From the two inventories build a proposed config:

- **scope_map** — one entry per detected stack: `{ glob, scope, dev_agent }`. `dev_agent` =
  the best-matching developer agent's `invoke_name` (specialty language == stack, role dev).
  Order specific globs before generic; first match wins.
- **roles** — map the consilium roles (`architect`, `code-reviewer`, `qa`, `security-tester`,
  `devops`, `diagnostics`, plus a per-stack dev key) to the best candidate per role. Prefer a
  language-specialised agent when one exists (Rust repo → `rust-agents:rust-architect` over the
  generic `architect`); fall back to this plugin's default otherwise.
- **roster_overrides** — when a stack has a dedicated reviewer/critic, `add` it to the `review`
  stage; when it has its own architect, `replace` the `architecture` roster.
- Keep `models`, `flags` from the baseline; adjust `flags.has_security` globs for the stack
  (e.g. Rust → add `**/unsafe*`).

For every mapping where there is **no clear single candidate** (zero matches, or two+ equally
good), mark it **AMBIGUOUS** — do not silently pick.

## Step 3 — Confirm (checkpoint, `AskUserQuestion`)

Present the proposed scope_map + role mapping as a table. Then:

- For each **AMBIGUOUS** mapping, ask via `AskUserQuestion` (offer the candidate agents +
  "this plugin's default" + an "enter a name myself" path). Multi-select where several stacks
  share a question.
- Also confirm the overall map once before writing.

Agent names are passed **verbatim** to `Task` and are **not** validated by any hook — a typo
fails at the `Task` call, not at a gate. So confirmation here matters; show the exact
`invoke_name` strings the user is approving.

(If invoked in an autonomous/non-interactive context, skip the questions, auto-pick the
top candidate per stack, and clearly log every AMBIGUOUS auto-decision in the summary.)

## Step 4 — Write + validate

1. Write `.claude/team.config.json` (full config — start from the baseline shape, fold in the
   confirmed scope_map / roles / roster_overrides). If a config existed, show a diff first.
2. **Validate JSON**: `jq empty .claude/team.config.json` (or `python3 -m json.tool`).
3. **Dry-run the scope_map**: for each entry, glob the repo and report how many files match;
   list any common source file types that match **no** scope (the misrouting risk). Example:
   ```
   scope_map dry-run:
     rust     **/*.rs, **/Cargo.toml   → 137 files → rust-agents:rust-developer
     devops   **/*.yml, **/.github/**   →   4 files → rust-agents:rust-cicd-devops
   unresolved file types: (none)
   ```

## Step 5 — Summary

Print:
- the scope→agent table that was written,
- the role→agent table,
- any unresolved file types (and a suggestion to add a scope),
- the reminder that agent names are not hook-validated (verify with `/agents` if unsure),
- next step: run `/team <task>` — it will now route to the configured agents.

---

## Notes

- **`.claude/team.config.json` is the full config** — when present the interpreter uses it
  as-is (it does not merge with built-in defaults). So this command always emits a complete
  file, including the generic roles you still want.
- **Polyglot repos** — emit a scope_map entry per stack; order matters (specific before
  generic).
- **No agent for a stack** — if discovery finds a stack but no matching agent in ANY source,
  say so explicitly and map it to the closest generic dev agent, flagged, rather than guessing
  silently. Suggest installing a suitable plugin.
- **Read-only discovery** — the discovery agent must not modify project code; only this command
  writes, and only `.claude/team.config.json`.
