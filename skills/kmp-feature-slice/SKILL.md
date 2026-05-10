---
name: kmp-feature-slice
description: Procedural KMP feature generation workflow — step-by-step creation of feature slices with typed errors, compose-arch compliance, and build verification. Use when scaffolding a new feature module in a KMP/Compose Multiplatform project.
---

# KMP Feature Slice Generator

Procedural workflow for generating complete KMP feature slices. Enforces strict creation order, typed error handling, and compose-arch compliance.

**Prerequisites**: Read `compose-arch` skill first — it is the SINGLE SOURCE OF TRUTH for architecture rules.

## Companion skills (versions live there — do not duplicate)

- Architecture rules + Component/View/Screen split — `compose-arch`.
- DI annotations (`@BindingContainer`, `@Provides`, `@AssistedInject`) — `metro-di-mobile` (Metro 1.0.0).
- Navigation primitives (`Value<T>`, `ChildStack`) — `decompose`.
- HTTP — `ktor-client` (3.4.3).

When generating a slice, **always read these companion skills first** for current versions and idioms; never inline a version here.

## Phase 1: Input Collection (LOW FREEDOM)

Collect these inputs before generating any code:

| Input | Required | Example |
|-------|----------|---------|
| **Feature name** | Yes | `OrderHistory` |
| **Data sources** | Yes | `remote-only`, `local+remote`, `local-only` |
| **Target platforms** | Yes | `android,ios,desktop`, `android,ios,desktop,wasm`, `all` |
| **Error types** | Yes | `network,validation`, `network,auth,conflict` |
| **Has list/detail?** | Yes | `list-only`, `detail-only`, `list+detail` |
| **Navigation** | Yes | `stack` (full screen), `slot` (dialog/modal), `none` |
| **Needs pagination?** | No | `true/false` (default: false) |
| **Parent module path** | Yes | `feature/order-history` |

### Error Type Catalog

Select from these typed error categories (see `references/error-patterns.md` for sealed class templates):

| Error Type | When to Use |
|------------|-------------|
| `network` | API calls, timeouts, connectivity |
| `validation` | User input, form data |
| `auth` | Token expired, unauthorized |
| `conflict` | Concurrent modification, duplicate |
| `not-found` | Missing resource |
| `storage` | Database, file system errors |
| `permission` | OS-level permissions (camera, location) |

## Phase 2: File Manifest (ZERO FREEDOM)

Based on inputs, generate the exact file list. Every feature slice follows this structure:

### Mandatory Files (always created)

```
feature/<name>/
├── api/
│   └── src/commonMain/kotlin/
│       ├── <Name>Component.kt          # Step 1: Interface
│       ├── <Name>Models.kt             # Step 2: Domain models + error types
│       └── <Name>Repository.kt         # Step 3: Repository interface (if data sources != none)
│
└── impl/
    └── src/commonMain/kotlin/
        ├── component/
        │   └── Default<Name>Component.kt   # Step 7: Component implementation
        ├── domain/
        │   ├── usecase/
        │   │   └── Get<Name>UseCase.kt     # Step 5: Primary use case
        │   └── repository/
        │       └── <Name>RepositoryImpl.kt # Step 6: Repository implementation
        ├── data/
        │   └── datasource/
        │       └── <Name>RemoteDataSource.kt  # Step 4: Remote data source
        ├── view/
        │   ├── <Name>ViewState.kt          # Step 8: View state
        │   ├── <Name>ViewEvent.kt          # Step 9: View events
        │   └── <Name>View.kt              # Step 10: View (pure UI)
        ├── screen/
        │   └── <Name>Screen.kt            # Step 11: Screen (thin adapter)
        └── di/
            └── <Name>Module.kt            # Step 12: DI module
```

### Conditional Files

