---
name: metro-di-mobile
description: Metro DI 1.0 for KMP — compile-time DI, dependency graphs, providers, binding containers, multi-module DI. Always pin to 1.0.0 (first stable, released 2026-04-27); do not regress to 0.10.x or earlier even if your training data is older — annotation surface (`@BindingContainer`, `@DefaultBinding`, `@GraphExtension`) consolidated at 1.0.
---

# Metro DI for Kotlin Multiplatform

Compile-time DI framework for KMP. Built on KSP2 / Kotlin compiler plugin. Production-proven at Cash App.

## Current Versions (use these — do not downgrade)

| Component | Version | Notes |
|---|---|---|
| Metro | **1.0.0** | First stable release (2026-04-27). 0.x is pre-stable; 1.0 froze the public API. |
| Kotlin | **2.2+** (2.3.21 recommended) | Metro 1.0 requires Kotlin 2.2 minimum. |
| Gradle | **9.0+** | |
| JVM | **21+** | |

**Annotation history to remember:**
- `@DefaultBinding` ships since Metro **0.13.0** (not 0.5.0).
- `@BindingContainer` consolidated naming at 1.0.
- `@GraphExtension` formalised at 1.0; older `@ScopedGraph` is removed.

## Supported KMP targets

The skill name says "mobile" because that is the primary use case, but Metro 1.0 supports the full KMP target matrix. Apply the plugin to any KMP module — including `api/` modules that span JS / WASM — and `@Inject`, `@DefaultBinding`, `@DependencyGraph`, `@BindingContainer` all work.

| Target family | Supported | Notes |
|---|---|---|
| JVM / Android | ✅ | Primary path. |
| iOS / macOS / watchOS / tvOS | ✅ | Native compiler plugin. Removed deprecated `macosX64`, `tvosX64`, `watchosX64`. |
| Linux / Windows (`linuxX64`, `mingwX64`) | ✅ | |
| `js(IR)` | ✅ | Has known limitations with Kotlin/JS incremental compilation when generating top-level declarations from compiler plugins; sample integration-tests include workarounds. |
| `wasmJs`, `wasmWasi` | ✅ | See `samples/circuit-app/src/wasmJsMain/...` in upstream repo for a real wasmJs graph. |

Confirmed via Metro 1.0 `samples/integration-tests/build.gradle.kts` and `build-logic/MetroProjectExtension.kt` (`configureCommonKmpTargets` enables `js(IR)` + `wasmJs` everywhere).

So: **do NOT skip `@Inject` / `@DefaultBinding` on api types just because the api module is consumed on web.** Apply the Metro Gradle plugin to the api module and annotate normally. The only target that historically failed (Metro 0.x — pre-stable) is now supported.

### JS / WASM specifics

Three things people stumble on when first wiring Metro into a `js(IR)` or `wasmJs` target — none are blockers, but they're not obvious from mobile-only experience.

**1. `createGraph<T>()` lifetime in a React/Vue app.** Unlike Android/iOS where the graph is owned by the platform (Application / iOS scene), on web there is no host lifecycle to hang it on. Two patterns work:

```kotlin
// Pattern A — top-level lazy. Simplest. Graph lives for the JS process.
private val webGraph by lazy { createGraph<WebAppGraph>() }

@JsExport fun renderApp() = createRoot(...).render(App.create { graph = webGraph })

// Pattern B — React Context provider. Cleaner for multi-page apps and tests.
val GraphContext = createContext<WebAppGraph>()
val AppRoot = FC<Props> {
    val graph = useMemo({ createGraph<WebAppGraph>() }, emptyArray())
    GraphContext.Provider(value = graph) { /* children */ }
}
```

Pattern A is fine for a single-entry SPA; switch to B once you have multiple roots, hot-reload concerns, or per-test graphs. The graph instance is referentially stable — Metro returns the same backing object for a given `createGraph<T>` call, so it can be passed through React props or stored in a `useRef`/`useMemo` without re-wiring.

