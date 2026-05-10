---
name: ktgbotapi-patterns
description: Telegram bot architecture patterns (ktgbotapi 33.x) — project structure, modular handlers, DI via Metro (standalone) or Spring (embedded in backend), callback models, keyboards, utils. Always use the versions listed below; never regress to ktgbotapi 31.x. Koin is no longer recommended — use Metro for compile-time safety.
---

# KTgBotAPI Architecture Patterns

Patterns for organizing Telegram bot projects with ktgbotapi.

## Current Versions (use these — do not downgrade)

| Component | Version | Notes |
|---|---|---|
| ktgbotapi | **33.1.0** | See `ktgbotapi` skill for v32→v33 breaking changes (BotToken value class, Unit return types, Poll API). |
| Metro | **1.0.0** | Default DI for standalone bots — compile-time graph, no runtime crashes. See `metro-di-mobile` skill. |
| Spring Boot | **3.4.x** | Use Spring DI when bot lives inside a full backend (sharing services, DB, observability). See `kotlin-spring-boot` skill. |
| Ktor client | **3.4.3** | See `ktor-client` skill for client patterns. |
| Kotlin | **2.3.21** | |

> **Koin is intentionally not in this skill anymore.** Earlier revisions documented Koin 4.x as the default. We removed it because: (1) compile-time DI catches missing bindings before deploy — Telegram bots can run for weeks without hitting a code path, so a runtime DI miss is found by users, not CI; (2) for monostack setups (mobile + bot + backend on Metro), one DI framework everywhere wins over two; (3) when the bot is part of a Spring backend, Spring DI is already there. If a project genuinely needs Koin (KMP bot sharing modules with a Koin-driven mobile app, or hot-reload module swapping), apply Koin manually — but don't take it from this skill.

## Project Structure

```
src/main/kotlin/com/example/bot/
├── Application.kt              # Entry point
├── di/
│   ├── BotGraph.kt             # Metro @DependencyGraph (standalone)
│   └── BotPlatformModule.kt    # @BindingContainer with @Provides for HttpClient, Json, env config
├── config/
│   └── BotConfig.kt            # Bot configuration value class
├── handlers/
│   ├── CommandHandlers.kt      # /start, /help, etc.
│   ├── MessageHandlers.kt      # Text message handlers
│   ├── CallbackHandlers.kt     # Inline button callbacks
│   └── MediaHandlers.kt        # Photo, document, etc.
├── keyboards/
│   ├── InlineKeyboards.kt      # Inline keyboard builders
│   └── ReplyKeyboards.kt       # Reply keyboard builders
├── fsm/
│   ├── States.kt               # FSM state definitions
│   └── StateHandlers.kt        # State transition handlers
├── api/
│   ├── BackendApiService.kt    # HTTP calls to backend (see ktor-client skill)
│   └── ApiModels.kt            # Request/Response DTOs
├── services/
│   ├── UserService.kt          # Business logic
│   └── NotificationService.kt
├── models/
│   ├── User.kt                 # Domain models
│   └── CallbackData.kt         # Callback payload models
└── utils/
    ├── Extensions.kt           # Useful extensions
    └── Formatters.kt           # Text formatting helpers
```

> **Note:** For backend API communication patterns, see the `ktor-client` skill. Embedded-in-Spring deployment uses Spring's project structure (`@Service`, `@Configuration`) instead of `di/` — see "DI: Spring Boot variant" below.

## Modular Handler Pattern

### Application Entry Point

```kotlin
// Application.kt — standalone bot with Metro
suspend fun main() {
    val graph = createGraph<BotGraph>()
    val bot = graph.telegramBot

    bot.buildBehaviourWithLongPolling(
        defaultExceptionsHandler = { logger.error("Bot error", it) }
    ) {
        with(graph.commandHandlers) { register() }
        with(graph.messageHandlers) { register() }
        with(graph.callbackHandlers) { register() }
        with(graph.mediaHandlers) { register() }
    }.join()
}
```

Each handler class exposes `suspend fun BehaviourContext.register()` as an extension on its enclosing class — see "Modular Handler Pattern" below.

### Handler Modules

Handlers are classes with constructor-injected dependencies. They expose `register()` as an extension on `BehaviourContext`, which keeps the DSL receiver while still letting the handler hold injected services.

