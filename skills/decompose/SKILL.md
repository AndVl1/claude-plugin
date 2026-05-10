---
name: decompose
description: Decompose navigation and components - use for KMP component architecture, navigation, lifecycle, and state management
---

# Decompose for Kotlin Multiplatform

Component-based architecture with lifecycle management and navigation for KMP.

## Setup

### libs.versions.toml

```toml
[versions]
decompose = "3.5.0"
essenty = "2.5.0"

[libraries]
decompose = { module = "com.arkivanov.decompose:decompose", version.ref = "decompose" }
decompose-compose = { module = "com.arkivanov.decompose:extensions-compose", version.ref = "decompose" }
essenty-lifecycle = { module = "com.arkivanov.essenty:lifecycle", version.ref = "essenty" }
```

### build.gradle.kts

```kotlin
commonMain.dependencies {
    implementation(libs.decompose)
    implementation(libs.decompose.compose)
    implementation(libs.essenty.lifecycle)
    implementation(libs.kotlinx.serialization.json)
}
```

## Core Concepts

### Component

Business logic container with lifecycle. UI-agnostic.

```kotlin
// Interface (public API)
interface HomeComponent {
    val state: Value<HomeState>
    fun onItemClick(item: HomeItem)
    fun onRefresh()
}

// Implementation
class DefaultHomeComponent(
    componentContext: ComponentContext,
    private val repository: HomeRepository,
    private val onNavigateToDetails: (itemId: String) -> Unit
) : HomeComponent, ComponentContext by componentContext {

    private val _state = MutableValue<HomeState>(HomeState.Loading)
    override val state: Value<HomeState> = _state

    private val scope = componentScope()

    init {
        loadData()
    }

    private fun loadData() {
        scope.launch {
            _state.value = HomeState.Loading
            repository.getItems()
                .onSuccess { items ->
                    _state.value = HomeState.Success(items)
                }
                .onError { message, _ ->
                    _state.value = HomeState.Error(message)
                }
        }
    }

    override fun onItemClick(item: HomeItem) {
        onNavigateToDetails(item.id)
    }

    override fun onRefresh() {
        loadData()
    }
}

sealed class HomeState {
    data object Loading : HomeState()
    data class Success(val items: List<HomeItem>) : HomeState()
    data class Error(val message: String) : HomeState()
}
```

### ComponentContext

Provides lifecycle, state preservation, and child management.

```kotlin
class MyComponent(
    componentContext: ComponentContext
) : ComponentContext by componentContext {

    // Access lifecycle
    init {
        lifecycle.subscribe(
            onCreate = { println("Created") },
            onStart = { println("Started") },
            onResume = { println("Resumed") },
            onPause = { println("Paused") },
            onStop = { println("Stopped") },
            onDestroy = { println("Destroyed") }
        )
    }

    // Retain instances across config changes (Android)
    private val viewModel = instanceKeeper.getOrCreate { MyViewModel() }

    // Preserve state during process death
    private var counter: Int by savedState("counter", 0)

    // Create coroutine scope tied to lifecycle
    private val scope = componentScope()
}

// Helper extension — place wherever your project keeps shared lifecycle utils.
// If you have a `core/` or `shared/core/` module, put it there so every feature can
// reuse it. If not, paste this snippet into your feature's impl module
// (e.g. `feature/<name>/impl/.../component/ComponentScope.kt`) — it has no Decompose-
// specific deps beyond `essenty`, so duplication is cheap.
import com.arkivanov.essenty.lifecycle.doOnDestroy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

fun ComponentContext.componentScope(): CoroutineScope {
    val scope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())
    lifecycle.doOnDestroy { scope.cancel() }
    return scope
}
```

## Navigation

### Child Stack (Primary Navigation)

Stack-based navigation like a navigation controller.