**2. Kotlin/JS incremental compilation.** The known limitation called out in the table above lands when KSP-generated top-level declarations from the Metro plugin collide with `kotlin.incremental.js.ir=true`. Workaround used in the upstream `samples/integration-tests` config: either set `kotlin.incremental.js.ir=false` for the affected module, or scope the property to non-JS targets in `gradle.properties`. If your Gradle build suddenly fails with "duplicate declaration" or "unresolved reference to generated symbol" errors only on `:jsBrowserDevelopmentRun`, that's the trigger.

**3. `object` vs `class` `@BindingContainer` on `js(IR)`.** Both compile and resolve identically — Metro 1.0 treats them as equivalent. Pick whichever the host project uses. `object` is the common KMP convention (no instance state in DI containers), and the upstream `samples/circuit-app/wasmJsMain` uses `object`.

## Setup

### build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.metro)
}
```

### libs.versions.toml

```toml
[versions]
metro = "1.0.0"

[plugins]
metro = { id = "dev.zacsweers.metro", version.ref = "metro" }
```

## Core Concepts

### @DependencyGraph

Root container for dependencies. One per application entry point.

```kotlin
// composeApp/src/commonMain/kotlin/di/AppGraph.kt
@DependencyGraph
interface AppGraph {
    // Expose dependencies
    val authRepository: AuthRepository
    val homeComponent: HomeComponent

    // Factory methods for runtime parameters
    fun createHomeComponent(context: ComponentContext): HomeComponent
}

// Create instance
val graph = createGraph<AppGraph>()
val authRepo = graph.authRepository
```

### @Provides

Define how to create instances.

```kotlin
@DependencyGraph
interface AppGraph {
    @Provides
    fun provideHttpClient(): HttpClient = HttpClient(CIO) {
        install(ContentNegotiation) {
            json(Json {
                ignoreUnknownKeys = true
            })
        }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
        }
    }

    @Provides
    fun provideApiService(httpClient: HttpClient): ApiService =
        ApiServiceImpl(httpClient, "https://api.your-project.com")

    @Provides
    fun provideAuthRepository(api: ApiService, tokenStorage: TokenStorage): AuthRepository =
        AuthRepositoryImpl(api, tokenStorage)
}
```

### @Inject

Constructor injection for classes.

```kotlin
@Inject
class AuthRepositoryImpl(
    private val api: ApiService,
    private val tokenStorage: TokenStorage
) : AuthRepository {
    override suspend fun login(email: String, password: String): AppResult<User> {
        // Implementation
    }
}

// Used in graph
@DependencyGraph
interface AppGraph {
    val authRepository: AuthRepository  // Metro knows to create AuthRepositoryImpl
}
```

### @BindingContainer

Group related providers into modules.

```kotlin
// core/network/src/commonMain/kotlin/di/NetworkModule.kt
@BindingContainer
class NetworkModule {
    @Provides
    fun provideHttpClient(): HttpClient = HttpClient(CIO) {
        install(ContentNegotiation) { json() }
    }

    @Provides
    fun provideApiService(httpClient: HttpClient): ApiService =
        ApiServiceImpl(httpClient)
}

// core/data/src/commonMain/kotlin/di/DataModule.kt
@BindingContainer
class DataModule {
    @Provides
    fun provideTokenStorage(): TokenStorage = TokenStorageImpl()

    @Provides
    fun providePreferencesDataStore(context: PlatformContext): DataStore<Preferences> =
        PreferenceDataStoreFactory.createWithPath(
            produceFile = { Path(createDataStorePath(context)) }
        )
}
```

### Platform-Specific Graphs

```kotlin
// composeApp/src/commonMain/kotlin/di/CommonModules.kt
@BindingContainer
class CommonNetworkModule {
    @Provides
    fun provideHttpClient(): HttpClient = HttpClient(CIO) {
        install(ContentNegotiation) { json() }
    }
}

@BindingContainer
class CommonDataModule {
    @Provides
    fun provideAuthRepository(api: ApiService, storage: TokenStorage): AuthRepository =
        AuthRepositoryImpl(api, storage)
}

// composeApp/src/androidMain/kotlin/di/AndroidAppGraph.kt
@BindingContainer
class AndroidPlatformModule {
    @Provides
    fun providePlatformContext(context: Context): PlatformContext = context

