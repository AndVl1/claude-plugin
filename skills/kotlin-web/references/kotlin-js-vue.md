# Kotlin/JS + Vue Patterns

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
            // Vue via npm
            implementation(npm("vue", "3.5.0"))
            implementation(npm("vue-router", "4.5.0"))
            implementation(npm("pinia", "3.0.0"))

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
import kotlinx.browser.document

external interface VueApp {
    fun use(plugin: dynamic): VueApp
    fun mount(selector: String): dynamic
}

@JsModule("vue")
@JsNonModule
external object Vue {
    fun createApp(component: dynamic): VueApp
}

@JsModule("vue-router")
@JsNonModule
external fun createRouter(options: dynamic): dynamic

@JsModule("pinia")
@JsNonModule
external fun createPinia(): dynamic

fun main() {
    val app = Vue.createApp(AppComponent)
    app.use(createRouter(routerConfig()))
    app.use(createPinia())
    app.mount("#app")
}
```

## Component Patterns

### Defining Vue Components in Kotlin

```kotlin
// Component definition via dynamic object
val FeatureList = js("{}").unsafeCast<dynamic>().apply {
    template = """
        <div class="feature-list">
            <div v-if="loading" class="loading">Loading...</div>
            <div v-else-if="error" class="error">{{ error }}</div>
            <div v-else-if="items.length === 0" class="empty">No items</div>
            <div v-else>
                <feature-card
                    v-for="item in items"
                    :key="item.id"
                    :item="item"
                    @click="onItemClick(item)"
                />
            </div>
        </div>
    """.trimIndent()

    components = js("{}").apply {
        set("feature-card", FeatureCard)
    }

    setup = { _: dynamic ->
        val state = useFeatureStore()
        js("{}").apply {
            set("items", state.items)
            set("loading", state.loading)
            set("error", state.error)
            set("onItemClick", state.navigateToDetail)
        }
    }
}
```

### Type-Safe Props

```kotlin
val FeatureCard = js("{}").unsafeCast<dynamic>().apply {
    props = js("{}").apply {
        set("item", js("{ type: Object, required: true }"))
    }

    template = """
        <div class="feature-card" @click="${'$'}emit('click')">
            <h3>{{ item.title }}</h3>
            <p>{{ item.description }}</p>
        </div>
    """.trimIndent()

    emits = arrayOf("click")
}
```

## State Management with Pinia + Kotlin

### Store Definition

```kotlin
// Bridge Kotlin use cases to Pinia store

@JsModule("pinia")
@JsNonModule
external fun defineStore(id: String, options: dynamic): dynamic

val useFeatureStore = defineStore("feature", js("{}").apply {
    state = {
        js("{}").apply {
            set("items", emptyArray<dynamic>())
            set("loading", true)
            set("error", null)
        }
    }

    actions = js("{}").apply {
        set("fetchItems", fun() {
            val store = js("this")
            store.loading = true
            store.error = null

            MainScope().launch {
                val repository = FeatureRepository(HttpClient())
                repository.getItems()
                    .onSuccess { items ->
                        store.items = items.map { it.toJs() }.toTypedArray()
                        store.loading = false
                    }
                    .onError { msg, _ ->
                        store.error = msg
                        store.loading = false
                    }
            }
        })
    }
})

// Domain model → JS object conversion
fun FeatureItem.toJs(): dynamic = js("{}").apply {
    set("id", this@toJs.id)
    set("title", this@toJs.title)
    set("description", this@toJs.description)
}
```

## Routing

```kotlin
fun routerConfig(): dynamic = js("{}").apply {
    history = createWebHistory()
    routes = arrayOf(
        js("{}").apply {
            path = "/"
            component = HomePage
        },
        js("{}").apply {
            path = "/features"
            component = FeatureList
        },
        js("{}").apply {
            path = "/features/:id"
            component = FeatureDetail
            props = true
        }
    )
}

@JsModule("vue-router")
@JsNonModule
external fun createWebHistory(): dynamic
```

## Kotlin Flow → Vue Reactivity Bridge

```kotlin
// Bridge StateFlow to Vue reactive ref

@JsModule("vue")
@JsNonModule
external fun ref(value: dynamic): dynamic

@JsModule("vue")
@JsNonModule
external fun onMounted(callback: () -> Unit)

@JsModule("vue")
@JsNonModule
external fun onUnmounted(callback: () -> Unit)

fun <T> useKotlinFlow(flow: StateFlow<T>): dynamic {
    val vueRef = ref(flow.value)
    var job: Job? = null

    onMounted {
        job = MainScope().launch {
            flow.collect { value ->
                vueRef.value = value
            }
        }
    }

    onUnmounted {
        job?.cancel()
    }

    return vueRef
}
```

## Styling

### Scoped CSS (via template)

```kotlin
val StyledComponent = js("{}").unsafeCast<dynamic>().apply {
    template = """
        <button :class="['btn', { 'btn-primary': primary }]" :disabled="disabled">
            <slot></slot>
        </button>
    """.trimIndent()

    props = js("{}").apply {
        set("primary", js("{ type: Boolean, default: false }"))
        set("disabled", js("{ type: Boolean, default: false }"))
    }

    // Scoped styles via style tag in SFC or CSS modules
}
```

### Using CSS Modules

```kotlin
// Import CSS module
@JsModule("./FeatureList.module.css")
@JsNonModule
external val styles: dynamic

// Usage in template: :class="${'$'}style.container"
```

## Vue UI Library Integration

### Vuetify Example

```kotlin
// npm dependency
implementation(npm("vuetify", "3.8.0"))

// In Main.kt
@JsModule("vuetify")
@JsNonModule
external fun createVuetify(options: dynamic = definedExternally): dynamic

fun main() {
    val vuetify = createVuetify()
    val app = Vue.createApp(AppComponent)
    app.use(vuetify)
    app.mount("#app")
}

// Use Vuetify components in templates:
// <v-btn color="primary">Click me</v-btn>
// <v-card>...</v-card>
```

## Testing

```kotlin
// Using @vue/test-utils via npm
implementation(npm("@vue/test-utils", "2.4.0"))

// Test example
class FeatureCardTest {
    @Test
    fun renders_item_title() {
        val wrapper = mount(FeatureCard, js("{}").apply {
            props = js("{}").apply {
                set("item", js("{ id: '1', title: 'Test', description: 'Desc' }"))
            }
        })
        assertTrue(wrapper.text().contains("Test"))
    }
}

@JsModule("@vue/test-utils")
@JsNonModule
external fun mount(component: dynamic, options: dynamic = definedExternally): dynamic
```

## Trade-offs vs React Approach

| Aspect | Kotlin/JS + Vue | Kotlin/JS + React |
|--------|----------------|-------------------|
| Template syntax | HTML templates (string-based in Kotlin) | JSX-like via Kotlin DSL |
| Type safety in templates | Lower (string templates) | Higher (Kotlin DSL) |
| Reactivity | Built-in (Composition API) | External (hooks) |
| State management | Pinia (Vue-native) | Zustand/Redux |
| Kotlin wrappers quality | Less mature | JetBrains-maintained |
| Community | Smaller Kotlin/JS community | Larger Kotlin/JS community |
