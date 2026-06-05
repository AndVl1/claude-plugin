# Исследование: как сделать плагин fullstack-team детерминированнее

**Дата:** 2026-06-06
**Тип:** INVESTIGATION / RESEARCH
**Источники:** [harnest](https://github.com/AlexGladkov/harnest), [claude-code-agents](https://github.com/AlexGladkov/claude-code-agents), наш `fullstack-team` v1.10.3

---

## 1. Что изучено

### Harnest
Генератор harness-конфигов (CLAUDE.md/.cursorrules/AGENTS.md и т.д.) для мультистек-проектов. Ключевое для нас — **не генерация конфигов, а модель workflow**:

- **Workflow-профили = декларативный список стадий.** 6 встроенных:
  - `business-feature`: Research → Plan → Executing → Validation → Report
  - `bug-hunting`: Reproduce → Diagnose → Fix → Validation → Report
  - `research`: Consilium без изменений кода
  - `refactoring`: Audit → Plan → Executing → Regression check
  - `e2e-testing`: Prepare → Deploy → Run → Fix → Re-run → Report
  - `e2e-authoring`: Research → Propose → Approve → Save scenarios
- **Тип стадии — данные, не проза.** Каждая стадия объявляет агент-тип: `single | consilium | bash | none`.
- **Роль → агент резолвится один раз** (wizard при init), потом таблица. 9 ролей консилиума: architect, frontend, ui, security, devops, api, diagnostics, test, mobile.
- **Non-interactive режим — первого класса** (`--non-interactive`, авто-дефолты для CI).
- **Marker-based сохранение** правок (`<!-- harnest-managed -->`) при апдейтах.

> Важно: наш текущий `~/.claude/CLAUDE.md` — это уже вывод harnest (роли консилиума, таблица роль→агент, профили в `~/.claude/profiles/`). То есть мы уже частично в этой экосистеме, но плагин `fullstack-team` живёт **параллельно** и не использует декларативную модель.

### claude-code-agents
Доменно-иерархическая организация агентов, marketplace-плагины.

- **Жёсткий последовательный pipeline:** `init-kotlin → builder-spring/compose → test-spring → kotlin-diagnostics → refactor → security-kotlin → devops-orchestrator`.
- **Знания живут внутри агентов** (config/university.yaml как source-of-truth) — **подход, который мы не берём** (пользователь предпочитает скиллы как слой знаний).
- **Что взять:** идею явных **prerequisite/handoff-контрактов** между шагами и именованную последовательность.
- Архитектурное принуждение: feature-slice пути (`feature/<name>/api/service/persistence/domain`).

---

## 2. Где наш плагин недетерминирован (корень проблемы)

**Главное:** workflow — это **проза** (`commands/team.md`, ~1100 строк), которую модель читает и интерпретирует, а не **данные**, по которым оркестратор шагает механически.

Текущая философия документа: *«детерминизм на воротах (классификация, выбор workflow, порог 80% на ревью), вольница на планировании»*. Именно «вольница на планировании» даёт разброс между запусками:

| # | Точка | Сейчас (недетерминировано) | Эффект |
|---|-------|----------------------------|--------|
| G1 | Исполнение workflow | EM читает 1100 строк прозы и сам решает порядок/состав | разный путь на одинаковом входе |
| G2 | Phase 0 классификация | keyword-таблицы, но финал type/complexity = суждение модели | граничные кейсы плавают |
| G3 | Выбор агентов в фазе | «EM выбирает какие 2-3 агента запустить» (Phase 2, 6) | разный состав консилиума |
| G4 | Scope (backend/frontend/mobile) | суждение EM по задаче | не тот dev-агент |
| G5 | Handoff между фазами | «paste section» — блоб текста в промпт | теряется при компактизации, не типизирован |
| G6 | State-файл | markdown-чеклист, обновляется моделью → дрейф (хуки уже борются) | рассинхрон фаз |
| G7 | Роль→агент + модели | проза в global CLAUDE.md | резолв «на глаз», нет per-project |

---

## 3. Предлагаемые доработки (по приоритету)

### P1 — Декларативные workflow-профили (главное, заимствуем у harnest)

Вынести каждый workflow (FULL / STANDARD / LIGHTWEIGHT / BUG_FIX / EMERGENCY / RESEARCH / REVIEW) из прозы в **данные**: `workflows/<name>.yaml`. Оркестратор `team.md` ужимается до интерпретатора: «загрузи профиль → иди по стадиям → проверь gate → следующая».

Схема стадии (синтез harnest `type` + контракты claude-code-agents):

```yaml
name: full-feature
stages:
  - id: discovery
    type: orchestrator          # в главном контексте, без субагента
    gate: branch_created
    output: feature_description
  - id: exploration
    type: consilium             # параллельный мульти-роль
    roles: [analyst, tech-researcher]
    parallel: true
    output: exploration.json    # files_to_read[], patterns[]
  - id: clarify
    type: orchestrator
    checkpoint: user_answers    # в autonomous — skip+log
    output: clarifications
  - id: architecture
    type: consilium
    roles: [architect, architect, architect]   # minimal/clean/pragmatic
    output: architecture.json   # approach_options[]
    checkpoint: user_choice     # autonomous → option #1
  - id: implementation
    type: single                # резолв по scope (см. P3)
    role: "${scope.dev_agent}"
    output: impl.json           # files_touched[], commits[]
  - id: review
    type: consilium
    roles: [qa, code-reviewer]
    conditional:                # состав = данные, не суждение
      - if: scope.has_security
        add: security-tester
      - if: scope.has_ui
        add: manual-qa
    gate: confidence>=80
    output: review.json
  - id: review_fixes
    type: single
    role: "${issue.zone.dev_agent}"
    skip_if: review.issues == []
  - id: summary
    type: bash                  # детерминированный шаг, без модели
    cmd: scripts/summarize.sh
```

Закрывает: **G1, G3**. Один вход → один путь стадий.

### P2 — Типизированные handoff-артефакты вместо «paste section»

Каждая стадия пишет **типизированный output-файл** в `.work-state/` (`exploration.json`, `architecture.json`, `review.json`). Следующая стадия читает файл, а не вставленный блоб. Схема файла = контракт (как prerequisite в claude-code-agents).

Плюсы: переживает компактизацию; контракт валидируется хуком; нет потери контекста в промпте.

Закрывает: **G5**, усиливает **G6**.

### P3 — Scope-резолв по glob-таблице (детерминированно)

Затронутые/планируемые пути → набор scope-флагов → набор агентов. Таблица (как «Executing» в global CLAUDE.md, но в плагине):

```yaml
scope_map:
  - glob: "**/*.kt"          # + не iosApp/composeApp
    scope: backend
    dev_agent: developer-backend
  - glob: "**/src/jsMain/**, **/*.tsx"
    scope: frontend
    dev_agent: frontend-developer
  - glob: "composeApp/**, **/commonMain/**"
    scope: mobile
    dev_agent: developer-mobile
flags:
  has_security: glob("**/auth/**", "**/security/**", "**/*crypto*")
  has_ui: scope ∋ {frontend, mobile}
```

Закрывает: **G4**; кормит conditional-составы из P1.

### P4 — Машиночитаемый state + легальные переходы

`team-state.md` → `team-state.json` со **stage cursor**. Хук валидирует, что курсор двигается легально (нельзя прыгнуть exploration→review). Уже частично есть PreToolUse-проверка свежести — добавить schema-валидацию перехода.

Закрывает: **G6**.

### P5 — Структурированная классификация как артефакт-ворота

Phase 0 обязана эмитить структурный блок `CLASSIFICATION` (type/complexity/confidence/workflow) → записать в state **до** любого агента → хук валидирует наличие и допустимость комбинации (по таблице Type×Complexity→Workflow). Опционально: bash-скрипт-скоринг по file-count/keywords как подсказка, чтобы убрать дрейф на границах.

Закрывает: **G2**.

### P6 — Per-project `team.config.json` (резолв роль→агент/модель)

Вынести из прозы global CLAUDE.md в конфиг плагина на проект: роли→агенты, модели по ролям, scope-globs, design-system. Резолв детерминированный, без «спросить пользователя» в рантайме. По духу = harnest `agents list|set`.

Закрывает: **G7**.

### P7 (опционально) — init-генератор в духе harnest

Команда `/team-init`: детект стека → предложить workflow-профили + сгенерировать `team.config.json`. Делает онбординг детерминированным. Большой объём — отдельная веха.

---

## 4. Что НЕ берём

- **Знания внутри агентов** (claude-code-agents). Оставляем скиллы как слой знаний — это сильная сторона нашего плагина. Из claude-code-agents берём только идею **контрактов между стадиями**, не размещение знаний.

---

## 5. Матрица детерминизма: сейчас → цель

| Аспект | Сейчас | После P1–P6 |
|--------|--------|-------------|
| Порядок стадий | проза/суждение | данные (профиль) |
| Состав консилиума | суждение EM | conditional по флагам |
| Scope→агент | суждение | glob-таблица |
| Handoff | текст-блоб | типизированный JSON |
| State | md-чеклист | json + cursor + валидация переходов |
| Классификация | финал = суждение | артефакт-ворота + валидация |
| Роль→агент/модель | проза в CLAUDE.md | per-project config |

---

## 6. Рекомендуемый порядок внедрения

1. **P1 + P2** (профили + handoff-артефакты) — даёт 80% эффекта, ужимает team.md.
2. **P3 + P5** (scope-таблица + классификация-ворота) — убирает оставшийся разброс.
3. **P4 + P6** (json-state + per-project config) — инфраструктура.
4. **P7** — позже, отдельно.

Каждый пункт обратно-совместим: профили можно вводить по одному, оставляя прозу как fallback.