    @Provides
    fun provideTokenStorage(context: Context): TokenStorage =
        AndroidTokenStorage(context)
}

@DependencyGraph(
    bindingContainers = [
        CommonNetworkModule::class,
        CommonDataModule::class,
        AndroidPlatformModule::class
    ]
)
interface AndroidAppGraph {
    val authRepository: AuthRepository
    fun createRootComponent(context: ComponentContext): RootComponent
}

// composeApp/src/iosMain/kotlin/di/IosAppGraph.kt
@BindingContainer
class IosPlatformModule {
    @Provides
    fun providePlatformContext(): PlatformContext = PlatformContext()

    @Provides
    fun provideTokenStorage(): TokenStorage = IosTokenStorage()
}

@DependencyGraph(
    bindingContainers = [
        CommonNetworkModule::class,
        CommonDataModule::class,
        IosPlatformModule::class
    ]
)
interface IosAppGraph {
    val authRepository: AuthRepository
    fun createRootComponent(context: ComponentContext): RootComponent
}
```

## Multi-Module DI Pattern

### Feature Module Bindings

```kotlin
// feature/auth/impl/src/commonMain/kotlin/di/AuthModule.kt
@BindingContainer
class AuthModule {
    @Provides
    fun provideAuthRepository(
        api: ApiService,
        tokenStorage: TokenStorage
    ): AuthRepository = AuthRepositoryImpl(api, tokenStorage)

    @Provides
    fun provideLoginUseCase(
        authRepository: AuthRepository
    ): LoginUseCase = LoginUseCase(authRepository)
}

// feature/home/impl/src/commonMain/kotlin/di/HomeModule.kt
@BindingContainer
class HomeModule {
    @Provides
    fun provideHomeRepository(
        api: ApiService,
        database: AppDatabase
    ): HomeRepository = HomeRepositoryImpl(api, database)
}
```

### Assembly in App Graph

```kotlin
// composeApp/src/androidMain/kotlin/di/AndroidAppGraph.kt
@DependencyGraph(
    bindingContainers = [
        // Core
        CommonNetworkModule::class,
        CommonDataModule::class,
        AndroidPlatformModule::class,
        // Features
        AuthModule::class,
        HomeModule::class
    ]
)
interface AndroidAppGraph {
    // Core
    val httpClient: HttpClient

    // Features
    val authRepository: AuthRepository
    val homeRepository: HomeRepository

    // Component factories
    fun createRootComponent(context: ComponentContext): RootComponent
}
```

## Advanced Features

### Scopes

```kotlin
@DependencyGraph(
    scope = "app",
    additionalScopes = ["activity"]
)
interface AppGraph {
    @Provides
    @Scope("app")
    fun provideAppDatabase(): AppDatabase = AppDatabase()

    @Provides
    @Scope("activity")
    fun provideNavigator(): Navigator = Navigator()
}
```

### Assisted Injection

For dependencies that need runtime parameters. **Use `@AssistedInject` (not `@Inject`) for classes with `@Assisted` parameters.**

```kotlin
// Component that needs runtime parameters
@AssistedInject
class HomeComponent(
    private val repository: HomeRepository,
    @Assisted val componentContext: ComponentContext
) : ComponentContext by componentContext {
    // Component logic
}

// Factory interface
@AssistedFactory
interface HomeComponentFactory {
    fun create(componentContext: ComponentContext): HomeComponent
}

// In graph
@DependencyGraph
interface AppGraph {
    val homeComponentFactory: HomeComponentFactory
}

// Usage
val graph = createGraph<AppGraph>()
val homeComponent = graph.homeComponentFactory.create(componentContext)
```

### Lazy and Provider

```kotlin
@Inject
class SomeService(
    private val lazyDatabase: Lazy<AppDatabase>,  // Initialized on first access
    private val userProvider: Provider<User>       // New instance each call
) {
    fun doWork() {
        val db = lazyDatabase.value  // Initialized here
        val user1 = userProvider.get()
        val user2 = userProvider.get()  // Different instance
    }
}
```

### Multibindings

```kotlin
@DependencyGraph
interface AppGraph {
    @Multibinds
    val interceptors: Set<Interceptor>