| Condition | Additional Files | Insert at step |
|-----------|-----------------|---------------|
| `data-sources: local+remote` | `<Name>LocalDataSource.kt` | Step 4b — same step as RemoteDataSource |
| `has: list+detail` | **Container** Component (`<Name>Component.kt`) owning `ChildStack<Config, Child>` + **two child Components**: `<Name>ListComponent.kt` and `<Name>DetailComponent.kt` (each with its own `viewState`/`Event`/`View`/`Screen`). Impl side mirrors with `Default<Name>Component`, `Default<Name>ListComponent`, `Default<Name>DetailComponent`. | Container interface at Step 1; child interfaces also at Step 1; container impl at Step 7 (drives `ChildStack`, exposes child factories); child impls at Step 7 (each owns its own state/use cases). View/State/Event/Screen for each child at Steps 8-11. |
| `pagination: true` | `<Name>Pager.kt` in `impl/domain/` | Step 5b — between Repository (Step 5) and Component (Step 7) |
| `navigation: stack` | Navigation config (`Config` sealed class + `ChildStack`) in `<Name>Component.kt` and `Default<Name>Component.kt` | Steps 1 + 7 |
| `navigation: slot` | Slot config in `<Name>Component.kt` and `Default<Name>Component.kt` | Steps 1 + 7 |

> **Component owning navigation alongside state.** A Component can expose BOTH `val viewState: Value<T>` AND `val childStack: Value<ChildStack<Config, Child>>`. They are independent fields.
>
> **List+detail uses the container pattern, not one Component with two states.** The container Component holds *only* the `ChildStack` and child factories — no `viewState` of its own. Each child Component (List, Detail) owns its own `viewState`, events, and use cases. This keeps each child testable in isolation and matches Decompose's `Children { }` rendering. A real example:
>
> ```kotlin
> // Container — navigation only, no viewState
> interface OrderHistoryComponent {
>     val childStack: Value<ChildStack<*, Child>>
>     sealed class Child {
>         data class List(val component: OrderHistoryListComponent) : Child()
>         data class Detail(val component: OrderHistoryDetailComponent) : Child()
>     }
> }
>
> // Each child is a full Component with its own viewState
> interface OrderHistoryListComponent {
>     val viewState: Value<OrderHistoryListViewState>
>     fun obtainEvent(event: OrderHistoryListEvent)
> }
> ```
>
> Avoid the anti-pattern of a single Component carrying `viewState: Value<ListState>` + `detailViewState: Value<DetailState>` + manual show/hide flags — that scales poorly and breaks the one-Component-one-screen mental model.

### Gradle Files

```
feature/<name>/
├── api/
│   └── build.gradle.kts               # Step 13: API module build
└── impl/
    └── build.gradle.kts               # Step 14: Impl module build
```

Update `settings.gradle.kts` — Step 15.

## Phase 3: Generation Order (STRICT SEQUENCE)

Generate files in this exact order. Each step depends on previous steps.

### Step 1: Component Interface (api/)
```kotlin
interface <Name>Component {
    val viewState: Value<<Name>ViewState>
    fun obtainEvent(event: <Name>Event)

    fun interface Factory {
        fun create(
            componentContext: ComponentContext,
            onNavigate: (<NavigationType>) -> Unit  // from navigation input
        ): <Name>Component
    }
}
```

### Step 2: Domain Models + Typed Errors (api/)
- Domain data classes
- Sealed error hierarchy (see `references/error-patterns.md`)
- Keep models serializable if used in navigation configs

### Step 3: Repository Interface (api/)
- Return `AppResult<T>` for all operations
- Define typed error mapping

### Step 4: Data Sources (impl/data/)
- Remote data source with Ktor client
- (Optional) Local data source with Room/DataStore
- Map API DTOs to domain models here

### Step 5: Use Cases (impl/domain/usecase/)
- Single `execute()` function returning `Result<T>`
- All error handling and mapping here
- Reference `error-patterns.md` for typed error creation