```kotlin
interface RootComponent {
    val childStack: Value<ChildStack<Config, Child>>

    sealed class Child {
        data class Home(val component: HomeComponent) : Child()
        data class Details(val component: DetailsComponent) : Child()
        data class Settings(val component: SettingsComponent) : Child()
    }

    @Serializable
    sealed class Config {
        @Serializable data object Home : Config()
        @Serializable data class Details(val itemId: String) : Config()
        @Serializable data object Settings : Config()
    }
}

class DefaultRootComponent(
    componentContext: ComponentContext,
    private val homeComponentFactory: HomeComponent.Factory,
    private val detailsComponentFactory: DetailsComponent.Factory,
    private val settingsComponentFactory: SettingsComponent.Factory
) : RootComponent, ComponentContext by componentContext {

    private val navigation = StackNavigation<RootComponent.Config>()

    override val childStack: Value<ChildStack<RootComponent.Config, RootComponent.Child>> =
        childStack(
            source = navigation,
            serializer = RootComponent.Config.serializer(),
            initialConfiguration = RootComponent.Config.Home,
            handleBackButton = true,  // Auto handle back
            childFactory = ::createChild
        )

    private fun createChild(
        config: RootComponent.Config,
        context: ComponentContext
    ): RootComponent.Child = when (config) {
        RootComponent.Config.Home -> RootComponent.Child.Home(
            homeComponentFactory.create(
                componentContext = context,
                onNavigateToDetails = { itemId ->
                    navigation.push(RootComponent.Config.Details(itemId))
                }
            )
        )
        is RootComponent.Config.Details -> RootComponent.Child.Details(
            detailsComponentFactory.create(
                componentContext = context,
                itemId = config.itemId,
                onBack = { navigation.pop() }
            )
        )
        RootComponent.Config.Settings -> RootComponent.Child.Settings(
            settingsComponentFactory.create(context)
        )
    }

    // Public navigation methods
    fun navigateToSettings() {
        navigation.push(RootComponent.Config.Settings)
    }
}
```

### Child Slot (Modals/Dialogs)

Single optional active child.

```kotlin
interface HomeComponent {
    val dialogSlot: Value<ChildSlot<DialogConfig, DialogChild>>
    fun showConfirmDialog(itemId: String)
    fun dismissDialog()
}

@Serializable
sealed class DialogConfig {
    @Serializable data class Confirm(val itemId: String) : DialogConfig()
    @Serializable data class Edit(val item: HomeItem) : DialogConfig()
}

sealed class DialogChild {
    data class Confirm(val component: ConfirmDialogComponent) : DialogChild()
    data class Edit(val component: EditDialogComponent) : DialogChild()
}

class DefaultHomeComponent(
    componentContext: ComponentContext
) : HomeComponent, ComponentContext by componentContext {

    private val dialogNavigation = SlotNavigation<DialogConfig>()

    override val dialogSlot: Value<ChildSlot<DialogConfig, DialogChild>> =
        childSlot(
            source = dialogNavigation,
            serializer = DialogConfig.serializer(),
            childFactory = ::createDialog
        )

    private fun createDialog(
        config: DialogConfig,
        context: ComponentContext
    ): DialogChild = when (config) {
        is DialogConfig.Confirm -> DialogChild.Confirm(
            ConfirmDialogComponent(
                context = context,
                itemId = config.itemId,
                onConfirm = { deleteItem(config.itemId); dismissDialog() },
                onDismiss = ::dismissDialog
            )
        )
        is DialogConfig.Edit -> DialogChild.Edit(
            EditDialogComponent(context, config.item)
        )
    }

    override fun showConfirmDialog(itemId: String) {
        dialogNavigation.activate(DialogConfig.Confirm(itemId))
    }

    override fun dismissDialog() {
        dialogNavigation.dismiss()
    }
}
```

### Navigation Operations

```kotlin
// Stack operations
navigation.push(Config.Details(itemId))           // Add to stack
navigation.pop()                                   // Go back
navigation.pop { config -> config is Config.Home } // Pop to specific
navigation.replaceAll(Config.Home)                 // Clear and replace
navigation.replaceCurrent(Config.Other)            // Replace top
navigation.navigate { stack -> stack + Config.X }  // Atomic rebuild (single recomposition)

// Slot operations
dialogNavigation.activate(DialogConfig.Confirm(id)) // Show
dialogNavigation.dismiss()                          // Hide
```

