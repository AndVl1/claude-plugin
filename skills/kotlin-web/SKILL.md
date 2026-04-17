---
name: kotlin-web
description: Kotlin-based web frontend development - Compose WASM, Kotlin/JS+React, Kotlin/JS+Vue with decision tree for framework selection and shared code strategies
---

# Kotlin Web Frontend

Patterns for building web frontends in Kotlin. Three approaches with clear selection criteria.

## Decision Tree

> **Правило выбора**: Compose WASM — для быстрых MVP и внутренних инструментов. Для продакшн-приложений с серьёзными требованиями к UX, производительности и доступности — Kotlin/JS + React или Vue.

### Option 1: Compose for Web (WASM) — MVP / Internal Tools

**Choose when:**
- Быстрый MVP или прототип с максимальным переиспользованием мобильного UI
- Internal tools, admin panels, dashboards (ограниченная аудитория)
- Team is Kotlin-first, нет JS/TS экспертизы и не планируется нанимать
- Допустимы ограничения: большой бандл, нет SEO, ограниченная доступность (a11y)

**Don't choose when:**
- Production-facing продукт с внешними пользователями
- Need SSR/SEO
- Нужна полноценная доступность (screen readers, ARIA) — Compose WASM рендерит в canvas, DOM-based a11y отсутствует
- Need extensive npm ecosystem (charting, rich text editors, maps)
- Bundle size is critical (Compose WASM ~2-5MB initial)
- Need to integrate into existing JS/TS app
- Ожидается длительная поддержка и развитие фронтенда

**Limitations to be aware of:**
- Canvas-based rendering: нет нативных DOM-элементов, нет инспектора элементов в браузере
- Accessibility: практически отсутствует (no screen reader support)
- Mobile web: тяжёлый бандл на мобильных сетях
- Ecosystem maturity: Compose for Web всё ещё в активной разработке, API может меняться

### Option 2: Kotlin/JS + React — Production Web Apps

**Choose when:**
- Production-facing продукт, нужна зрелая экосистема
- Need React ecosystem (existing components, npm libraries)
- Team knows React patterns or willing to learn
- Integrating Kotlin business logic into React frontend
- Need SSR via Next.js
- Нужна полная доступность (a11y), SEO, performance

**Don't choose when:**
- No React experience on team AND tight deadlines
- Pure Kotlin stack preferred AND это внутренний инструмент (→ Compose WASM)

### Option 3: Kotlin/JS + Vue — Production Web Apps

**Choose when:**
- Production-facing продукт, предпочитается Vue ecosystem
- Need Vue ecosystem (Vuetify, Quasar, PrimeVue)
- Vue's reactivity model feels natural (similar to Kotlin Flow)
- Single File Components (SFC) preferred
- Team knows Vue patterns

**Don't choose when:**
- No Vue experience on team
- Need maximum community support (React has larger Kotlin/JS community)

## Comparison Matrix

| Criterion | Compose WASM | Kotlin/JS + React | Kotlin/JS + Vue |
|-----------|-------------|-------------------|-----------------|
| **Maturity** | Early (MVP/internal) | **Production-ready** | **Production-ready** |
| Code sharing with mobile | **Maximum** | Business logic only | Business logic only |
| Bundle size | ~2-5MB | ~200-500KB | ~200-500KB |
| npm ecosystem | Limited | **Full access** | **Full access** |
| SEO/SSR | No | Yes (Next.js) | Yes (Nuxt) |
| Accessibility (a11y) | None (canvas) | **Full (DOM)** | **Full (DOM)** |
| Learning curve (Kotlin dev) | **Lowest** | Medium | Medium |
| Browser APIs | Via interop | **Native** | **Native** |
| Performance (rendering) | Canvas-based | **DOM-native** | **DOM-native** |
| Long-term maintainability | Risky (API changes) | **Stable** | **Stable** |

## Compose WASM Setup

### Project Structure

```
composeApp/
└── src/
    ├── commonMain/kotlin/       # Shared UI + logic
    ├── wasmJsMain/kotlin/       # Web entry point
    │   ├── Main.kt
    │   └── platform/
    │       ├── WasmStorage.kt   # localStorage
    │       └── WasmPlatform.kt  # Browser APIs
    └── wasmJsMain/resources/
        └── index.html
```

### Entry Point

```kotlin
// wasmJsMain/kotlin/Main.kt
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.window.CanvasBasedWindow

@OptIn(ExperimentalComposeUiApi::class)
fun main() {
    CanvasBasedWindow(canvasElementId = "ComposeTarget") {
        App()
    }
}
```

### Build Configuration

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

### WASM Limitations

