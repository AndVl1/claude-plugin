# Kotlin Web Templates for KMP Features

Templates for web-specific code in KMP feature slices targeting `wasmJs` and `js` platforms.

## WASM Entry Point

```kotlin
// composeApp/src/wasmJsMain/kotlin/Main.kt
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.window.CanvasBasedWindow

@OptIn(ExperimentalComposeUiApi::class)
fun main() {
    CanvasBasedWindow(canvasElementId = "ComposeTarget") {
        App() // Same composable as other platforms
    }
}
```

### index.html for WASM

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>App</title>
    <style>
        html, body { margin: 0; padding: 0; width: 100%; height: 100%; }
        #ComposeTarget { width: 100%; height: 100vh; }
    </style>
</head>
<body>
    <canvas id="ComposeTarget"></canvas>
    <script src="composeApp.js"></script>
</body>
</html>
```

## WASM-Specific Limitations in Features

### Storage (no Room on WASM)

```kotlin
// wasmJsMain/kotlin/storage/WasmStorage.kt
import kotlinx.browser.localStorage

actual class AppStorage {
    actual fun getString(key: String): String? =
        localStorage.getItem(key)

    actual fun putString(key: String, value: String) {
        localStorage.setItem(key, value)
    }

    actual fun remove(key: String) {
        localStorage.removeItem(key)
    }
}
```

### Network (CORS-aware)

```kotlin
// wasmJsMain/kotlin/network/WasmHttpEngine.kt
import io.ktor.client.engine.js.*

actual fun createHttpEngine(): HttpClientEngine = Js.create()
```

### No Dispatchers.IO

```kotlin
// In commonMain, use expect/actual for dispatcher
expect val ioDispatcher: CoroutineDispatcher

// wasmJsMain
actual val ioDispatcher: CoroutineDispatcher = Dispatchers.Default

// androidMain
actual val ioDispatcher: CoroutineDispatcher = Dispatchers.IO

// jvmMain (desktop)
actual val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
```

## Compose WASM Component Adaptations

### Responsive Layout

```kotlin
// Use BoxWithConstraints for responsive behavior on web
@Composable
fun ResponsiveLayout(
    content: @Composable () -> Unit,
    sidePanel: @Composable () -> Unit
) {
    BoxWithConstraints {
        if (maxWidth > 840.dp) {
            // Desktop/web wide layout
            Row(modifier = Modifier.fillMaxSize()) {
                Box(modifier = Modifier.weight(0.3f)) { sidePanel() }
                Box(modifier = Modifier.weight(0.7f)) { content() }
            }
        } else {
            // Mobile/narrow layout
            content()
        }
    }
}
```

### Web-Specific Interactions

```kotlin
// Handle browser-specific behavior in wasmJsMain
expect fun openExternalUrl(url: String)

// wasmJsMain
actual fun openExternalUrl(url: String) {
    kotlinx.browser.window.open(url, "_blank")
}

// androidMain
actual fun openExternalUrl(url: String) {
    // Use Intent
}
```

## Build Configuration for WASM

```kotlin
// composeApp/build.gradle.kts
kotlin {
    wasmJs {
        browser {
            commonWebpackConfig {
                outputFileName = "composeApp.js"
            }
        }
        binaries.executable()
    }
}
```

### Running WASM Target

```bash
# Development
./gradlew :composeApp:wasmJsBrowserDevelopmentRun

# Production build
./gradlew :composeApp:wasmJsBrowserDistribution
```

## Platform-Conditional UI in Features

When a feature needs different UI on web vs mobile:

```kotlin
// In the View layer, use platform checks sparingly
@Composable
fun <Name>View(
    viewState: <Name>ViewState,
    eventHandler: (<Name>Event) -> Unit
) {
    // Platform-specific scaffold adjustments
    val horizontalPadding = if (currentPlatform == Platform.Web) 24.dp else 16.dp

    Scaffold(/* ... */) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = horizontalPadding)
        ) {
            // Shared UI content
        }
    }
}
```

## Cross-Reference

- For full Kotlin/JS + framework patterns (React, Vue), see `kotlin-web` skill
- For WASM project setup and limitations, see `kmp` skill (WASM Limitations section)
- For shared code strategy between platforms, see `kotlin-web` skill