```kotlin
// handlers/CommandHandlers.kt
@Inject
class CommandHandlers(
    private val userService: UserService,
) {
    suspend fun BehaviourContext.register() {
        onCommand("start") { message ->
            reply(message, "Welcome!", replyMarkup = ReplyKeyboards.main())
        }

        onCommand("help") { message ->
            reply(message, HelpTexts.commands())
        }

        onCommand("profile") { message ->
            val user = userService.findByChatId(message.chat.id.chatId)
            reply(message, user?.let { "Name: ${it.name}" } ?: "Not registered")
        }

        onDeepLink { message, deepLink -> handleDeepLink(message, deepLink) }
    }
}

// handlers/MessageHandlers.kt
@Inject
class MessageHandlers {
    suspend fun BehaviourContext.register() {
        onText(initialFilter = { it.content.text == "📋 Menu" }) { showMenu(it) }
        onText(initialFilter = { it.content.text == "⚙️ Settings" }) { showSettings(it) }
    }
}

// handlers/CallbackHandlers.kt
@Inject
class CallbackHandlers(
    private val api: BackendApiService,
) {
    suspend fun BehaviourContext.register() {
        onDataCallbackQuery(Regex("menu:.*")) { handleMenuCallback(it) }
        onDataCallbackQuery(Regex("item:.*")) { handleItemCallback(it, api) }
        onDataCallbackQuery(Regex("page:.*")) { handlePaginationCallback(it) }
    }
}
```

> **Why extension on `BehaviourContext` inside a class?** ktgbotapi's DSL (`onCommand`, `onText`, ...) requires `BehaviourContext` as receiver. Free-standing extension functions can't carry constructor state, so we put the extension *inside* the class — `register()` is a member extension, the class holds dependencies, and the DSL receiver flows in at the call site (`with(graph.commandHandlers) { register() }`).

## Callback Data Models

Type-safe callback data parsing:

```kotlin
// models/CallbackData.kt
sealed class CallbackData {
    abstract fun encode(): String

    // Menu actions
    data class Menu(val action: String) : CallbackData() {
        override fun encode() = "m:$action"
    }

    // Item operations
    data class Item(val action: String, val id: String) : CallbackData() {
        override fun encode() = "i:$action:$id"
    }

    // Pagination
    data class Page(val list: String, val page: Int) : CallbackData() {
        override fun encode() = "p:$list:$page"
    }

    // Confirmation
    data class Confirm(val action: String, val id: String) : CallbackData() {
        override fun encode() = "c:$action:$id"
    }

    companion object {
        fun parse(data: String): CallbackData? {
            val parts = data.split(":")
            return when (parts.getOrNull(0)) {
                "m" -> Menu(parts[1])
                "i" -> Item(parts[1], parts[2])
                "p" -> Page(parts[1], parts[2].toInt())
                "c" -> Confirm(parts[1], parts[2])
                else -> null
            }
        }
    }
}

// Usage in handlers
suspend fun BehaviourContext.setupCallbackHandlers() {
    onDataCallbackQuery { query ->
        when (val cb = CallbackData.parse(query.data)) {
            is CallbackData.Menu -> handleMenu(query, cb.action)
            is CallbackData.Item -> handleItem(query, cb.action, cb.id)
            is CallbackData.Page -> handlePage(query, cb.list, cb.page)
            is CallbackData.Confirm -> handleConfirm(query, cb.action, cb.id)
            null -> answer(query, "Unknown action")
        }
    }
}

// Usage in keyboard builders
fun itemKeyboard(itemId: String) = inlineKeyboard {
    row {
        dataButton("✏️ Edit", CallbackData.Item("edit", itemId).encode())
        dataButton("🗑 Delete", CallbackData.Item("delete", itemId).encode())
    }
}
```

## Keyboard Builders

### Inline Keyboards Object

```kotlin
// keyboards/InlineKeyboards.kt
object InlineKeyboards {

    fun mainMenu() = inlineKeyboard {
        row { dataButton("📊 Statistics", "m:stats") }
        row {
            dataButton("👤 Profile", "m:profile")
            dataButton("⚙️ Settings", "m:settings")
        }
        row { urlButton("📖 Help", "https://example.com/help") }
    }

    fun confirmation(action: String, id: String) = inlineKeyboard {
        row {
            dataButton("✅ Confirm", "c:$action:$id")
            dataButton("❌ Cancel", "c:cancel:$id")
        }
    }

    fun pagination(list: String, current: Int, total: Int) = inlineKeyboard {
        row {
            if (current > 1) dataButton("◀️", "p:$list:${current - 1}")
            dataButton("$current / $total", "p:$list:$current")
            if (current < total) dataButton("▶️", "p:$list:${current + 1}")
        }
    }

    fun itemActions(id: String) = inlineKeyboard {
        row {
            dataButton("✏️ Edit", "i:edit:$id")
            dataButton("🗑 Delete", "i:delete:$id")
        }
        row { dataButton("◀️ Back", "m:back") }
    }

    fun backButton(target: String = "back") = inlineKeyboard {
        row { dataButton("◀️ Back", "m:$target") }
    }
}
```

