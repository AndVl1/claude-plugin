# Dream Team Plugin for Claude Code

A comprehensive fullstack development plugin with 12+ specialized agents for building modern applications: Kotlin/Spring Boot backends, React web frontends, KMP mobile apps, Telegram bots, DevOps pipelines, and AI integration.

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

### 12 Specialized Agents
| Agent | Description |
|-------|-------------|
| `analyst` | Requirements analyst - clarifies requirements, researches patterns |
| `architect` | Technical architect - designs APIs, data models, implementation plans |
| `code-reviewer` | Code quality reviewer - security, patterns, best practices |
| `developer` | Backend developer - Kotlin/Spring services |
| `developer-mobile` | Mobile developer - KMP with Compose UI |
| `devops` | DevOps engineer - Docker, K8s, Helm, CI/CD |
| `discovery` | Repository discovery - analyzes codebases |
| `frontend-developer` | Frontend developer - React/TypeScript |
| `init-mobile` | Mobile project initializer - creates KMP projects |
| `manual-qa` | Manual QA tester - UI testing via Chrome/Mobile MCP |
| `qa` | QA engineer - writes tests, reviews code |
| `security-tester` | Security specialist - vulnerability assessment |
| `tech-researcher` | Research agent - documentation, best practices |

### Commands (User-invokable Skills)
| Command | Description |
|---------|-------------|
| `/fullstack-team:team` | 7-phase feature development with parallel agents |
| `/fullstack-team:interview` | Deep interview to clarify ideas before implementation |
| `/fullstack-team:init-mobile` | Create KMP Compose Multiplatform project |
| `/fullstack-team:update-readme` | Update project README |

### 20+ Agent Skills
Domain knowledge for: Kotlin, Spring Boot, React, KMP, Compose, Decompose, Ktor, JOOQ, OpenTelemetry, and more.

### Safety Hooks
- Protected branch enforcement (main/production)
- State synchronization reminders
- File change logging
- MCP tools access control (manual-qa agent only)
- Sensitive file protection (.env, credentials)

## Plugin Structure

```
claude-plugin/
├── .claude-plugin/
│   ├── plugin.json       # Plugin manifest
│   └── marketplace.json  # Marketplace catalog
├── agents/               # 12 agent definitions
├── commands/             # User-invokable commands
├── skills/               # Domain knowledge (20+ skills)
├── workflows/            # Declarative workflow profiles (JSON) + schemas
│   ├── _schema.json          # Profile schema (stage taxonomy)
│   ├── artifacts-schema.json # Typed handoff contracts
│   ├── team.config.example.json # Per-project role→agent/model/scope (copy to .claude/)
│   └── <name>.json           # One profile per workflow
├── hooks/
│   ├── hooks.json        # Safety + state hooks
│   └── validate-state.sh # Deterministic classification + transition gate
├── tests/                # Cross-platform hook test suite
└── README.md
```

### Deterministic workflows

`/team` no longer interprets its workflow from prose — it resolves a **declarative profile**
(`workflows/*.json`) from the task classification and walks the stages mechanically, so the
same input takes the same path every run. Each stage hands off **typed artifacts** under
`.work-state/artifacts/`, and a hook (`hooks/validate-state.sh`) gates agent launches when the
state's classification, workflow, or stage progress is inconsistent. Per-project role→agent,
model, and scope mapping lives in `.claude/team.config.json` (see
`workflows/team.config.example.json`). Full design: `workflows/README.md`.

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
- Optional MCP servers: deepwiki, context7, claude-in-chrome, mobile

## References

This plugin was inspired by and built upon:

- [Anthropic's feature-dev plugin](https://github.com/anthropics/claude-code/blob/main/plugins/feature-dev/commands/feature-dev.md) - Official Claude Code plugin patterns
- [Dream Team by ashchupliak](https://github.com/ashchupliak/dream-team) - Multi-agent development workflow

## License

MIT
