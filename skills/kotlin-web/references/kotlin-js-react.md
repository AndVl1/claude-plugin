# Kotlin/JS + React Patterns

## Project Setup

### Dependencies

```kotlin
// webApp/build.gradle.kts
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
            // Kotlin React wrappers
            implementation("org.jetbrains.kotlin-wrappers:kotlin-react:19.1.0-pre.886")
            implementation("org.jetbrains.kotlin-wrappers:kotlin-react-dom:19.1.0-pre.886")
            implementation("org.jetbrains.kotlin-wrappers:kotlin-react-router-dom:7.5.0-pre.886")
            implementation("org.jetbrains.kotlin-wrappers:kotlin-emotion:11.14.0-pre.886")

            // Shared Kotlin modules
            implementation(projects.shared.core)
            implementation(projects.shared.domain)
        }
    }
}
```

### Entry Point

```kotlin
// src/jsMain/kotlin/Main.kt
import react.create
import react.dom.client.createRoot
import kotlinx.browser.document

fun main() {
    val root = document.getElementById("root") ?: error("Root element not found")
    createRoot(root).render(App.create())
}
```

## Component Patterns

### Functional Component with State

```kotlin
val FeatureList = FC<Props> {
    // Bridge Kotlin StateFlow to React state
    val (items, setItems) = useState<List<FeatureItem>>(emptyList())
    val (loading, setLoading) = useState(true)
    val (error, setError) = useState<String?>(null)

    val repository = useMemo { FeatureRepository(HttpClient()) }

    useEffectOnce {
        MainScope().launch {
            try {
                val result = repository.getItems()
                result.onSuccess { setItems(it) }
                result.onError { msg, _ -> setError(msg) }
            } finally {
                setLoading(false)
            }
        }
    }

    when {
        loading -> LoadingSpinner {}
        error != null -> ErrorMessage { message = error }
        items.isEmpty() -> EmptyState {}
        else -> {
            div {
                css { /* emotion styles */ }
                items.forEach { item ->
                    FeatureCard {
                        key = item.id
                        this.item = item
                        onItemClick = { /* navigate */ }
                    }
                }
            }
        }
    }
}
```

### Props with Kotlin Types

```kotlin
external interface FeatureCardProps : Props {
    var item: FeatureItem      // Kotlin domain model
    var onItemClick: (String) -> Unit
}

val FeatureCard = FC<FeatureCardProps> { props ->
    div {
        css {
            padding = 16.px
            borderRadius = 8.px
            cursor = Cursor.pointer
            hover { backgroundColor = Color("#f5f5f5") }
        }
        onClick = { props.onItemClick(props.item.id) }

        h3 { +props.item.title }
        p { +props.item.description }
    }
}
```

## Routing

```kotlin
val App = FC<Props> {
    BrowserRouter {
        Routes {
            Route {
                path = "/"
                element = HomePage.create()
            }
            Route {
                path = "/features"
                element = FeatureList.create()
            }
            Route {
                path = "/features/:id"
                element = FeatureDetail.create()
            }
        }
    }
}

// Using route params
val FeatureDetail = FC<Props> {
    val params = useParams()
    val featureId = params["id"] ?: return@FC

    // Load feature by id...
}
```

## State Management with Kotlin Flow

```kotlin
// Bridge pattern: Kotlin StateFlow → React hook

fun <T> useStateFlow(flow: StateFlow<T>): T {
    val (state, setState) = useState(flow.value)

    useEffectOnce {
        val job = MainScope().launch {
            flow.collect { setState(it) }
        }
        cleanup { job.cancel() }
    }

    return state
}

// Usage in component
val FeatureScreen = FC<Props> {
    val viewModel = useMemo { FeatureViewModel() }
    val state = useStateFlow(viewModel.state)

    when (state) {
        is FeatureState.Loading -> LoadingSpinner {}
        is FeatureState.Success -> FeatureContent { data = state.data }
        is FeatureState.Error -> ErrorContent { message = state.message }
    }
}
```

## Styling with Emotion

```kotlin
val StyledButton = FC<ButtonProps> { props ->
    button {
        css {
            padding = Padding(8.px, 16.px)
            backgroundColor = if (props.primary) Color("#1976d2") else Color.transparent
            color = if (props.primary) Color.white else Color("#1976d2")
            border = Border(1.px, LineStyle.solid, Color("#1976d2"))
            borderRadius = 4.px
            cursor = Cursor.pointer
            fontSize = 14.px
            fontWeight = FontWeight.w500

            hover {
                backgroundColor = if (props.primary) Color("#1565c0") else Color("#e3f2fd")
            }

            disabled {
                opacity = number(0.5)
                cursor = Cursor.notAllowed
            }
        }
        disabled = props.disabled
        onClick = { props.onClick?.invoke() }

        +props.text
    }
}
```

## npm Library Integration

```kotlin
// Declare external React component from npm

@JsModule("@mui/material/Button")
@JsNonModule
external val MuiButton: react.ComponentClass<dynamic>

// Usage
MuiButton {
    attrs["variant"] = "contained"
    attrs["color"] = "primary"
    attrs["onClick"] = { handleClick() }
    +"Click me"
}
```

## Testing

```kotlin
// src/jsTest/kotlin/FeatureListTest.kt
import react.dom.test.renderIntoDocument
import kotlin.test.Test

class FeatureListTest {
    @Test
    fun renders_loading_state() {
        renderIntoDocument {
            FeatureList {}
        }
        // Assert loading spinner visible
    }
}
```