`navigate { ... }` rebuilds whole stack atomically — use for deep links or any multi-step transition where intermediate states must not flicker through UI.

### Multiple coexisting stacks (bottom navigation)

Bottom nav requires independent back stacks per tab — switching tabs must preserve each tab's history. Single root `ChildStack` cannot express this; use one `StackNavigation` + `childStack(...)` per tab, scoped under distinct `childContext(key = ...)` to keep their `StateKeeper`/`InstanceKeeper`/lifecycle isolated. Pick which tab is visible via `SlotNavigation` (or `PagesNavigation` if want swipe).

```kotlin
interface RootComponent {
    val tabSlot: Value<ChildSlot<TabConfig, TabChild>>
    fun selectTab(tab: TabConfig)

    @Serializable
    sealed class TabConfig {
        @Serializable data object Home : TabConfig()
        @Serializable data object Search : TabConfig()
        @Serializable data object Profile : TabConfig()
    }

    sealed class TabChild {
        data class Home(val component: HomeTabComponent) : TabChild()
        data class Search(val component: SearchTabComponent) : TabChild()
        data class Profile(val component: ProfileTabComponent) : TabChild()
    }
}

class DefaultRootComponent(
    componentContext: ComponentContext,
    private val homeTabFactory: HomeTabComponent.Factory,
    // ...
) : RootComponent, ComponentContext by componentContext {

    private val tabNavigation = SlotNavigation<RootComponent.TabConfig>()

    override val tabSlot: Value<ChildSlot<RootComponent.TabConfig, RootComponent.TabChild>> =
        childSlot(
            source = tabNavigation,
            serializer = RootComponent.TabConfig.serializer(),
            initialConfiguration = { RootComponent.TabConfig.Home },
            // Keep all tabs alive so their back stacks survive tab switches.
            // Without this, an inactive tab's components are destroyed and history is lost.
            handleBackButton = false,
            childFactory = ::createTab
        )

    private fun createTab(
        config: RootComponent.TabConfig,
        context: ComponentContext
    ): RootComponent.TabChild = when (config) {
        RootComponent.TabConfig.Home -> RootComponent.TabChild.Home(
            homeTabFactory.create(
                // Distinct key per tab — gives each subtree its own
                // StateKeeper/InstanceKeeper namespace under the same parent.
                componentContext = context.childContext(key = "tab-home"),
            )
        )
        // ... search, profile analogous
    }

    override fun selectTab(tab: RootComponent.TabConfig) {
        // Re-tap on already-active tab → pop that tab's stack to root.
        if (tabSlot.value.child?.configuration == tab) {
            (tabSlot.value.child?.instance as? PoppableTab)?.popToRoot()
            return
        }
        tabNavigation.activate(tab)
    }
}

interface PoppableTab { fun popToRoot() }

// Per-tab component owns its own StackNavigation and ChildStack.
class DefaultHomeTabComponent(
    componentContext: ComponentContext,
) : HomeTabComponent, PoppableTab, ComponentContext by componentContext {

    private val navigation = StackNavigation<HomeConfig>()

    override val childStack: Value<ChildStack<HomeConfig, HomeChild>> =
        childStack(
            source = navigation,
            serializer = HomeConfig.serializer(),
            initialConfiguration = HomeConfig.List,
            // Important: only the active tab should consume back press;
            // wire this through your platform back dispatcher.
            handleBackButton = true,
            childFactory = ::createChild,
            key = "home-stack"  // unique within this tab's context
        )

    override fun popToRoot() {
        navigation.popWhile { it !is HomeConfig.List }
    }
}
```

Why each piece:
- **`childContext(key = "tab-home")`** — without unique keys, sibling tabs share `StateKeeper` slot names and one will overwrite the other on save/restore.
- **`SlotNavigation` over `StackNavigation` for tab selector** — tabs aren't a back stack; they're a flat switch. Using a stack here would push tabs onto each other.
- **Per-tab `StackNavigation`** — back press inside Home tab pops Home's stack only, not the tab selection.
- **Re-tap pop-to-root** — standard mobile UX (iOS tab bar, Material bottom nav). Detect by comparing current slot config before activating.

