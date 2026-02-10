# WorkManager Troubleshooting

Solutions to common WorkManager problems and debugging strategies.

## Work Not Executing

### Problem: Work stays in ENQUEUED state

**Causes:**
1. Constraints not met
2. Battery optimization enabled for app
3. Doze mode restrictions
4. WorkManager not initialized

**Solutions:**

```kotlin
// 1. Check constraint status
val workManager = WorkManager.getInstance(context)
val workInfo = workManager.getWorkInfoById(workId).get()

Log.d("WorkManager", "State: ${workInfo.state}")
Log.d("WorkManager", "Constraints: ${workInfo.constraints}")

// 2. Test without constraints
val request = OneTimeWorkRequestBuilder<SyncWorker>()
    // Remove .setConstraints()
    .build()

// 3. Check battery optimization
fun checkBatteryOptimization() {
    val powerManager = context.getSystemService<PowerManager>()
    val packageName = context.packageName

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        if (!powerManager?.isIgnoringBatteryOptimizations(packageName)!!) {
            // Request to ignore battery optimization
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            context.startActivity(intent)
        }
    }
}

// 4. Verify WorkManager initialization
class MyApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.DEBUG) // Enable debug logging
            .build()
}
```

### Problem: Periodic work not running at expected interval

**Causes:**
1. Interval < 15 minutes
2. Doze mode delays
3. App in standby bucket

**Solutions:**

```kotlin
// 1. Verify minimum interval
val request = PeriodicWorkRequestBuilder<SyncWorker>(
    repeatInterval = 15, // Minimum is 15 minutes
    repeatIntervalTimeUnit = TimeUnit.MINUTES
).build()

// 2. Use flex interval for more control
val flexRequest = PeriodicWorkRequestBuilder<SyncWorker>(
    repeatInterval = 1,
    repeatIntervalTimeUnit = TimeUnit.HOURS,
    flexTimeInterval = 15, // Run within last 15 minutes of hour
    flexTimeIntervalUnit = TimeUnit.MINUTES
).build()

// 3. Check app standby bucket
fun checkStandbyBucket() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val usageStatsManager = context.getSystemService<UsageStatsManager>()
        val bucket = usageStatsManager?.appStandbyBucket

        when (bucket) {
            UsageStatsManager.STANDBY_BUCKET_ACTIVE -> Log.d("Standby", "Active")
            UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> Log.d("Standby", "Working set")
            UsageStatsManager.STANDBY_BUCKET_FREQUENT -> Log.d("Standby", "Frequent")
            UsageStatsManager.STANDBY_BUCKET_RARE -> Log.d("Standby", "Rare - severely limited")
            UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> Log.d("Standby", "Restricted")
        }
    }
}
```

## Constraints Not Working

### Problem: Work runs without network despite constraint

**Causes:**
1. Incorrect constraint type
2. Network check happens at enqueue time
3. Constraint satisfied briefly

**Solutions:**

```kotlin
// 1. Use correct network type
val constraints = Constraints.Builder()
    .setRequiredNetworkType(NetworkType.CONNECTED) // Any network
    // or
    .setRequiredNetworkType(NetworkType.UNMETERED) // WiFi only
    .build()

// 2. Verify network in Worker
class SyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // Double-check network availability
        if (!isNetworkAvailable()) {
            return Result.retry()
        }

        return try {
            performSync()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = applicationContext
            .getSystemService<ConnectivityManager>()

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = connectivityManager?.activeNetwork
            val capabilities = connectivityManager?.getNetworkCapabilities(network)
            capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        } else {
            @Suppress("DEPRECATION")
            connectivityManager?.activeNetworkInfo?.isConnected == true
        }
    }
}
```

### Problem: Battery constraint never satisfied

**Causes:**
1. Device never reaches "battery not low" threshold (>15%)
2. Manufacturer-specific battery management

**Solutions:**

```kotlin
// 1. Check actual battery level
fun checkBatteryLevel() {
    val batteryManager = context.getSystemService<BatteryManager>()
    val batteryLevel = batteryManager?.getIntProperty(
        BatteryManager.BATTERY_PROPERTY_CAPACITY
    ) ?: 0

    Log.d("Battery", "Current level: $batteryLevel%")

    // WorkManager considers battery low when < 15%
    val isBatteryLow = batteryLevel < 15
    Log.d("Battery", "Battery low: $isBatteryLow")
}

// 2. Use less strict constraint
val constraints = Constraints.Builder()
    // Remove battery constraint if too restrictive
    .setRequiredNetworkType(NetworkType.CONNECTED)
    .build()

// 3. Use expedited work for important tasks (Android 12+)
val request = OneTimeWorkRequestBuilder<ImportantWorker>()
    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
    .build()
```

## Work Retrying Indefinitely

### Problem: Worker keeps retrying without success

**Causes:**
1. No max retry limit set
2. Transient errors treated as permanent
3. Incorrect retry logic

**Solutions:**

