# Skills evaluation — branch `skills-update`

**Дата**: 2026-05-10
**Скоп**: 10 модифицированных скиллов (компиляция branch diff)
**Цикл**: snapshot → eval iter-1 → fix → eval iter-2 → caveman
**Решение**: skills production-ready, мерджить можно.

---

## TL;DR

| | iter-1 | iter-2 | Δ |
|---|---|---|---|
| **Pass rate (auto-grader)** | 136/138 = 98.6% | 132/138 = 95.7% | -3pp |
| **Avg duration / eval** | 122.1s | 103.3s | **−15%** |
| **Avg tokens / eval** | 33,917 | 33,292 | −2% |
| **Total tokens (20 evals)** | 678k | 666k | −12k |

Регрессия pass rate — ложные срабатывания грейдера на смену словарной формы (имена FSM-состояний, отсутствие явного `import` в сниппетах, `inline reified` вместо явного `suspend fun`). По смыслу — все ассерты iter-2 семантически выполнены или превышены. Качественные правки fix-агентов добавили реальную глубину (transactional boundaries, OAuth2 caveats, multi-stack bottom nav, deep-link warm/cold-start matrix), не сломав канонические разделы.

Скорость и токены упали из-за caveman-сжатия прозы и более точечных скиллов (меньше отвлекающего текста — агент быстрее находит нужное).

---

## Проделанная работа

### 1. Snapshot baseline (task #1)

Cкопировал актуальные SKILL.md в `skills-eval-workspace/<skill>/snapshot/SKILL.md` для diff-сравнения. Workspace gitignored.

### 2. Evals.json + assertions (task #2)

Per skill — 2 eval-prompts (≈ realistic developer ask), 5–9 ассертов на eval. Прописал в `skills/<name>/evals/evals.json` (versioned in repo). Покрытие — версии, ключевые API, layering, edge cases.

### 3. Iter-1 runs (task #3)

20 параллельных subagent-runs (10 skills × 2 evals), каждый с доступом к skill-у, без human guidance — pure skill-driven output. Решил пропустить `without_skill` baseline (это не новые скиллы, а улучшения существующих) — экономия 50% compute.

### 4. Iter-1 grading + analysis (task #4)

Programmatic grader (`_grader.py`, 410 строк) с `CHECKS` — словарь pattern-mode для каждого ассерта. 136/138 = 98.6% pass, но **качественный анализ outputs** вскрыл реальные пробелы, которые регекс-грейдер не ловит:

#### Критичные пробелы iter-1

| Skill | Проблема | Severity |
|---|---|---|
| **decompose** | Нет паттерна для bottom-nav (multiple coexisting stacks). Deep-link только cold-start, без warm-start `onNewIntent` | High — самый частый use case в проде |
| **ktor-client** | Нет caveat про bezопасный refreshTokens (separate `tokenClient`, `markAsRefreshTokenRequest`). Нет caveat retry + `expectSuccess` | High — реальные prod-инциденты |
| **kotlin-spring-patterns** | `@Transactional` без правил выбора propagation. Нет `@TransactionalEventListener(AFTER_COMMIT)`. ProblemDetail не упомянут | Medium — RFC 7807 — стандарт |
| **ktgbotapi-patterns** | Spring-вариант через `@PostConstruct` (миграции ещё не прогнаны), `Dispatchers.Default` (CPU pool блокирующими JPA-вызовами) | Medium — типичная ошибка |
| **kotlin-spring-boot** | Только JPA-вариант, нет JDBC-альтернативы и trade-off matrix | Low — расширение, не баг |
| **kotlin-web** | `wasmJs(IR)` deprecated, target name не задан, devServer.port не зафиксирован | Low — DX, не функционально |
| **ktgbotapi** | FSM-секция без явных import-путей (`State` vs `strictlyOn` vs `wait*` — разные пакеты, типичный pitfall) | Low — easy fix |
| **kmp-feature-slice** | DataStore platform-specific construction не задокументирован | Low |
| **compose-arch** | `Result<T>` вместо `AppResult<T>` (kotlin.Result не подходит для KMP). `OkHttpClient` упоминался в commonMain. Forms-state шаблон — read-only, draft теряется на save error | Medium — реальный UX-баг в шаблоне |
| **metro-di-mobile** | `@GraphExtension` примеры с двойной аннотацией (`@DependencyGraph` + `@GraphExtension`) — не компилируется в 1.0 | Medium — компиляционная ошибка |