## Compose Integration

### Observing State

```kotlin
@Composable
fun HomeScreen(component: HomeComponent) {
    val state by component.state.subscribeAsState()

    when (val currentState = state) {
        is HomeState.Loading -> LoadingIndicator()
        is HomeState.Error -> ErrorContent(
            message = currentState.message,
            onRetry = component::onRefresh
        )
        is HomeState.Success -> HomeContent(
            items = currentState.items,
            onItemClick = component::onItemClick
        )
    }
}
```

### Rendering Child Stack

```kotlin
@Composable
fun RootContent(component: RootComponent) {
    val childStack by component.childStack.subscribeAsState()

    Children(
        stack = childStack,
        modifier = Modifier.fillMaxSize(),
        animation = stackAnimation(fade() + slide())
    ) { child ->
        when (val instance = child.instance) {
            is RootComponent.Child.Home -> HomeScreen(instance.component)
            is RootComponent.Child.Details -> DetailsScreen(instance.component)
            is RootComponent.Child.Settings -> SettingsScreen(instance.component)
        }
    }
}

// Animation options
val animation = stackAnimation(
    fade(),                    // Fade in/out
    slide(),                   // Slide horizontal
    scale(),                   // Scale
    fade() + slide(),          // Combined
    slide(SlideAnimation.Top)  // Slide from top
)
```

### Rendering Child Slot (Dialog)

```kotlin
@Composable
fun HomeScreen(component: HomeComponent) {
    val state by component.state.subscribeAsState()
    val dialogSlot by component.dialogSlot.subscribeAsState()

    Scaffold { paddingValues ->
        // Main content
        HomeContent(
            modifier = Modifier.padding(paddingValues),
            state = state,
            onItemLongClick = { component.showConfirmDialog(it.id) }
        )

        // Dialog overlay
        dialogSlot.child?.instance?.let { dialogChild ->
            when (dialogChild) {
                is DialogChild.Confirm -> ConfirmDialog(dialogChild.component)
                is DialogChild.Edit -> EditDialog(dialogChild.component)
            }
        }
    }
}

@Composable
private fun ConfirmDialog(component: ConfirmDialogComponent) {
    AlertDialog(
        onDismissRequest = component::onDismiss,
        title = { Text("Delete Item?") },
        text = { Text("This action cannot be undone.") },
        confirmButton = {
            TextButton(onClick = component::onConfirm) {
                Text("Delete")
            }
        },
        dismissButton = {
            TextButton(onClick = component::onDismiss) {
                Text("Cancel")
            }
        }
    )
}
```

## State Preservation

### InstanceKeeper (Config Changes)

Survives configuration changes on Android. Does NOT survive process death.

```kotlin
class MyComponent(componentContext: ComponentContext) : ComponentContext by componentContext {

    // Approach 1: Manual
    private val viewModel = instanceKeeper.getOrCreate("viewModel") {
        MyViewModel()
    }

    // Approach 2: Extension
    private val viewModel by retainedInstance { MyViewModel() }

    class MyViewModel : InstanceKeeper.Instance {
        val state = MutableStateFlow<UiState>(UiState.Initial)

        override fun onDestroy() {
            // Cleanup when component truly destroyed
        }
    }
}
```

### StateKeeper (Process Death)

Survives process death. Data must be serializable.

```kotlin
class MyComponent(componentContext: ComponentContext) : ComponentContext by componentContext {

    // Approach 1: Delegate property
    private var searchQuery: String by savedState("searchQuery", "")
    private var selectedTab: Int by savedState("selectedTab", 0)

    // Approach 2: Complex state
    @Serializable
    data class SavedState(
        val query: String = "",
        val filters: List<Filter> = emptyList(),
        val scrollPosition: Int = 0
    )

    private var savedState: SavedState by savedState("state", SavedState())

    // Approach 3: Manual
    init {
        stateKeeper.register("manualState") {
            SavedState(query = currentQuery, filters = currentFilters)
        }

        stateKeeper.consume<SavedState>("manualState")?.let { restored ->
            currentQuery = restored.query
            currentFilters = restored.filters
        }
    }
}
```

