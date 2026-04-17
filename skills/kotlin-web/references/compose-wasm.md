# Compose for Web (WASM) — Advanced Patterns

## Navigation on Web

Compose WASM uses Decompose navigation — same as mobile:

```kotlin
// Browser URL sync with Decompose
import kotlinx.browser.window

class WebUrlSync(private val navigation: StackNavigation<Config>) {
    fun init() {
        // Listen to browser back/forward
        window.onpopstate = { event ->
            val path = window.location.pathname
            navigateToPath(path)
        }
    }

    fun pushState(config: Config) {
        val path = configToPath(config)
        window.history.pushState(null, "", path)
    }

    private fun configToPath(config: Config): String = when (config) {
        is Config.Home -> "/"
        is Config.Detail -> "/detail/${config.id}"
        is Config.Settings -> "/settings"
    }

    private fun navigateToPath(path: String) {
        val config = pathToConfig(path)
        if (config != null) {
            navigation.replaceCurrent(config)
        }
    }
}
```

## Responsive Breakpoints

```kotlin
object WebBreakpoints {
    val Mobile = 0.dp..599.dp
    val Tablet = 600.dp..1023.dp
    val Desktop = 1024.dp..Dp.Infinity
}

@Composable
fun AdaptiveLayout(
    mobileContent: @Composable () -> Unit,
    tabletContent: @Composable () -> Unit = mobileContent,
    desktopContent: @Composable () -> Unit = tabletContent
) {
    BoxWithConstraints {
        when {
            maxWidth < 600.dp -> mobileContent()
            maxWidth < 1024.dp -> tabletContent()
            else -> desktopContent()
        }
    }
}
```

## Web-Specific Compose Components

### Scrollbar Support

```kotlin
@Composable
fun ScrollableListWithScrollbar(
    items: List<Item>,
    content: @Composable (Item) -> Unit
) {
    val scrollState = rememberLazyListState()

    Box {
        LazyColumn(state = scrollState) {
            items(items) { item -> content(item) }
        }
        // WASM supports native scrollbar via CSS on the canvas container
    }
}
```

### Keyboard Shortcuts

```kotlin
@Composable
fun WithKeyboardShortcuts(
    onSave: () -> Unit,
    onCancel: () -> Unit,
    content: @Composable () -> Unit
) {
    Box(
        modifier = Modifier
            .onKeyEvent { event ->
                when {
                    event.isCtrlPressed && event.key == Key.S -> {
                        onSave()
                        true
                    }
                    event.key == Key.Escape -> {
                        onCancel()
                        true
                    }
                    else -> false
                }
            }
            .focusable()
    ) {
        content()
    }
}
```

## IndexedDB for Complex Storage

```kotlin
// wasmJsMain - for cases where localStorage is insufficient

external interface IDBDatabase
external interface IDBObjectStore
external interface IDBRequest

@JsName("indexedDB")
external val indexedDB: dynamic

class IndexedDbStorage(private val dbName: String) {
    private var db: IDBDatabase? = null

    suspend fun open(): IDBDatabase {
        return suspendCoroutine { cont ->
            val request = indexedDB.open(dbName, 1)
            request.onsuccess = { event: dynamic ->
                db = event.target.result
                cont.resume(event.target.result)
            }
            request.onerror = { event: dynamic ->
                cont.resumeWithException(Exception("IndexedDB error: ${event.target.error}"))
            }
            request.onupgradeneeded = { event: dynamic ->
                val database = event.target.result
                database.createObjectStore("data", js("{ keyPath: 'id' }"))
            }
        }
    }
}
```

## Deployment

### Static Hosting (Compose WASM)

Output is a static site — deploy anywhere:

```bash
# Build production
./gradlew :composeApp:wasmJsBrowserDistribution

# Output: composeApp/build/dist/wasmJs/productionExecutable/
# Contents: index.html, composeApp.js, composeApp.wasm
```

### Docker (Nginx)

```dockerfile
FROM nginx:alpine
COPY composeApp/build/dist/wasmJs/productionExecutable/ /usr/share/nginx/html/
# Add WASM MIME type if needed
RUN echo "types { application/wasm wasm; }" > /etc/nginx/conf.d/wasm.conf
EXPOSE 80
```

### Headers for WASM

Required server headers:
```
Content-Type: application/wasm  (for .wasm files)
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

## Performance Tips

1. **Lazy composables**: Defer heavy UI behind `LaunchedEffect` or user interaction
2. **Image optimization**: Use web-optimized formats, lazy load images
3. **State granularity**: Fine-grained `Value<T>` to minimize recompositions
4. **Avoid large lists**: Use `LazyColumn` with `key` parameter
5. **Preload critical resources**: Use `<link rel="preload">` in index.html