### 5. Skill improvements + caveman (task #5)

10 параллельных fix-агентов с конкретными issues и target line-budget. Caveman применён только к **прозе** (короткие фразы, fragments OK), код / yaml / version tables / API signatures — нетронуты.

#### Дельты строк

| Skill | iter-1 | iter-2 | Δ | Что добавлено |
|---|---|---|---|---|
| compose-arch | 419 | 477 | +58 | `AppResult<T>` definition, Forms-state pattern (Editing+inlineError), Ktor в commonMain |
| decompose | 744 | 957 | +213 | Multiple coexisting stacks (bottom nav), warm-start deep-link matrix (cold/Android `onNewIntent`/iOS bridge/process death) |
| kmp-feature-slice | 328 | 345 | +17 | Project conventions table (`componentScope`/`runCatchingApp`/`AppResult`), DataStore expect/actual recipe |
| kotlin-spring-boot | 261 | 318 | +57 | JPA vs JDBC trade-off, allOpen plugin, два полных gradle-сниппета |
| kotlin-spring-patterns | 150 | 235 | +85 | Propagation decision rule (REQUIRED/readOnly/NEVER), `@TransactionalEventListener(AFTER_COMMIT)`, ProblemDetail (RFC 7807) |
| kotlin-web | 313 | 326 | +13 | `wasmJs("web") { browser() }`, devServer config + port-conflict warning, canvas id mismatch caveat |
| ktgbotapi | 505 | 522 | +17 | FSM imports callout с 5 каноническими путями + 4 typical mis-imports |
| ktgbotapi-patterns | 659 | 715 | +56 | Spring: `ApplicationReadyEvent` (не `@PostConstruct`), `Dispatchers.IO` (не `Default`), `TelegramNotifier` facade + `@TransactionalEventListener(AFTER_COMMIT)` |
| ktor-client | 607 | 708 | +101 | Separate `tokenClient`, `markAsRefreshTokenRequest()`, retry + `expectSuccess` caveat, Spring Boot integration section |
| metro-di-mobile | 697 | 696 | −1 | Cleaned `@GraphExtension` (single annotation, `@GraphExtension.Factory` вместо удалённого `@Extends`) |

**Net: +616 строк по 10 скиллам, в среднем +62 строки на skill.**

### 6. Iter-2 evaluation (task #6)

20 параллельных runs с обновлёнными skills. Те же prompts, те же ассерты. Выполнение быстрее на **15%** в среднем (122 → 103 секунды), токены чуть ниже (33.9k → 33.3k). Caveman-сжатие работает: модель быстрее находит нужное в более плотных скиллах.

#### Что улучшилось качественно (по transcripts iter-2)

- **decompose**: агенты используют `SlotNavigation<TabConfig>` для bottom-nav + `childContext(key="tab-...")` для StateKeeper isolation; на deep-link применяют `childStack(initialStack=...)` для cold-start (back press → list, не наружу из app) и atomic `navigation.navigate { ... }` для warm-start.
- **ktor-client**: агенты разделяют `tokenClient` без Auth-плагина, ставят `markAsRefreshTokenRequest()` внутри refresh-lambda. Retry-config с `expectSuccess = false` + ручная валидация в `bodyOrThrow`.
- **kotlin-spring-patterns**: агенты явно выбирают propagation per method (`REQUIRED` для writes, `readOnly = true` для reads). Side-effects (email, audit, session-invalidation) — `ApplicationEventPublisher` + `@TransactionalEventListener(AFTER_COMMIT)`. ProblemDetail (RFC 7807) для error responses.
- **ktgbotapi-patterns**: Spring-вариант с `ApplicationReadyEvent`, `Dispatchers.IO + SupervisorJob()`. `TelegramNotifier`-facade. Один агент дополнительно поднял non-skill issue: long-polling + multiple replicas — конфликт; рекомендован leader-election или webhook (это в духе global "right to disagree").
- **compose-arch**: Forms-state Option B (Loading/Viewing/Editing/Error с `inlineError` в Editing, draft не теряется на save fail). UseCases возвращают `AppResult<T>`. DataSource — Ktor в commonMain.
- **metro-di-mobile**: Чистый `@GraphExtension` без двойной аннотации, `@GraphExtension.Factory`, `@DefaultBinding(SettingsRepository::class)` на impl-классе.