```kotlin
class SyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            performSync()
            Result.success()
        } catch (e: NetworkException) {
            // Limit retries
            if (runAttemptCount >= MAX_RETRIES) {
                Log.e(TAG, "Max retries reached, failing permanently")
                return Result.failure(
                    workDataOf("error" to "Max retries exceeded")
                )
            }

            Log.w(TAG, "Network error, retry attempt $runAttemptCount")
            Result.retry()
        } catch (e: InvalidDataException) {
            // Don't retry on permanent errors
            Log.e(TAG, "Invalid data, failing permanently")
            Result.failure(workDataOf("error" to e.message))
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error", e)
            if (runAttemptCount >= MAX_RETRIES) {
                Result.failure()
            } else {
                Result.retry()
            }
        }
    }

    companion object {
        private const val TAG = "SyncWorker"
        private const val MAX_RETRIES = 3
    }
}

// Set custom backoff policy
val request = OneTimeWorkRequestBuilder<SyncWorker>()
    .setBackoffCriteria(
        BackoffPolicy.EXPONENTIAL,
        WorkRequest.MIN_BACKOFF_MILLIS, // 10 seconds
        TimeUnit.MILLISECONDS
    )
    .build()
```

### Problem: Backoff delay too long

**Solutions:**

```kotlin
// Use LINEAR backoff for shorter delays
val request = OneTimeWorkRequestBuilder<SyncWorker>()
    .setBackoffCriteria(
        BackoffPolicy.LINEAR,
        10, // 10 seconds
        TimeUnit.SECONDS
    )
    .build()

// EXPONENTIAL: 10s, 20s, 40s, 80s, ...
// LINEAR: 10s, 20s, 30s, 40s, ...
```

## Dependency Injection Issues

### Problem: DI not working in Workers

**Causes:**
1. Custom WorkerFactory not set
2. Factory not returning worker instance
3. Wrong DI scope

**Solutions:**

```kotlin
// 1. Implement WorkerFactory
class AppWorkerFactory(
    private val repository: SyncRepository,
    private val uploader: FileUploader
) : WorkerFactory() {

    override fun createWorker(
        appContext: Context,
        workerClassName: String,
        workerParameters: WorkerParameters
    ): ListenableWorker? {
        return when (workerClassName) {
            SyncWorker::class.java.name ->
                SyncWorker(appContext, workerParameters, repository)

            UploadWorker::class.java.name ->
                UploadWorker(appContext, workerParameters, uploader)

            else -> null // Return null for unknown workers
        }
    }
}

// 2. Configure in Application
class MyApplication : Application(), Configuration.Provider {

    private lateinit var workerFactory: AppWorkerFactory

    override fun onCreate() {
        super.onCreate()

        // Initialize DI
        val graph = AppGraph.create(this)
        workerFactory = graph.workerFactory
    }

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .build()
}

// 3. Add to AndroidManifest.xml
// <application
//     android:name=".MyApplication"
//     tools:node="merge">
//     <provider
//         android:name="androidx.startup.InitializationProvider"
//         android:authorities="${applicationId}.androidx-startup"
//         tools:node="remove" />
// </application>

// 4. Verify factory is called
class AppWorkerFactory(
    private val repository: SyncRepository
) : WorkerFactory() {

    override fun createWorker(
        appContext: Context,
        workerClassName: String,
        workerParameters: WorkerParameters
    ): ListenableWorker? {
        Log.d("WorkerFactory", "Creating worker: $workerClassName")

        return when (workerClassName) {
            SyncWorker::class.java.name -> {
                Log.d("WorkerFactory", "Injecting dependencies into SyncWorker")
                SyncWorker(appContext, workerParameters, repository)
            }
            else -> {
                Log.w("WorkerFactory", "Unknown worker: $workerClassName")
                null
            }
        }
    }
}
```

## Data Size Limitations

### Problem: WorkData size exceeded

**Causes:**
1. Passing large data through WorkData
2. Exceeding 10KB limit

**Solutions:**

```kotlin
// DON'T: Pass large data directly
val largeData = generateLargeJsonString() // 50KB
val request = OneTimeWorkRequestBuilder<ProcessWorker>()
    .setInputData(workDataOf("data" to largeData)) // FAILS
    .build()

// DO: Save to file and pass file path
fun enqueueLargeDataWork(data: String) {
    // Save to file
    val file = File(context.cacheDir, "work_data_${UUID.randomUUID()}.json")
    file.writeText(data)

    val request = OneTimeWorkRequestBuilder<ProcessWorker>()
        .setInputData(workDataOf("file_path" to file.absolutePath))
        .build()

    WorkManager.getInstance(context).enqueue(request)
}

class ProcessWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val filePath = inputData.getString("file_path") ?: return Result.failure()

        val file = File(filePath)
        val data = file.readText()

        // Process data
        processData(data)

        // Clean up
        file.delete()

        return Result.success()
    }
}

// DO: Use database for complex data
fun enqueueWithDatabaseReference(dataId: Long) {
    val request = OneTimeWorkRequestBuilder<ProcessWorker>()
        .setInputData(workDataOf("data_id" to dataId))
        .build()

    WorkManager.getInstance(context).enqueue(request)
}

class ProcessWorker(
    context: Context,
    params: WorkerParameters,
    private val database: AppDatabase
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val dataId = inputData.getLong("data_id", -1)
        if (dataId == -1L) return Result.failure()

        val data = database.dao().getDataById(dataId)
        processData(data)

        return Result.success()
    }
}
```