## Component Hierarchy Pattern

### Feature Module Structure

```
feature/home/impl/src/commonMain/kotlin/
├── HomeComponent.kt          # Interface
├── DefaultHomeComponent.kt   # Implementation
├── HomeState.kt              # State sealed class
├── di/
│   └── HomeModule.kt         # Metro bindings
└── ui/
    ├── HomeScreen.kt         # Compose UI
    └── HomeContent.kt        # UI components
```

### Component Interface Pattern

```kotlin
// feature/home/api/src/commonMain/kotlin/HomeComponent.kt
interface HomeComponent {
    val state: Value<HomeState>
    val dialogSlot: Value<ChildSlot<*, DialogChild>>

    fun onItemClick(item: HomeItem)
    fun onRefresh()
    fun showDeleteDialog(itemId: String)
    fun dismissDialog()

    interface Factory {
        fun create(
            componentContext: ComponentContext,
            onNavigateToDetails: (String) -> Unit
        ): HomeComponent
    }
}
```

### Factory with DI

```kotlin
// feature/home/impl/src/commonMain/kotlin/DefaultHomeComponent.kt
@Inject
class DefaultHomeComponent(
    private val repository: HomeRepository,
    @Assisted componentContext: ComponentContext,
    @Assisted private val onNavigateToDetails: (String) -> Unit
) : HomeComponent, ComponentContext by componentContext {

    // Implementation...

    @AssistedFactory
    interface Factory : HomeComponent.Factory {
        override fun create(
            componentContext: ComponentContext,
            onNavigateToDetails: (String) -> Unit
        ): DefaultHomeComponent
    }
}
```

## Deep Linking

Two delivery moments to handle: **cold start** (process not running, link arrives via `Intent`/launch options — root component constructed with link) and **warm start** (process alive, link arrives via `onNewIntent` on Android or notification delegate on iOS — must forward to existing root component, not rebuild it).

### Cold-start: pre-built stack

For a flat app, `replaceAll(...)` after construction works. But if landing screen needs a real back stack (tap notification → Details, press back → List), build initial stack via `childStack(initialStack = ...)` overload — avoids one-frame flicker of List → Details and gets correct back behavior on first frame.

```kotlin
class DefaultRootComponent(
    componentContext: ComponentContext,
    deepLink: DeepLink? = null
) : RootComponent, ComponentContext by componentContext {

    private val navigation = StackNavigation<Config>()

    override val childStack: Value<ChildStack<Config, Child>> =
        childStack(
            source = navigation,
            serializer = Config.serializer(),
            initialStack = { resolveInitialStack(deepLink) },
            handleBackButton = true,
            childFactory = ::createChild
        )

    private fun resolveInitialStack(deepLink: DeepLink?): List<Config> = when (deepLink) {
        null -> listOf(Config.Home)
        is DeepLink.ItemDetails -> listOf(Config.Home, Config.Details(deepLink.itemId))
        is DeepLink.Settings -> listOf(Config.Home, Config.Settings)
    }

    // Warm-start entry: invoked from platform layer (see below).
    fun onDeepLink(deepLink: DeepLink) {
        navigation.navigate { stack ->
            when (deepLink) {
                is DeepLink.ItemDetails -> stack.dropLastWhile { it !is Config.Home } + Config.Details(deepLink.itemId)
                is DeepLink.Settings -> stack.dropLastWhile { it !is Config.Home } + Config.Settings
            }
        }
    }
}

sealed class DeepLink {
    data class ItemDetails(val itemId: String) : DeepLink()
    data object Settings : DeepLink()
}
```

`navigate { stack -> ... }` is the atomic operation: receives current stack, returns new stack — single recomposition, no transient state. Prefer it over chained `pop()`/`push()` for deep-link handling.

### Warm-start: Android `onNewIntent`