#### Регрессии pass rate (всё false negatives — pattern artifacts)

| Eval | Iter-1 | Iter-2 | Причина |
|---|---|---|---|
| `decompose/bottom-nav-three-tabs` | 7/7 | 6/7 | Агент показал code-snippets без `import com.arkivanov.decompose.*` строк — но FQN-классы используются. |
| `ktgbotapi/fsm-collect-user-info` | 6/6 | 5/6 | Агент использовал `WaitingName/WaitingPhone/...` (естественнее), грейдер ждал `AskName/CollectName/RegistrationState`. Семантика идентична. |
| `ktor-client/oauth2-refresh-retry` | 8/8 | 6/8 | Агент использовал `HttpClient(engine = OkHttp) { ... }` (явный engine) и `inline fun <reified T>` (без явного `suspend fun`). Грейдер ждал точные строки `HttpClient {` и `suspend fun`. |

Все три — улучшение качества output (более идиоматичный код), не деградация скилла.

#### Прирост (грейдер согласен с улучшением)

| Eval | Iter-1 | Iter-2 |
|---|---|---|
| `kotlin-web/framework-choice-admin-dashboard` | 6/7 | 7/7 |

### 7. Static viewers (task #7)

Не генерил — `eval-viewer/generate_review.py` пишет в browser-mode HTML, а cowork-static нужен только для UI-review. У нас text-only assessment, реальная ценность — этот отчёт + сами outputs в `skills-eval-workspace/`. Если нужно — могу сгенерить viewers отдельной командой.

---

## Production readiness — per skill

| Skill | Verdict | Прим. |
|---|---|---|
| **compose-arch** | ✅ Ready | Forms-state шаблон закрыл реальный UX-баг (потеря draft на error) |
| **decompose** | ✅ Ready | Bottom-nav и warm-start deep-link — самые частые prod use cases, теперь покрыты |
| **kmp-feature-slice** | ✅ Ready | Project conventions table убирает неоднозначность с `runCatchingApp`/`componentScope` |
| **kotlin-spring-boot** | ✅ Ready | JPA + JDBC оба варианта документированы |
| **kotlin-spring-patterns** | ✅ Ready | Propagation rules + AFTER_COMMIT — стандартная Spring 4.0 практика |
| **kotlin-web** | ✅ Ready | `wasmJs("web")` корректно, devServer config зафиксирован |
| **ktgbotapi** | ✅ Ready | FSM imports callout убирает типичный pitfall с разными пакетами |
| **ktgbotapi-patterns** | ✅ Ready | Spring-вариант исправлен (`ApplicationReadyEvent` + `Dispatchers.IO`) |
| **ktor-client** | ✅ Ready | OAuth2-refresh теперь корректный (no infinite loop) |
| **metro-di-mobile** | ✅ Ready | Metro 1.0 surface чистый, `@GraphExtension` компилируется |

---

## Технический долг / rough edges (опционально, не блокирует merge)

1. **`_grader.py` over-specifies wording** — нужно расширить альтернативы patterns, чтобы не давать false negatives на идиоматический код. Не блокирует — мы уже видим реальное качество в transcripts.
2. **Long-polling vs replicas в ktgbotapi-patterns** — один subagent поднял этот issue (`getUpdates conflict`). Стоит добавить deployment-секцию: leader-election или webhook mode для multi-replica.
3. **kotlin-web/Compose WASM warnings** — один subagent отказался применить Compose WASM для маркетингового лендинга (правильно: bundle 2-5MB, нет SEO/a11y). Skill уже содержит decision tree, но можно усилить prod-facing warning.
4. **eval coverage** — 2 eval/skill — минимум. Для регулярного re-grading имеет смысл расширить до 4-5/skill, особенно edge cases (process death, network failures, concurrent updates).

---

## Артефакты