### Reply Keyboards Object

```kotlin
// keyboards/ReplyKeyboards.kt
object ReplyKeyboards {

    fun main() = replyKeyboard(resizeKeyboard = true) {
        row {
            simpleButton("📋 Menu")
            simpleButton("⚙️ Settings")
        }
        row { simpleButton("❓ Help") }
    }

    fun cancel() = replyKeyboard(resizeKeyboard = true, oneTimeKeyboard = true) {
        row { simpleButton("❌ Cancel") }
    }

    fun yesNo() = replyKeyboard(resizeKeyboard = true, oneTimeKeyboard = true) {
        row {
            simpleButton("✅ Yes")
            simpleButton("❌ No")
        }
    }

    fun phoneRequest() = replyKeyboard(resizeKeyboard = true) {
        row { requestContactButton("📱 Share Phone") }
        row { simpleButton("❌ Cancel") }
    }

    fun remove() = ReplyKeyboardRemove()
}
```

## FSM Pattern

### State Definitions

```kotlin
// fsm/States.kt
sealed interface BotState : State {
    override val context: IdChatIdentifier

    // Registration flow
    data class AwaitingName(override val context: IdChatIdentifier) : BotState
    data class AwaitingEmail(override val context: IdChatIdentifier, val name: String) : BotState
    data class AwaitingConfirmation(
        override val context: IdChatIdentifier,
        val name: String,
        val email: String
    ) : BotState

    // Feedback flow
    data class AwaitingFeedback(override val context: IdChatIdentifier) : BotState
    data class AwaitingRating(override val context: IdChatIdentifier, val feedback: String) : BotState
}
```

### State Handlers

```kotlin
// fsm/StateHandlers.kt
suspend fun BehaviourContextWithFSM<BotState>.setupRegistrationFlow() {

    onCommand("register") { startChain(BotState.AwaitingName(it.chat.id)) }

    strictlyOn<BotState.AwaitingName> { state ->
        send(state.context, "Enter your name:", replyMarkup = ReplyKeyboards.cancel())

        val response = waitTextOrCancel(state.context) ?: return@strictlyOn null
        if (response.length < 2) {
            send(state.context, "Name too short. Try again:")
            return@strictlyOn state
        }

        BotState.AwaitingEmail(state.context, response)
    }

    strictlyOn<BotState.AwaitingEmail> { state ->
        send(state.context, "Enter your email:")

        val response = waitTextOrCancel(state.context) ?: return@strictlyOn null
        if (!response.contains("@")) {
            send(state.context, "Invalid email. Try again:")
            return@strictlyOn state
        }

        BotState.AwaitingConfirmation(state.context, state.name, response)
    }

    strictlyOn<BotState.AwaitingConfirmation> { state ->
        send(state.context, buildEntities {
            +"Confirm registration:\n\n"
            bold("Name: ") + state.name + "\n"
            bold("Email: ") + state.email
        }, replyMarkup = ReplyKeyboards.yesNo())

        val response = waitTextOrCancel(state.context) ?: return@strictlyOn null
        when (response) {
            "✅ Yes" -> {
                userService.register(state.name, state.email)
                send(state.context, "✅ Registered!", replyMarkup = ReplyKeyboards.main())
            }
            else -> send(state.context, "❌ Cancelled", replyMarkup = ReplyKeyboards.main())
        }
        null
    }
}

// Helper function
private suspend fun BehaviourContextWithFSM<BotState>.waitTextOrCancel(
    chatId: IdChatIdentifier
): String? {
    val message = waitText { it.chat.id == chatId }.first()
    return if (message.content.text == "❌ Cancel") {
        send(chatId, "Cancelled", replyMarkup = ReplyKeyboards.main())
        null
    } else {
        message.content.text
    }
}
```

## Dependency Injection

### Decision tree