### Step 6: Repository Implementation (impl/domain/repository/)
- Coordinate data sources
- Cache strategy (if local+remote)

### Step 7: Component Implementation (impl/component/)
- `@Inject` + `@Assisted` pattern
- `Value<T>` for state (NOT StateFlow)
- `componentScope()` for coroutines
- Event handling via `obtainEvent()`
- Navigation via Decompose callbacks

### Step 8-9: ViewState + ViewEvent (impl/view/)
- Sealed class for ViewState: Loading, Success, Error (+ Empty if list)
- Sealed class for ViewEvent: all user interactions

### Step 10: View (impl/view/)
- Pure UI, only viewState + eventHandler params
- NO remember, NO side effects
- See `references/compose-ui-templates.md` for templates

### Step 11: Screen (impl/screen/)
- Thin adapter: subscribe to component state, pass to View
- Target ~20 lines for a single-view screen. With `list+detail` and an internal `Children { when }` block, ~25–30 lines is acceptable — the rule is "no logic", not a hard line count.

### Step 12: DI Module (impl/di/)
- `@BindingContainer` with `@Provides` bindings — one module per feature.
- For each interface declared in `api/` whose impl lives in `impl/`, prefer `@DefaultBinding(<ApiInterface>::class)` on the impl class over a hand-written `@Provides` — Metro auto-binds and you avoid one boilerplate function per interface.
- Use `@Provides` in the module only when:
  - the binding requires plumbing several deps together (e.g. wrapping a `HttpClient` into a feature-scoped service), OR
  - the binding wires an api-side `Factory` to its impl-side counterpart (e.g. mapping `OrderHistoryComponent.Factory` → `DefaultOrderHistoryComponent.Factory`).
- `object` vs `class` `@BindingContainer`: both work identically in Metro 1.0. Default to `object` (no instance state, matches common KMP convention) unless the host project uses `class`. Canonical example:

```kotlin
@BindingContainer
object OrderHistoryModule {
    // Use cases + repository auto-bind via @Inject / @DefaultBinding — nothing needed here.

    // @Provides only when wiring api Factory ← impl Factory or composing several deps.
    @Provides
    fun provideComponentFactory(
        impl: DefaultOrderHistoryComponent.Factory,
    ): OrderHistoryComponent.Factory = impl
}
```

### Step 13-14: Gradle Build Files
- API module: kotlin multiplatform only, no compose. Apply the Metro plugin if you want use cases to carry `@Inject`.
- Impl module: kotlin multiplatform + compose + decompose + Metro plugin.

#### Cross-target api note