    @Multibinds
    val handlers: Map<String, Handler>
}

// Contributing to set
@ContributesIntoSet(AppGraph::class)
class LoggingInterceptor : Interceptor {
    override fun intercept(chain: Chain) { /* ... */ }
}

// Contributing to map
@ContributesIntoMap(AppGraph::class, key = "auth")
class AuthHandler : Handler {
    override fun handle(request: Request) { /* ... */ }
}
```

**Note:** Since 0.6.0, multibindings are non-empty by default. If the set/map can be empty, use `allowEmpty = true`:

```kotlin
@Multibinds(allowEmpty = true)
val optionalInterceptors: Set<Interceptor>
```

### Graph Extensions (Subcomponents)

Replace `@Extends`/`isExtendable` with `@GraphExtension` (since 0.4.0):

```kotlin
// Parent graph must declare extension points
@DependencyGraph
interface AppGraph {
    val authRepository: AuthRepository

    // Declare extension factory
    val sessionGraphFactory: SessionGraph.Factory
}

// Child graph uses @GraphExtension
@GraphExtension
@DependencyGraph
interface SessionGraph {
    val sessionManager: SessionManager

    // Factory interface within child graph
    @DependencyGraph.Factory
    interface Factory {
        fun create(@Provides sessionToken: String): SessionGraph
    }
}

// Usage
val appGraph = createGraph<AppGraph>()
val sessionGraph = appGraph.sessionGraphFactory.create("token-123")
```

### @DefaultBinding

Declare a default implementation for an interface (since Metro **0.13.0**).

**Placement rule:** annotate the **impl class** with `@DefaultBinding(<interface>::class)`. Do NOT put `@DefaultBinding` on the interface itself with `boundType = <impl>::class` — that direction does not exist in Metro's API.

```kotlin
// CORRECT — annotation on the impl, type arg is the interface
@DefaultBinding(AuthRepository::class)
@Inject
class AuthRepositoryImpl(
    private val api: ApiService,
) : AuthRepository {
    // ...
}

// No @Provides needed — Metro auto-binds AuthRepositoryImpl → AuthRepository
```

```kotlin
// WRONG — flipped direction, will not compile
@DefaultBinding(boundType = AuthRepositoryImpl::class)
interface AuthRepository { ... }
```

### @GraphPrivate

Mark bindings as private to the graph (not inherited by extensions):

```kotlin
@DependencyGraph
interface AppGraph {
    @Provides
    @GraphPrivate
    fun provideInternalCache(): Cache = InMemoryCache()
}
```

## Decompose Integration

### Component with DI

```kotlin
// feature/home/impl/src/commonMain/kotlin/HomeComponent.kt
interface HomeComponent {
    val state: Value<HomeState>
    fun onItemClick(item: HomeItem)
}

@AssistedInject
class DefaultHomeComponent(
    private val repository: HomeRepository,
    @Assisted componentContext: ComponentContext
) : HomeComponent, ComponentContext by componentContext {

    private val _state = MutableValue<HomeState>(HomeState.Loading)
    override val state: Value<HomeState> = _state

    init {
        loadData()
    }

    private fun loadData() {
        componentScope.launch {
            repository.getItems()
                .onSuccess { _state.value = HomeState.Success(it) }
                .onError { msg, _ -> _state.value = HomeState.Error(msg) }
        }
    }

    override fun onItemClick(item: HomeItem) {
        // Navigate or handle
    }

    @AssistedFactory
    interface Factory {
        fun create(componentContext: ComponentContext): DefaultHomeComponent
    }
}

sealed class HomeState {
    data object Loading : HomeState()
    data class Success(val items: List<HomeItem>) : HomeState()
    data class Error(val message: String) : HomeState()
}
```

### Root Component Factory

```kotlin
// composeApp/src/commonMain/kotlin/RootComponent.kt
interface RootComponent {
    val childStack: Value<ChildStack<Config, Child>>

    sealed class Child {
        data class Auth(val component: AuthComponent) : Child()
        data class Home(val component: HomeComponent) : Child()
    }