| Deployment | DI choice |
|---|---|
| Standalone bot (own JVM process, just bot logic + HTTP client) | **Metro** |
| Bot is part of a Spring Boot backend (shares DB, services, observability with REST/gRPC layer) | **Spring DI** |
| Bot is part of a KMP monostack with mobile + web on Metro | **Metro** (single DI everywhere) |
| Bot is a Ktor server with embedded handlers | Metro |

The discriminator is "is there already a DI container running in this process?". If yes (Spring), use it. If no, use Metro.

### Metro variant (standalone)

```kotlin
// di/BotPlatformModule.kt
@BindingContainer
object BotPlatformModule {
    @Provides
    fun provideBotConfig(): BotConfig = BotConfig(
        token = System.getenv("BOT_TOKEN") ?: error("BOT_TOKEN not set"),
        backendUrl = System.getenv("BACKEND_URL") ?: error("BACKEND_URL not set"),
        apiKey = System.getenv("API_KEY") ?: error("API_KEY not set"),
    )

    @Provides
    fun provideTelegramBot(config: BotConfig): TelegramBot = telegramBot(config.token)

    @Provides
    fun provideJson(): Json = Json { ignoreUnknownKeys = true }

    @Provides
    fun provideHttpClient(config: BotConfig, json: Json): HttpClient = HttpClient(CIO) {
        install(ContentNegotiation) { json(json) }
        install(HttpTimeout) { requestTimeoutMillis = 30_000 }
        defaultRequest {
            url(config.backendUrl)
            header("X-API-Key", config.apiKey)
        }
    }
}

// di/BotGraph.kt
@DependencyGraph(bindingContainers = [BotPlatformModule::class])
interface BotGraph {
    val telegramBot: TelegramBot
    val commandHandlers: CommandHandlers
    val messageHandlers: MessageHandlers
    val callbackHandlers: CallbackHandlers
    val mediaHandlers: MediaHandlers
}

// Services and handlers carry @Inject — Metro auto-wires:
@Inject class UserService(private val api: BackendApiService)
@Inject class BackendApiService(private val httpClient: HttpClient, private val json: Json)
// CommandHandlers, etc. — see "Handler Modules" above
```