| Limitation | Workaround |
|-----------|------------|
| No Room database | Use `localStorage` / `IndexedDB` via expect/actual |
| No `Dispatchers.IO` | Use `Dispatchers.Default` |
| CORS on all requests | Configure server or proxy |
| No file system | Use Blob URLs, File API |
| Canvas rendering | No DOM accessibility by default |
| Large bundle (~2-5MB) | Lazy loading, code splitting (limited) |

### Browser API Interop

```kotlin
// Access browser APIs from WASM
import kotlinx.browser.window
import kotlinx.browser.document

fun getCurrentUrl(): String = window.location.href

fun setPageTitle(title: String) {
    document.title = title
}

// Using external JS functions
external fun fetch(url: String): Promise<Response>
```

### Reference: `references/compose-wasm.md` for advanced patterns

## Kotlin/JS Common Setup

Both React and Vue approaches share these fundamentals:

### Gradle Configuration

```kotlin
// build.gradle.kts
plugins {
    alias(libs.plugins.kotlinMultiplatform)
}

kotlin {
    js(IR) {
        browser {
            commonWebpackConfig {
                cssSupport { enabled.set(true) }
            }
        }
        binaries.executable()
    }

    sourceSets {
        jsMain.dependencies {
            // Shared Kotlin modules
            implementation(projects.core.common)
            implementation(projects.core.network)

            // npm dependencies
            implementation(npm("axios", "1.7.0"))
        }
    }
}
```

### npm Interop Pattern

```kotlin
// Declare external npm module
@JsModule("axios")
@JsNonModule
external fun axios(config: dynamic): Promise<dynamic>

// Type-safe wrapper
suspend fun <T> httpGet(url: String): T {
    val response = axios(js("{ method: 'get', url: url }")).await()
    return response.data.unsafeCast<T>()
}
```

### State Bridging (Kotlin Flow → JS Framework)

```kotlin
// Bridge Kotlin StateFlow to framework-observable state

// Common pattern for both React and Vue:
class StateBridge<T>(private val flow: StateFlow<T>) {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    fun subscribe(callback: (T) -> Unit): () -> Unit {
        val job = scope.launch {
            flow.collect { callback(it) }
        }
        return { job.cancel() }
    }

    fun currentValue(): T = flow.value
}
```

### Reference: `references/kotlin-js-react.md` for React-specific patterns
### Reference: `references/kotlin-js-vue.md` for Vue-specific patterns

## Shared Code Strategy

### What to Share Between Mobile and Web

| Layer | Share? | How |
|-------|--------|-----|
| Domain models | **Yes** | `commonMain` module |
| Repository interfaces | **Yes** | `commonMain` module |
| Use cases | **Yes** | `commonMain` module |
| Network client config | **Mostly** | expect/actual for engine |
| ViewState/ViewEvent | **Compose WASM: Yes** | Same sealed classes |
| ViewState/ViewEvent | **Kotlin/JS: Adapt** | Map to framework state |
| UI components | **Compose WASM: Yes** | Same composables |
| UI components | **Kotlin/JS: No** | Rewrite in React/Vue |
| Navigation | **No** | Platform-specific |
| Storage | **Interface only** | expect/actual |

### Module Structure for Shared Code

```
project/
├── shared/
│   ├── core/                    # Domain models, utils
│   │   └── src/commonMain/
│   ├── data/                    # Repository interfaces, DTOs
│   │   └── src/commonMain/
│   └── domain/                  # Use cases
│       └── src/commonMain/
│
├── composeApp/                  # Compose WASM + mobile
│   └── src/
│       ├── commonMain/          # Shared Compose UI
│       ├── androidMain/
│       ├── iosMain/
│       └── wasmJsMain/
│
└── webApp/                      # Kotlin/JS + React/Vue (if not using Compose WASM)
    └── src/jsMain/
```

## Build & Run Commands

```bash
# Compose WASM
./gradlew :composeApp:wasmJsBrowserDevelopmentRun      # Dev server
./gradlew :composeApp:wasmJsBrowserDistribution        # Production

# Kotlin/JS
./gradlew :webApp:jsBrowserDevelopmentRun              # Dev server
./gradlew :webApp:jsBrowserDistribution                # Production
```

## Integration with Other Skills

| Skill | Relationship |
|-------|-------------|
| `kmp` | Project structure, source sets, expect/actual patterns |
| `kmp-feature-slice` | Feature generation. Load `kotlin-web-templates.md` for web targets |
| `compose-arch` | Architecture rules apply to Compose WASM UI (same composables) |
| `ktor-client` | HTTP client patterns, shared between mobile and web |