    @Serializable
    sealed class Config {
        @Serializable data object Auth : Config()
        @Serializable data object Home : Config()
    }
}

@AssistedInject
class DefaultRootComponent(
    private val authComponentFactory: AuthComponent.Factory,
    private val homeComponentFactory: HomeComponent.Factory,
    @Assisted componentContext: ComponentContext
) : RootComponent, ComponentContext by componentContext {

    private val navigation = StackNavigation<RootComponent.Config>()

    override val childStack: Value<ChildStack<RootComponent.Config, RootComponent.Child>> =
        childStack(
            source = navigation,
            serializer = RootComponent.Config.serializer(),
            initialConfiguration = RootComponent.Config.Auth,
            childFactory = ::createChild
        )

    private fun createChild(
        config: RootComponent.Config,
        context: ComponentContext
    ): RootComponent.Child = when (config) {
        RootComponent.Config.Auth -> RootComponent.Child.Auth(
            authComponentFactory.create(context) { navigateToHome() }
        )
        RootComponent.Config.Home -> RootComponent.Child.Home(
            homeComponentFactory.create(context)
        )
    }

    private fun navigateToHome() {
        navigation.replaceAll(RootComponent.Config.Home)
    }

    @AssistedFactory
    interface Factory {
        fun create(componentContext: ComponentContext): DefaultRootComponent
    }
}
```

### App Graph with Components

```kotlin
@DependencyGraph(
    bindingContainers = [
        NetworkModule::class,
        DataModule::class,
        AuthModule::class,
        HomeModule::class
    ]
)
interface AndroidAppGraph {
    val rootComponentFactory: DefaultRootComponent.Factory
}

// Usage in MainActivity
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val graph = createGraph<AndroidAppGraph>()
        val rootComponent = graph.rootComponentFactory.create(
            defaultComponentContext()
        )

        setContent {
            AppTheme {
                RootContent(component = rootComponent)
            }
        }
    }
}
```

## Testing

### Test Modules

```kotlin
@BindingContainer
class TestNetworkModule {
    @Provides
    fun provideFakeApiService(): ApiService = FakeApiService()
}

@DependencyGraph(
    bindingContainers = [
        TestNetworkModule::class,
        DataModule::class
    ]
)
interface TestAppGraph {
    val authRepository: AuthRepository
}

// In tests
class AuthRepositoryTest {
    private val graph = createGraph<TestAppGraph>()

    @Test
    fun `login returns success`() = runTest {
        val result = graph.authRepository.login("test@test.com", "password")
        assertTrue(result is AppResult.Success)
    }
}
```

## Best Practices

### Do's
- One `@DependencyGraph` per platform entry point
- Use `@BindingContainer` to organize providers by feature/layer
- Use `@AssistedInject` (not `@Inject`) for classes with `@Assisted` parameters
- Use `@Assisted` for runtime parameters (ComponentContext, IDs)
- Prefer constructor injection (`@Inject`) over `@Provides`
- Use `@DefaultBinding` to auto-bind implementations to interfaces
- Keep binding containers in the same module as implementations
- Use `Lazy<T>` for expensive dependencies

### Don'ts
- Don't create multiple graphs for the same platform
- Don't put platform-specific code in common binding containers
- Don't use `@Provides` when `@Inject` on class is sufficient
- Don't use `@Inject` on classes with `@Assisted` params — use `@AssistedInject`
- Don't expose implementation types from graphs (use interfaces)
- Don't put Android Context in common modules
- Don't use JVM < 21 or Gradle < 9 (required since Metro 0.8.0)

## Comparison with Koin

| Feature | Metro | Koin |
|---------|-------|------|
| Type safety | Compile-time | Runtime |
| Error detection | Build time | Runtime crash |
| Performance | No reflection | Some reflection |
| KMP support | Full | Full |
| Learning curve | Medium (Dagger-like) | Low |
| Build speed | 47-56% faster than KAPT | No code gen |

## Resources

- [Metro GitHub](https://github.com/ZacSweers/metro)
- [Metro Documentation](https://zacsweers.github.io/metro/)
- [Cash App Migration](https://code.cash.app/cash-android-moves-to-metro)