`createGraph<BotGraph>()` is called once in `main()`. The graph instance is process-wide; the bot lives until SIGTERM. No graph teardown needed unless you have per-update scopes (which you usually don't — handlers are stateless).

> **Per-message scope?** Telegram updates are inherently stateless from the bot's perspective. If you need per-update context (request ID, user-scoped logger), pass it through the DSL closure or `BehaviourContext` extensions — don't reach for `@AssistedInject` unless you have a real reason. Most bots never need it.

### Spring Boot variant (embedded in backend)

When the bot lives inside a full Spring Boot service (sharing JPA repositories, business services, Micrometer metrics, the same `application.yml`), use Spring DI directly. No Metro on top.

```kotlin
// config/TelegramBotConfig.kt
@ConfigurationProperties(prefix = "telegram")
data class TelegramProperties(
    val token: String,
    val adminIds: List<Long> = emptyList(),
)

@Configuration
@EnableConfigurationProperties(TelegramProperties::class)
class TelegramBotConfig {
    @Bean
    fun telegramBot(props: TelegramProperties): TelegramBot = telegramBot(props.token)
}

// handlers/CommandHandlers.kt
@Component
class CommandHandlers(
    private val userService: UserService,         // @Service from main backend
    private val orderRepository: OrderRepository, // @Repository from JPA layer
) {
    suspend fun BehaviourContext.register() {
        onCommand("start") { /* ... */ }
        onCommand("orders") { message ->
            val orders = orderRepository.findRecent(message.chat.id.chatId)
            reply(message, formatOrders(orders))
        }
    }
}

// BotService.kt — owns bot lifecycle as a Spring bean
@Service
class BotService(
    private val bot: TelegramBot,
    private val commandHandlers: CommandHandlers,
    private val callbackHandlers: CallbackHandlers,
) {
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    @PostConstruct
    fun start() {
        scope.launch {
            bot.buildBehaviourWithLongPolling {
                with(commandHandlers) { register() }
                with(callbackHandlers) { register() }
            }.join()
        }
    }

    @PreDestroy
    fun stop() = scope.cancel()
}
```

This variant gives you transactions (`@Transactional` on services called from handlers), metrics (`@Timed`), shared connection pools, and unified logging out of the box. The price is the Spring runtime — don't pick this for a standalone bot.

For Spring patterns themselves, see `kotlin-spring-boot` and `kotlin-spring-patterns` skills.

## Useful Extensions

```kotlin
// utils/Extensions.kt

// User display name
val CommonMessage<*>.userDisplayName: String
    get() = chat.asPrivateChat()?.let {
        listOfNotNull(it.firstName, it.lastName).joinToString(" ").ifEmpty { "User" }
    } ?: "User"

// Safe callback answer
suspend fun BehaviourContext.safeAnswer(
    query: CallbackQuery,
    text: String? = null,
    showAlert: Boolean = false
) = runCatching { answer(query, text, showAlert) }

// Edit or send new
suspend fun BehaviourContext.editOrSend(
    query: DataCallbackQuery,
    text: String,
    replyMarkup: InlineKeyboardMarkup? = null
) {
    runCatching {
        edit(query.message!!, text, replyMarkup = replyMarkup)
    }.onFailure {
        send(query.message!!.chat, text, replyMarkup = replyMarkup)
    }
}

// Chunked message sending
suspend fun BehaviourContext.sendLongMessage(
    chatId: IdChatIdentifier,
    text: String,
    chunkSize: Int = 4000
) {
    text.chunked(chunkSize).forEach { chunk ->
        sendMessage(chatId, chunk)
        delay(50)
    }
}

// Admin check
suspend fun BehaviourContext.isAdmin(chatId: IdChatIdentifier, userId: UserId): Boolean {
    return runCatching {
        val member = getChatMember(chatId, userId)
        member is Administrator || member is Creator
    }.getOrDefault(false)
}
```

## Error Handling Pattern

```kotlin
// utils/ErrorHandling.kt
class BotException(message: String, val userMessage: String = message) : Exception(message)
class ValidationException(message: String) : BotException(message)
class NotFoundException(message: String) : BotException(message, "Not found")

suspend fun BehaviourContext.withErrorHandling(
    message: CommonMessage<*>,
    block: suspend () -> Unit
) {
    try {
        block()
    } catch (e: ValidationException) {
        reply(message, "⚠️ ${e.userMessage}")
    } catch (e: NotFoundException) {
        reply(message, "❌ ${e.userMessage}")
    } catch (e: BotException) {
        reply(message, "❌ ${e.userMessage}")
    } catch (e: Exception) {
        logger.error("Unexpected error", e)
        reply(message, "❌ Something went wrong")
    }
}

// Usage
onCommand("action") { message ->
    withErrorHandling(message) {
        val result = service.performAction()
        reply(message, "✅ Done: $result")
    }
}
```

## Rate Limiter

```kotlin
// utils/RateLimiter.kt
class RateLimiter(private val maxRequests: Int = 30) {
    private val semaphore = Semaphore(maxRequests)

    suspend fun <T> withLimit(block: suspend () -> T): T {
        return semaphore.withPermit { block() }
    }
}

// Broadcast helper
suspend fun BehaviourContext.broadcast(
    userIds: List<Long>,
    text: String,
    rateLimiter: RateLimiter = RateLimiter(25)
): BroadcastResult {
    var success = 0
    var failed = 0

    userIds.forEach { userId ->
        rateLimiter.withLimit {
            runCatching {
                sendMessage(ChatId(userId), text)
                success++
            }.onFailure { failed++ }
        }
    }

    return BroadcastResult(success, failed)
}

data class BroadcastResult(val success: Int, val failed: Int)
```

## Testing Pattern

```kotlin
// Test with MockK
class CommandHandlersTest {
    private val mockBot = mockk<TelegramBot>(relaxed = true)

    @Test
    fun `start command sends welcome`() = runTest {
        val message = createTestMessage("/start")

        coEvery { mockBot.execute(any<SendTextMessage>()) } returns mockk()

        testBehaviourContext(mockBot) {
            setupCommandHandlers()
            // trigger handler
        }

        coVerify {
            mockBot.execute(match<SendTextMessage> {
                it.text.contains("Welcome")
            })
        }
    }
}

// Test helper
suspend fun testBehaviourContext(
    bot: TelegramBot,
    block: suspend BehaviourContext.() -> Unit
) {
    bot.buildBehaviour { block() }
}
```

## Integration with other skills

| Skill | When to load |
|---|---|
| `ktgbotapi` | Always — base bot API (BotToken, behaviour DSL, message types). |
| `metro-di-mobile` | Standalone bot DI variant. |
| `kotlin-spring-boot`, `kotlin-spring-patterns` | Embedded-in-backend variant — service layer, transactions, observability. |
| `ktor-client` | All HTTP calls to backend / external APIs. |
