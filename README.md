# Dream Team Plugin for Claude Code

A comprehensive fullstack development plugin with 14 specialized agents for building modern applications: Kotlin/Spring Boot backends, React web frontends, KMP mobile apps, Telegram bots, DevOps pipelines, and AI integration.

`/team` runs a **deterministic, profile-driven workflow** with a Definition-of-Done gate — the same task takes the same path every run, and a task can't claim "done" without verified acceptance criteria.

## Installation

### Option 1: Install from Marketplace (Recommended)

1. Add the marketplace:
```
/plugin marketplace add AndVl1/claude-plugin
```

2. Install the plugin:
```
/plugin install fullstack-team@andvl1-plugins
```

### Option 2: Install directly from GitHub

```
/plugin install github:AndVl1/claude-plugin
```

### Option 3: Local development

```bash
claude --plugin-dir /path/to/claude-plugin
```

## Marketplace Setup

If you want to add this marketplace to your team's project, add to `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "andvl1-plugins": {
      "source": {
        "source": "github",
        "repo": "AndVl1/claude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "fullstack-team@andvl1-plugins": true
  }
}
```

## Features

### 14 Specialized Agents
| Agent | Description |
|-------|-------------|
| `analyst` | Requirements analyst - clarifies requirements, researches patterns |
| `architect` | Technical architect - designs APIs, data models, implementation plans |
| `code-reviewer` | Code quality reviewer - security, patterns, best practices |
| `developer-backend` | Backend developer - Kotlin/Spring services, JOOQ, bots |
| `developer-mobile` | Mobile developer - KMP with Compose UI |
| `devops` | DevOps engineer - Docker, K8s, Helm, CI/CD |
| `diagnostics` | Bug investigator - 5-phase diagnostic workflow, root-cause analysis |
| `discovery` | Repository discovery - analyzes codebases |
| `frontend-developer` | Frontend developer - React/TypeScript |
| `init-mobile` | Mobile project initializer - creates KMP projects |
| `manual-qa` | Manual QA tester - UI testing via Chrome/Mobile MCP |
| `qa` | QA engineer - writes tests, reviews code |
| `security-tester` | Security specialist - vulnerability assessment |
| `tech-researcher` | Research agent - documentation, best practices |

> Workflows can also use **custom agents** — project (`.claude/agents/`), user
> (`~/.claude/agents/`), or another plugin (`<plugin>:<agent>`) — via `.claude/team.config.json`.

### Commands (User-invokable Skills)
| Command | Description |
|---------|-------------|
| `/fullstack-team:team` | 7-phase feature development with parallel agents |
| `/fullstack-team:interview` | Deep interview to clarify ideas before implementation |
| `/fullstack-team:init-mobile` | Create KMP Compose Multiplatform project |
| `/fullstack-team:update-readme` | Update project README |

### 20+ Agent Skills
Domain knowledge for: Kotlin, Spring Boot, React, KMP, Compose, Decompose, Ktor, JOOQ, OpenTelemetry, and more.

### Safety & Determinism Hooks
- **Classification gate** — blocks agent launches when `team-state.json` lacks a classification
  or its workflow mismatches `type×complexity` (`hooks/validate-state.sh`)
- **Definition-of-Done gate** — blocks a "done" claim with unmet/evidence-less DoD; never nags
  mid-work, always allows intentional pauses (`hooks/dod-gate.sh`)
- **Monotonic stage progress** — blocks phase-skipping in state
- Protected branch enforcement (main/production)
- MCP tools access control (manual-qa agent only)
- Sensitive file protection (.env, credentials)
- State synchronization reminders, file change logging

> Gates degrade gracefully (no `jq` or legacy markdown-only state → no enforcement) and have
> escape hatches (`workflow_override`, `pause.kind`, `.work-state/.dod-override`).

## Plugin Structure

```
claude-plugin/
├── .claude-plugin/
│   ├── plugin.json       # Plugin manifest
│   └── marketplace.json  # Marketplace catalog
├── agents/               # 14 agent definitions
├── commands/             # User-invokable commands
├── skills/               # Domain knowledge (23 skills)
├── workflows/            # Declarative workflow profiles (JSON) + schemas
│   ├── _schema.json          # Profile schema (stage taxonomy)
│   ├── artifacts-schema.json # Typed handoff contracts (incl. dod)
│   ├── team.config.example.json # Per-project role→agent/model/scope (copy to .claude/)
│   ├── stages/               # Per-stage prompt templates (loaded on demand)
│   └── <name>.json           # One profile per workflow
├── hooks/
│   ├── hooks.json        # Safety + state hooks
│   ├── validate-state.sh # Classification + transition gate
│   ├── dod-gate.sh       # Definition-of-Done backstop
│   └── team-nudge.sh     # /team reminder to classify before working
├── tests/                # Cross-platform hook test suite
├── CHANGELOG.md
└── README.md
```

### Deterministic workflows

`/team` no longer interprets its workflow from prose — it resolves a **declarative profile**
(`workflows/*.json`) from the task classification and walks the stages mechanically, so the
same input takes the same path every run. Each stage hands off **typed artifacts** under
`.work-state/artifacts/`, and a hook (`hooks/validate-state.sh`) gates agent launches when the
state's classification, workflow, or stage progress is inconsistent. Per-project role→agent,
model, and scope mapping (and custom-agent roster overrides) live in `.claude/team.config.json`
(see `workflows/team.config.example.json`).

A **Definition of Done** is fixed before code (acceptance criteria + how each is verified) and
closed only with proof; a Stop-hook backstop blocks a "done" claim while items are unmet. Full
design: `workflows/README.md`.

## Usage

### Team Workflow
```
/fullstack-team:team implement user authentication feature
```

### Interview
```
/fullstack-team:interview mobile app for recipe sharing
```

## State Management

The plugin tracks progress in `.work-state/`: `team-state.json` is the machine source of
truth (classification, stage cursor, monotonic stage status) consumed by the interpreter and
the validation hook; `team-state.md` is the human-readable mirror. Handoff artifacts live in
`.work-state/artifacts/`. The markdown file (created as below) keeps the legacy hooks working:

```bash
mkdir -p .work-state
```

```markdown
# Team State

## Current Task
**Feature**: [Feature name]
**Branch**: [branch-name]

## Phases
- [ ] Phase 1: Analysis
- [ ] Phase 2: Architecture
- [ ] Phase 3: Implementation
- [ ] Phase 4: Testing
- [ ] Phase 5: Code Review
```

> **Note**: Earlier versions used `.claude/` for state files. The plugin hooks check both locations for backward compatibility, but new sessions should always use `.work-state/`.

## Requirements

- Claude Code CLI v1.0.33+
- `jq` recommended — the determinism/DoD gates use it; without it they degrade to no-ops
- Optional MCP servers: deepwiki, context7, claude-in-chrome, mobile

## References

This plugin was inspired by and built upon:

- [Anthropic's feature-dev plugin](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/commands/feature-dev.md) - Official Claude Code plugin patterns
- [Dream Team by ashchupliak](https://github.com/ashchupliak/dream-team) - Multi-agent development workflow

## License

MIT