## Debugging Strategies

### Enable Debug Logging

```kotlin
class MyApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setMinimumLoggingLevel(Log.DEBUG)
            .build()
}

// View logs
// adb logcat | grep WorkManager
```

### Inspect WorkManager Database

```kotlin
fun inspectWorkManagerDatabase(context: Context) {
    val database = WorkDatabase.create(
        context,
        context.defaultSharedExecutor,
        true
    )

    // Query all work
    val workSpecs = database.workSpecDao().getAllWorkSpecs()

    workSpecs.forEach { spec ->
        Log.d("WorkManager", """
            ID: ${spec.id}
            State: ${spec.state}
            Worker: ${spec.workerClassName}
            Run Attempt: ${spec.runAttemptCount}
            Constraints: ${spec.constraints}
        """.trimIndent())
    }

    database.close()
}
```

### Use WorkManager Inspector (Android Studio)

1. Open Android Studio
2. View > Tool Windows > App Inspection
3. Select WorkManager tab
4. View all scheduled work, states, and constraints

### Monitor Work Status

```kotlin
fun monitorAllWork(context: Context) {
    WorkManager.getInstance(context)
        .getWorkInfosByTagLiveData("monitoring")
        .observeForever { workInfos ->
            workInfos.forEach { workInfo ->
                Log.d("WorkMonitor", """
                    ID: ${workInfo.id}
                    State: ${workInfo.state}
                    Run Attempt: ${workInfo.runAttemptCount}
                    Output: ${workInfo.outputData}
                    Tags: ${workInfo.tags}
                """.trimIndent())
            }
        }
}
```

## Performance Issues

### Problem: Too many workers enqueued

**Solutions:**

```kotlin
// Use unique work to prevent duplicates
WorkManager.getInstance(context)
    .enqueueUniqueWork(
        "sync_work",
        ExistingWorkPolicy.KEEP, // Don't enqueue if already exists
        syncRequest
    )

// Cancel old work before enqueuing new
WorkManager.getInstance(context).apply {
    cancelAllWorkByTag("sync")
    enqueue(newSyncRequest)
}

// Prune completed work
WorkManager.getInstance(context).pruneWork()
```

### Problem: Worker taking too long

**Solutions:**

```kotlin
class LongRunningWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // Set as foreground for long operations (>10 min)
        setForeground(createForegroundInfo())

        return withContext(Dispatchers.IO) {
            // Use appropriate dispatcher
            performLongOperation()
            Result.success()
        }
    }

    private fun createForegroundInfo(): ForegroundInfo {
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle("Processing")
            .setSmallIcon(R.drawable.ic_work)
            .setOngoing(true)
            .build()

        return ForegroundInfo(NOTIFICATION_ID, notification)
    }
}

// Split work into smaller chunks
fun enqueueChunkedWork(items: List<Item>) {
    val chunks = items.chunked(100)

    chunks.forEachIndexed { index, chunk ->
        val request = OneTimeWorkRequestBuilder<ProcessChunkWorker>()
            .setInputData(workDataOf(
                "chunk_index" to index,
                "item_ids" to chunk.map { it.id }.toLongArray()
            ))
            .build()

        WorkManager.getInstance(context).enqueue(request)
    }
}
```

## Common Error Messages

### "IllegalStateException: WorkManager is not initialized"

```kotlin
// Ensure Application implements Configuration.Provider
class MyApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder().build()
}
```

### "java.lang.IllegalArgumentException: Cannot set backoff criteria on an already-built WorkRequest"

```kotlin
// Set backoff BEFORE building
val request = OneTimeWorkRequestBuilder<SyncWorker>()
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 10, TimeUnit.SECONDS)
    .build() // Build after setting criteria
```

### "Data cannot occupy more than 10240 bytes when serialized"

```kotlin
// Use file paths or database IDs instead of large data
// See "Data Size Limitations" section above
```

## Device-Specific Issues

### Xiaomi/MIUI Battery Optimization

```kotlin
// Request autostart permission
fun requestMiuiAutoStart() {
    try {
        val intent = Intent().apply {
            component = ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
        }
        context.startActivity(intent)
    } catch (e: Exception) {
        // Fallback to battery settings
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
        }
        context.startActivity(intent)
    }
}
```

### Samsung/Huawei Background Restrictions

- Guide users to disable battery optimization
- Use foreground services for critical work
- Consider alternative scheduling mechanisms

## Best Practices for Debugging

1. **Enable debug logging** during development
2. **Use unique work names** for easier tracking
3. **Add tags** to group related work
4. **Log state transitions** in Workers
5. **Monitor WorkManager database** for stuck work
6. **Test on multiple devices** with different manufacturers
7. **Use WorkManager Inspector** in Android Studio
8. **Check battery optimization** settings
9. **Verify constraints** are appropriate for use case
10. **Handle errors explicitly** with proper Result types