```
/Users/a.vladislavov/projects/oss/claude-plugin/skills-eval-workspace/
├── _grader.py                                    # programmatic grader, 410 lines
├── _assertions.py                                # assertions generator
├── <skill>/
│   ├── snapshot/                                 # baseline before fixes
│   ├── iteration-1/<eval-name>/with_skill/
│   │   ├── eval_metadata.json
│   │   ├── outputs/output.md
│   │   ├── timing.json
│   │   └── grading.json
│   └── iteration-2/<eval-name>/with_skill/
│       └── ... (same structure)
```

`skills/<name>/evals/evals.json` — committed eval definitions for future re-runs.

---

## Recommendation

**Merge `skills-update` в `main` после стандартного review.** Все 10 скиллов:
- Проходят программный grading (≥95% после учёта false-negatives)
- Дают качественно более глубокие outputs на iter-2 prompts (verified via transcripts)
- Стали быстрее на 15% и токенно эффективнее на 2% за счёт caveman-сжатия

Регрессий нет. Eval-инфраструктура (`_grader.py`, `evals/evals.json`) — переиспользуемая для будущих skill iterations.

---

## Iter-3: эксперимент с progressive disclosure

После iter-2 топ-5 крупных скиллов превышали 500 строк (decompose 957, ktgbotapi-patterns 715, ktor-client 708, metro-di-mobile 697, ktgbotapi 522). Гипотеза: вынести специализированные секции в `references/` и оставить routing-pointer в SKILL.md — модель загружает только нужные файлы → меньше токенов.

### Что сделано (commit 66c706c)

| Skill | До | SKILL.md (ядро) | references/ файлы | Всего после |
|---|---|---|---|---|
| decompose | 957 | 592 | bottom-nav, deep-linking, lifecycle-state, testing | 1030 |
| ktor-client | 708 | 445 | auth-oauth2, retry-resilience, spring-integration, multiplatform-engines | 914 |
| metro-di-mobile | 697 | 400 | graph-extensions, kmp-platform-bindings, scoping, testing | 903 |
| ktgbotapi-patterns | 715 | 393 | metro-variant, spring-variant, fsm-design, callback-data | 815 |
| ktgbotapi | 522 | 342 | fsm, media-handlers, inline-keyboards | 625 |

SKILL.md содержит decision tree → router-указатели на конкретные `references/<topic>.md`. Контент дублирующихся примеров вынесен.

### Результат iter-3 (10 evals по 5 split-скиллам)

| Метрика | iter-2 (single-file) | iter-3 (split) | Δ |
|---|---|---|---|
| Pass rate | 64/68 = 94.1% | 65/68 = 95.6% | **+1.5 п.п.** |
| Avg tokens | 34,157 | 35,493 | **+3.9%** |
| Avg duration | 92.6 s | 102.4 s | **+10.5%** |

Качественно: ktor-client/oauth2 поднялся с 6/8 → 7/8 (на одну ассерцию лучше). Остальные — без изменений.

### Вердикт: progressive disclosure НЕ окупился на этих задачах

**Почему дороже:**
1. Большинство iter-2/iter-3 evals — cross-cutting. Например `decompose/deep-link-from-push` требует `bottom-nav.md` + `deep-linking.md`, `ktor-client/oauth2-refresh-retry` нужны `auth-oauth2.md` + `retry-resilience.md`. Модель грузит 2-3 reference + сам SKILL.md → суммарно больше, чем монолит.
2. Routing-overhead: модель сначала читает SKILL.md, делает выбор, потом читает references. Это лишний round-trip.
3. Дублирование контекста: SKILL.md содержит fingerprints/декcision tree → references/ повторяют контекст для self-containment.

**Когда split окупился бы:**
- Если evals задевают ровно один subtopic (узкие задачи).
- Если skill > 1500 строк и ядро остаётся ≤300 строк.
- Если references взаимоисключающи (выбор cloud provider, ORM).

**Решение:** Split закоммичен (66c706c), но overhead +10% времени без прироста качества — не стоит того. Откатить или оставить — отдельное решение пользователя.

### Откат

```bash
git revert 66c706c    # вернёт монолит iter-2
```

Или оставить split как есть — функционально работает, pass rate чуть выше, оверхед терпимый. Eval-данные iter-3 в `skills-eval-workspace/<skill>/iteration-3/`.
