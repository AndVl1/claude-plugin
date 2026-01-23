---
name: metro-di-mobile
description: Metro DI for KMP - use for compile-time dependency injection, graphs, providers, and multi-module DI setup
---

# Metro DI for Kotlin Multiplatform

Compile-time dependency injection framework for KMP. Production-proven at Cash App.

## Setup

### build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.metro)
}

// Apply Metro plugin to modules that need DI
```

### libs.versions.toml

```toml
[versions]
metro = "0.1.1"

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

For dependencies that need runtime parameters.

```kotlin
// Component that needs runtime parameters
@Inject
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

## Decompose Integration

### Component with DI

```kotlin
// feature/home/impl/src/commonMain/kotlin/HomeComponent.kt
interface HomeComponent {
    val state: Value<HomeState>
    fun onItemClick(item: HomeItem)
}

@Inject
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

@Inject
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
- Use `@Assisted` for runtime parameters (ComponentContext, IDs)
- Prefer constructor injection (`@Inject`) over `@Provides`
- Keep binding containers in the same module as implementations
- Use `Lazy<T>` for expensive dependencies

### Don'ts
- Don't create multiple graphs for the same platform
- Don't put platform-specific code in common binding containers
- Don't use `@Provides` when `@Inject` on class is sufficient
- Don't expose implementation types from graphs (use interfaces)
- Don't put Android Context in common modules

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