Android delivers warm-start links via `onNewIntent` on a `singleTask`/`singleTop` Activity. Hold the root component on the Activity and forward parsed link to it — do NOT recreate component or you lose all in-memory state.

```kotlin
// AndroidManifest.xml: <activity ... android:launchMode="singleTask">
class MainActivity : ComponentActivity() {
    private lateinit var rootComponent: RootComponent

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val deepLink = intent.data?.toString()?.let(::parseDeepLink)
        rootComponent = createGraph<AndroidAppGraph>().rootComponentFactory.create(
            componentContext = defaultComponentContext(),
            deepLink = deepLink
        )
        setContent { AppTheme { RootContent(rootComponent) } }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.let(::parseDeepLink)?.let(rootComponent::onDeepLink)
    }
}
```

### Warm-start: iOS

`UNUserNotificationCenterDelegate` (or universal-link delegate) fires while app foregrounded. Bridge to Kotlin by exposing the root component (or a thin wrapper) from `MainViewController` and calling `onDeepLink` from Swift.

```kotlin
// shared
class IosAppEntry {
    lateinit var rootComponent: RootComponent
        private set

    fun build(deepLink: DeepLink?): UIViewController { /* construct rootComponent, return ComposeUIViewController */ }
    fun handleDeepLink(deepLink: DeepLink) = rootComponent.onDeepLink(deepLink)
}
```

```swift
// iOS app
func userNotificationCenter(_:didReceive response: UNNotificationResponse, withCompletionHandler ...) {
    if let link = parseDeepLink(response.notification.request.content.userInfo) {
        AppEntry.shared.handleDeepLink(deepLink: link)
    }
}
```

### Bottom-nav deep links

With multi-tab structure, deep link to "item in Home tab" must (a) switch active tab to Home, (b) push Details onto Home's stack — flat `replaceAll` on root would clobber tab structure. Route the link through root, which dispatches to the right tab.

```kotlin
fun DefaultRootComponent.onDeepLink(deepLink: DeepLink) {
    when (deepLink) {
        is DeepLink.ItemDetails -> {
            tabNavigation.activate(TabConfig.Home)
            // After activation, the Home tab component exists in tabSlot —
            // forward to it. The tab component owns its own StackNavigation.
            (tabSlot.value.child?.instance as? RootComponent.TabChild.Home)
                ?.component
                ?.openDetails(deepLink.itemId)
        }
        is DeepLink.Profile -> tabNavigation.activate(TabConfig.Profile)
    }
}
```

If the target tab isn't yet instantiated (cold start with a non-default initial tab), use `initialConfiguration = { resolvedTab }` on the tab `childSlot` and pre-build the tab's stack via the `initialStack` overload of its `childStack(...)`.

### Process death between tap and construction

Notification tap can launch process; if OS kills it before `onCreate` finishes, link is lost unless preserved. Two-layer safety: (1) Android delivers `Intent` via `savedInstanceState`-aware launch; (2) for in-flight links arriving during reconstruction, stash via `StateKeeper`:

```kotlin
class DefaultRootComponent(
    componentContext: ComponentContext,
    deepLink: DeepLink? = null
) : RootComponent, ComponentContext by componentContext {

    // Persist any pending link that hasn't been consumed yet.
    private var pendingLink: DeepLink? by savedState("pendingLink", deepLink)

    init {
        pendingLink?.let { link ->
            // consume on first frame; clear so we don't re-apply on next restore
            handleDeepLink(link)
            pendingLink = null
        }
    }
}
```

Use this only for links whose target may not exist at construction time (e.g., requires async auth check). For synchronous routing, `initialStack` resolution is sufficient.

```kotlin
// Parse in platform code
fun parseDeepLink(uri: String): DeepLink? = when {
    uri.contains("/item/") -> DeepLink.ItemDetails(uri.substringAfter("/item/"))
    uri.contains("/settings") -> DeepLink.Settings
    else -> null
}
```

## Result Passing

### Callbacks

