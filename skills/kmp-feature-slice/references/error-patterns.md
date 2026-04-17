# Typed Error Patterns for KMP Features

## Base Error Hierarchy

Every feature defines a sealed error hierarchy in the `api/` module:

```kotlin
// feature/<name>/api/src/commonMain/kotlin/<Name>Error.kt

sealed class <Name>Error(
    override val message: String,
    override val cause: Throwable? = null
) : Exception(message, cause) {

    // Network errors
    class NetworkError(
        cause: Throwable? = null
    ) : <Name>Error("Network error occurred", cause)

    class TimeoutError(
        cause: Throwable? = null
    ) : <Name>Error("Request timed out", cause)

    class ServerError(
        val code: Int,
        cause: Throwable? = null
    ) : <Name>Error("Server error: $code", cause)

    // Validation errors
    class ValidationError(
        val field: String,
        val reason: String
    ) : <Name>Error("Validation failed for $field: $reason")

    // Auth errors
    class UnauthorizedError(
        cause: Throwable? = null
    ) : <Name>Error("Unauthorized", cause)

    class TokenExpiredError(
        cause: Throwable? = null
    ) : <Name>Error("Token expired", cause)

    // Conflict errors
    class ConflictError(
        val resourceId: String
    ) : <Name>Error("Conflict for resource: $resourceId")

    // Not found
    class NotFoundError(
        val resourceId: String
    ) : <Name>Error("Resource not found: $resourceId")

    // Storage errors
    class StorageError(
        cause: Throwable? = null
    ) : <Name>Error("Storage error", cause)

    // Permission errors
    class PermissionDeniedError(
        val permission: String
    ) : <Name>Error("Permission denied: $permission")
}
```

## Error Selection by Feature Type

Only include error types that match the feature's `error_types` input:

| Input Error Type | Include Classes |
|------------------|----------------|
| `network` | `NetworkError`, `TimeoutError`, `ServerError` |
| `validation` | `ValidationError` |
| `auth` | `UnauthorizedError`, `TokenExpiredError` |
| `conflict` | `ConflictError` |
| `not-found` | `NotFoundError` |
| `storage` | `StorageError` |
| `permission` | `PermissionDeniedError` |

## Error Mapping in Use Cases

```kotlin
// Map exceptions to typed errors in UseCase

@Inject
class Get<Name>UseCase(
    private val repository: <Name>Repository
) {
    suspend fun execute(id: String): Result<<Name>Data> {
        return repository.getData(id).fold(
            onSuccess = { Result.success(it) },
            onError = { message, cause ->
                val error = mapError(cause)
                Result.failure(error)
            }
        )
    }

    private fun mapError(cause: Throwable?): <Name>Error {
        return when (cause) {
            is io.ktor.client.plugins.ClientRequestException -> {
                when (cause.response.status.value) {
                    401 -> <Name>Error.UnauthorizedError(cause)
                    404 -> <Name>Error.NotFoundError("")
                    409 -> <Name>Error.ConflictError("")
                    else -> <Name>Error.ServerError(cause.response.status.value, cause)
                }
            }
            is io.ktor.client.plugins.ServerResponseException ->
                <Name>Error.ServerError(cause.response.status.value, cause)
            is kotlinx.io.IOException ->
                <Name>Error.NetworkError(cause)
            else -> <Name>Error.NetworkError(cause)
        }
    }
}
```

## Error Handling in Component

```kotlin
// Component maps errors to user-visible ViewState

private fun handleError(error: Throwable) {
    val viewError = when (error) {
        is <Name>Error.NetworkError,
        is <Name>Error.TimeoutError -> ViewError(
            message = "Нет подключения к сети",
            retryable = true
        )
        is <Name>Error.UnauthorizedError,
        is <Name>Error.TokenExpiredError -> {
            onNavigate(NavigationTarget.Login)
            return
        }
        is <Name>Error.NotFoundError -> ViewError(
            message = "Данные не найдены",
            retryable = false
        )
        is <Name>Error.ServerError -> ViewError(
            message = "Ошибка сервера (${error.code})",
            retryable = true
        )
        else -> ViewError(
            message = "Неизвестная ошибка",
            retryable = true
        )
    }
    _viewState.value = <Name>ViewState.Error(viewError)
}

data class ViewError(
    val message: String,
    val retryable: Boolean
)
```

## Error Reporting Pattern

For features that need error analytics:

```kotlin
// Optional: error reporting via use case wrapper

@Inject
class ErrorReportingUseCase(
    private val analytics: AnalyticsTracker
) {
    suspend fun <T> tracked(
        featureName: String,
        block: suspend () -> Result<T>
    ): Result<T> {
        return block().also { result ->
            result.onFailure { error ->
                analytics.trackError(
                    feature = featureName,
                    errorType = error::class.simpleName ?: "Unknown",
                    message = error.message ?: ""
                )
            }
        }
    }
}
```
