# WorkManager Constraints

Detailed guide for constraint types, combinations, and platform-specific behavior.

## Constraint Types

### Network Constraints

```kotlin
// Any network connection
Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .build()

// Unmetered network only (WiFi or unlimited data)
Constraints.Builder()
    .setRequiredNetworkType(NetworkType.UNMETERED)
    .build()

// No network required
Constraints.Builder()
    .setRequiredNetworkType(NetworkType.NOT_REQUIRED)
    .build()

// Not roaming (API 24+)
Constraints.Builder()
    .setRequiredNetworkType(NetworkType.NOT_ROAMING)
    .build()

// Metered network (API 26+)
Constraints.Builder()
    .setRequiredNetworkType(NetworkType.METERED)
    .build()

// Temporarily unmetered (API 30+)
// WiFi or temporarily unmetered cellular
Constraints.Builder()
    .setRequiredNetworkType(NetworkType.TEMPORARILY_UNMETERED)
    .build()
```

### Battery Constraints

```kotlin
// Battery not low (>15%)
Constraints.Builder()
    .setRequiresBatteryNotLow(true)
    .build()

// Device charging
Constraints.Builder()
    .setRequiresCharging(true)
    .build()

// Combine both
Constraints.Builder()
    .setRequiresBatteryNotLow(true)
    .setRequiresCharging(true)
    .build()
```

### Storage Constraints

```kotlin
// Storage not low
Constraints.Builder()
    .setRequiresStorageNotLow(true)
    .build()
```

### Device State Constraints

```kotlin
// Device idle (API 23+)
// Device is idle and not in use
Constraints.Builder()
    .setRequiresDeviceIdle(true)
    .build()
```

### Content URI Triggers (API 24+)

```kotlin
// Trigger when content changes
val constraints = Constraints.Builder()
    .addContentUriTrigger(
        uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
        triggerForDescendants = true
    )
    .setTriggerContentMaxDelay(5, TimeUnit.MINUTES)
    .setTriggerContentUpdateDelay(1, TimeUnit.SECONDS)
    .build()

// Use case: Process new photos
class PhotoProcessWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val uris = inputData.getStringArray(CONTENT_URI_TRIGGERS_KEY)
        uris?.forEach { uriString ->
            processPhoto(Uri.parse(uriString))
        }
        return Result.success()
    }
}
```

## Common Constraint Combinations

### Background Sync Pattern

```kotlin
// Sync when WiFi available and battery not low
val syncConstraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.UNMETERED)
    .setRequiresBatteryNotLow(true)
    .build()

val syncRequest = PeriodicWorkRequestBuilder<SyncWorker>(
    repeatInterval = 1,
    repeatIntervalTimeUnit = TimeUnit.HOURS
)
    .setConstraints(syncConstraints)
    .build()
```

### Upload Pattern

```kotlin
// Upload when network available
val uploadConstraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .setRequiresStorageNotLow(true)
    .build()

val uploadRequest = OneTimeWorkRequestBuilder<UploadWorker>()
    .setConstraints(uploadConstraints)
    .build()
```

### Heavy Processing Pattern

```kotlin
// Process when charging, idle, and WiFi connected
val processingConstraints = Constraints.Builder()
    .setRequiresCharging(true)
    .setRequiresDeviceIdle(true)
    .setRequiredNetworkType(NetworkType.UNMETERED)
    .build()

val processRequest = OneTimeWorkRequestBuilder<VideoProcessingWorker>()
    .setConstraints(processingConstraints)
    .build()
```

### Low-Priority Background Task

```kotlin
// Run when device is charging overnight
val lowPriorityConstraints = Constraints.Builder()
    .setRequiresCharging(true)
    .setRequiresBatteryNotLow(true)
    .setRequiredNetworkType(NetworkType.UNMETERED)
    .build()

val cleanupRequest = PeriodicWorkRequestBuilder<CleanupWorker>(
    repeatInterval = 1,
    repeatIntervalTimeUnit = TimeUnit.DAYS
)
    .setConstraints(lowPriorityConstraints)
    .build()
```

## Platform-Specific Behavior

### Android 6.0+ (API 23)

- Doze mode can significantly delay work
- `setRequiresDeviceIdle()` available
- Battery optimization affects execution

### Android 7.0+ (API 24)

- Content URI triggers available
- Background execution limits begin
- `NetworkType.NOT_ROAMING` available

### Android 8.0+ (API 26)

- Background service limitations
- `NetworkType.METERED` available
- Execution limits stricter

### Android 10+ (API 29)

- Background location restrictions
- Scoped storage affects file access

### Android 11+ (API 30)

- `NetworkType.TEMPORARILY_UNMETERED` available
- One-time permissions affect location work

### Android 12+ (API 31)

- Alarm and exact scheduling restrictions
- Expedited work available
- More aggressive battery restrictions

## Constraint Priority

When multiple constraints are set, ALL must be satisfied for work to run:

```kotlin
// Work runs ONLY when:
// - Battery is NOT low AND
// - Device is charging AND
// - WiFi is connected
val strictConstraints = Constraints.Builder()
    .setRequiresBatteryNotLow(true)
    .setRequiresCharging(true)
    .setRequiredNetworkType(NetworkType.UNMETERED)
    .build()
```

## Constraint Evaluation

### Immediate Check

```kotlin
// Check if constraints are currently met
val workManager = WorkManager.getInstance(context)
val workInfo = workManager.getWorkInfoById(workId).get()

if (workInfo.state == WorkInfo.State.ENQUEUED) {
    // Work is waiting for constraints
}
```

### Dynamic Constraints

Constraints cannot be changed after work is enqueued. To change constraints:

```kotlin
// Cancel old work
WorkManager.getInstance(context).cancelUniqueWork("sync")

// Enqueue new work with updated constraints
val newConstraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .build()

val newRequest = OneTimeWorkRequestBuilder<SyncWorker>()
    .setConstraints(newConstraints)
    .build()

WorkManager.getInstance(context)
    .enqueueUniqueWork("sync", ExistingWorkPolicy.REPLACE, newRequest)
```

## Testing Constraints

### Simulate Constraints in Tests

```kotlin
@Test
fun testConstraints() = runTest {
    val context = ApplicationProvider.getApplicationContext<Context>()

    // Set network constraint
    val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .build()

    val request = OneTimeWorkRequestBuilder<SyncWorker>()
        .setConstraints(constraints)
        .build()

    val workManager = WorkManager.getInstance(context)
    workManager.enqueue(request).result.get()

    // Simulate network available
    val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!
    testDriver.setAllConstraintsMet(request.id)

    // Wait for work to complete
    val workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
}
```

## Troubleshooting Constraints

### Work Not Running

1. Check constraint status in logs
2. Verify all constraints are met simultaneously
3. Check device battery optimization settings
4. Test without constraints to isolate issue

### Network Constraint Not Working

```kotlin
// Debug network state
val connectivityManager = context.getSystemService<ConnectivityManager>()
val network = connectivityManager?.activeNetwork
val capabilities = connectivityManager?.getNetworkCapabilities(network)

Log.d("WorkManager", "Network available: ${network != null}")
Log.d("WorkManager", "WiFi: ${capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)}")
Log.d("WorkManager", "Cellular: ${capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)}")
```

### Battery Constraint Issues

- Some manufacturers override battery status
- User may have disabled battery optimization
- Check Settings > Apps > Special Access > Battery optimization

### Best Practices

- Use minimum necessary constraints
- Test constraints on different devices
- Provide user feedback when waiting for constraints
- Consider fallback for time-critical work
- Log constraint status for debugging