```kotlin
class DetailsComponent(
    componentContext: ComponentContext,
    private val itemId: String,
    private val onResult: (DetailsResult) -> Unit
) : ComponentContext by componentContext {

    fun onSave(data: ItemData) {
        // Save logic...
        onResult(DetailsResult.Saved(data))
    }

    fun onDelete() {
        // Delete logic...
        onResult(DetailsResult.Deleted)
    }
}

sealed class DetailsResult {
    data class Saved(val data: ItemData) : DetailsResult()
    data object Deleted : DetailsResult()
}

// In parent
private fun createDetailsChild(
    config: Config.Details,
    context: ComponentContext
): Child.Details = Child.Details(
    DetailsComponent(
        componentContext = context,
        itemId = config.itemId,
        onResult = { result ->
            when (result) {
                is DetailsResult.Saved -> refreshList()
                DetailsResult.Deleted -> navigation.pop()
            }
        }
    )
)
```

## Platform Entry Points

### Android

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val deepLink = intent.data?.toString()?.let(::parseDeepLink)

        val graph = createGraph<AndroidAppGraph>()
        val rootComponent = graph.rootComponentFactory.create(
            componentContext = defaultComponentContext(),
            deepLink = deepLink
        )

        setContent {
            AppTheme {
                RootContent(component = rootComponent)
            }
        }
    }
}
```

### iOS

```kotlin
fun MainViewController(deepLink: DeepLink? = null): UIViewController {
    return ComposeUIViewController {
        val rootComponent = remember {
            val graph = createGraph<IosAppGraph>()
            graph.rootComponentFactory.create(
                componentContext = DefaultComponentContext(
                    lifecycle = ApplicationLifecycle()
                ),
                deepLink = deepLink
            )
        }

        AppTheme {
            RootContent(component = rootComponent)
        }
    }
}
```

### Desktop

```kotlin
fun main() = application {
    val lifecycle = LifecycleRegistry()

    val graph = createGraph<DesktopAppGraph>()
    val rootComponent = runOnUiThread {
        graph.rootComponentFactory.create(
            componentContext = DefaultComponentContext(lifecycle)
        )
    }

    Window(onCloseRequest = ::exitApplication, title = "My Application") {
        LifecycleController(lifecycle)

        AppTheme {
            RootContent(component = rootComponent)
        }
    }
}
```

## Best Practices

### Do's
- Keep components UI-agnostic (no Compose imports)
- Use interfaces for component public API
- Use `Value<T>` for observable state (not StateFlow)
- Handle back navigation via `handleBackButton = true`
- Use `@Serializable` for all Config classes
- Preserve necessary state in StateKeeper
- Use componentScope for coroutines

### Don'ts
- Don't put Compose code in components
- Don't store Context/Activity in components
- Don't use StateFlow for component state (use Value)
- Don't skip Config serialization
- Don't create ComponentContext manually
- Don't forget to handle deep links

## Testing

```kotlin
class HomeComponentTest {
    @Test
    fun `initial state is loading`() {
        val component = DefaultHomeComponent(
            componentContext = TestComponentContext(),
            repository = FakeHomeRepository(),
            onNavigateToDetails = {}
        )

        assertEquals(HomeState.Loading, component.state.value)
    }

    @Test
    fun `loads items successfully`() = runTest {
        val fakeRepo = FakeHomeRepository(items = listOf(testItem))

        val component = DefaultHomeComponent(
            componentContext = TestComponentContext(),
            repository = fakeRepo,
            onNavigateToDetails = {}
        )

        advanceUntilIdle()

        val state = component.state.value
        assertTrue(state is HomeState.Success)
        assertEquals(1, (state as HomeState.Success).items.size)
    }
}

// Test helper
class TestComponentContext : ComponentContext {
    override val lifecycle = LifecycleRegistry()
    override val stateKeeper = StateKeeperDispatcher()
    override val instanceKeeper = InstanceKeeperDispatcher()
    override val backHandler = BackDispatcher()
}
```

## Resources

- [Decompose Docs](https://arkivanov.github.io/Decompose/)
- [Decompose GitHub](https://github.com/arkivanov/Decompose)
- [Decompose Template](https://github.com/arkivanov/Decompose-multiplatform-template)
