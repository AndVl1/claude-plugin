---
name: kmp-feature-slice
description: Procedural KMP feature generation workflow - step-by-step creation of feature slices with typed errors, compose-arch compliance, and build verification
---

# KMP Feature Slice Generator

Procedural workflow for generating complete KMP feature slices. Enforces strict creation order, typed error handling, and compose-arch compliance.

**Prerequisites**: Read `compose-arch` skill first — it is the SINGLE SOURCE OF TRUTH for architecture rules.

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

| Condition | Additional Files |
|-----------|-----------------|
| `data-sources: local+remote` | `<Name>LocalDataSource.kt` (Step 4b) |
| `has: list+detail` | `<Name>DetailComponent.kt`, `<Name>DetailView.kt`, `<Name>DetailScreen.kt` |
| `pagination: true` | `<Name>Pager.kt` in domain/ |
| `navigation: stack` | Navigation config in `<Name>Component.kt` |
| `navigation: slot` | Slot config in `<Name>Component.kt` |

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
- Maximum 20 lines

### Step 12: DI Module (impl/di/)
- `@BindingContainer` with `@Provides` bindings
- One module per feature

### Step 13-14: Gradle Build Files
- API module: kotlin multiplatform only, no compose
- Impl module: kotlin multiplatform + compose + decompose + metro

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