Metro 1.0 supports the full KMP target matrix — including `js(IR)`, `wasmJs`, `wasmWasi`, and all native targets (see `metro-di-mobile` skill's "Supported KMP targets" table). So an `api/` module that targets `android+ios+desktop+js+wasmJs` can still apply the Metro plugin and use `@Inject` on its use cases. Web frontends consuming the api module will compile fine.

The only reason to keep an `api/` module Metro-free is when **the consumer doesn't run Metro at all** — for example, a non-KMP Kotlin/JS app that pulls in only the `api` artifact and wires use cases by hand. In that case:
- Use cases in `api/` stay as plain Kotlin classes (no annotations).
- The `impl/` module provides them via `@Provides` in `<Name>Module.kt` for the mobile path.
- The web target instantiates use cases manually (`GetOrderHistoryUseCase(JsOrderHistoryRepository())`) at the call site.

Default to "Metro everywhere" unless you have a concrete reason to opt out.

#### Consumer-side graph: two-graph wiring

Once the api module carries `@Inject` annotations, each consumer (mobile vs web) defines its own `@DependencyGraph` and reuses the same api use cases. The two graphs differ only in which impl modules they pull in.

**Mobile graph** — pulls the impl module (with Decompose, real DataSources, full Compose UI):

```kotlin
// composeApp/.../di/AndroidAppGraph.kt
@DependencyGraph(
    bindingContainers = [
        NetworkModule::class,
        AndroidPlatformModule::class,
        OrderHistoryModule::class,           // impl-side @BindingContainer
    ]
)
interface AndroidAppGraph {
    val orderHistoryComponentFactory: OrderHistoryComponent.Factory
}
```

**Web graph** — only the api module + a web-specific repo impl. No Decompose, no impl module:

```kotlin
// webApp/.../di/WebAppGraph.kt
@DependencyGraph(
    bindingContainers = [WebPlatformModule::class],
)
interface WebAppGraph {
    val getOrderHistoryPageUseCase: GetOrderHistoryPageUseCase
    val getOrderDetailUseCase: GetOrderDetailUseCase
    val orderHistoryRepository: OrderHistoryRepository
}

// webApp/.../orderhistory/JsOrderHistoryRepository.kt
@Inject
@DefaultBinding(OrderHistoryRepository::class)
class JsOrderHistoryRepository(
    private val httpClient: HttpClient,
) : OrderHistoryRepository {
    override suspend fun getPage(cursor: String?): AppResult<OrderPage> = /* ... */
    override suspend fun getDetail(id: String): AppResult<OrderDetail> = /* ... */
}
```

The use cases (`GetOrderHistoryPageUseCase`, `GetOrderDetailUseCase`) live in api with `@Inject` and resolve from constructor scanning — no `@Provides` needed in the web module. The `@DefaultBinding` on `JsOrderHistoryRepository` plugs the api interface. The web graph deliberately excludes `OrderHistoryModule` (impl side) since it pulls Decompose lifecycle types React doesn't need.

For createGraph lifetime on JS (top-level `lazy` vs React Context provider), see `metro-di-mobile`'s "JS / WASM specifics" section.

### Step 15: Settings Update
- Add both modules to `settings.gradle.kts`
- Add impl dependency to `composeApp/build.gradle.kts`

## Phase 4: Validation Checklist

After generation, verify ALL of these:

- [ ] **compose-arch compliance**: Screen has no logic, View has no remember
- [ ] **Typed errors**: All error types from input are covered in sealed hierarchy
- [ ] **One class per file**: No file contains multiple classes
- [ ] **Value<T> state**: Component uses `Value<T>`, not `StateFlow`
- [ ] **Result<T> returns**: All use cases return `Result<T>`
- [ ] **AppResult<T> in repository**: Repository interface returns `AppResult<T>`
- [ ] **No Compose imports in Component**: Component has zero compose dependencies
- [ ] **Platform targets match input**: Build file targets match requested platforms
- [ ] **DI bindings complete**: All interfaces bound in Module
- [ ] **Navigation wired**: Component factory registered in parent navigation
- [ ] **Build passes**: `./gradlew :<module>:assemble` succeeds

## Phase 5: Build Verification

```bash
# Verify API module compiles
./gradlew :feature:<name>:api:assemble

# Verify impl module compiles
./gradlew :feature:<name>:impl:assemble

# Verify full app compiles with new feature
./gradlew :composeApp:assemble
```

## Reference Files

Load these on demand — do NOT read all upfront:

| Reference | When to Load |
|-----------|-------------|
| `references/error-patterns.md` | Step 2 (domain models + errors) |
| `references/compose-ui-templates.md` | Steps 8-11 (UI layer) |
| `references/kotlin-web-templates.md` | When target includes `wasm` or `js` |

## Integration with Other Skills

| Skill | Relationship |
|-------|-------------|
| `compose-arch` | **SOURCE OF TRUTH** for architecture rules. This skill adds generation order on top. |
| `decompose` | Navigation patterns. Load for Step 7 (component) if complex navigation. |
| `metro-di-mobile` | DI patterns. Load for Step 12 (module). |
| `kmp` | Project structure. Load for Steps 13-15 (gradle). |
| `kotlin-web` | Web-specific patterns. Load when targets include wasm/js. |
