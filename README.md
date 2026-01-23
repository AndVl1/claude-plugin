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
/plugin install dream-team@fullstack-prod-team
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
    "fullstack-prod-team": {
      "source": {
        "source": "github",
        "repo": "AndVl1/claude-plugin"
      }
    }
  },
  "enabledPlugins": {
    "dream-team@fullstack-prod-team": true
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
| `/dream-team:team` | 7-phase feature development with parallel agents |
| `/dream-team:solo` | Incremental development workflow |
| `/dream-team:interview` | Deep interview to clarify ideas before implementation |
| `/dream-team:init-mobile` | Create KMP Compose Multiplatform project |
| `/dream-team:update-readme` | Update project README |

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
├── hooks/
│   └── hooks.json        # Safety hooks
└── README.md
```

## Usage

### Team Workflow
```
/dream-team:team implement user authentication feature
```

### Solo Workflow
```
/dream-team:solo add pagination to the API
```

### Interview
```
/dream-team:interview mobile app for recipe sharing
```

## State Management

The plugin uses `.claude/team-state.md` to track progress across agent sessions. Create this file in your project:

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

## Requirements

- Claude Code CLI v1.0.33+
- Optional MCP servers: deepwiki, context7, claude-in-chrome, mobile

## License

MIT
