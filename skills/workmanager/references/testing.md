# WorkManager Testing

Complete guide for testing Workers, constraints, chains, and integration scenarios.

## Table of Contents

- Test Dependencies
- Basic Worker Testing
- Testing with Dependencies
- Testing Constraints
- Testing Chains
- Testing Periodic Work
- Integration Testing

## Test Dependencies

### build.gradle.kts

```kotlin
dependencies {
    // WorkManager
    implementation("androidx.work:work-runtime-ktx:2.9.0")

    // Testing
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.7.3")
    testImplementation("androidx.work:work-testing:2.9.0")
    testImplementation("androidx.test:core:1.5.0")
    testImplementation("androidx.test.ext:junit:1.1.5")
    testImplementation("org.robolectric:robolectric:4.11.1")

    androidTestImplementation("androidx.work:work-testing:2.9.0")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
}
```

## Basic Worker Testing

### Unit Test with TestListenableWorkerBuilder

```kotlin
@RunWith(RobolectricTestRunner::class)
class SyncWorkerTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
    }

    @Test
    fun testSyncWorker_success() = runTest {
        // Create worker instance
        val worker = TestListenableWorkerBuilder<SyncWorker>(context)
            .build()

        // Execute worker
        val result = worker.doWork()

        // Assert success
        assertThat(result).isEqualTo(Result.success())
    }

    @Test
    fun testSyncWorker_withInputData() = runTest {
        val inputData = workDataOf(
            SyncWorker.KEY_USER_ID to 123L,
            SyncWorker.KEY_SYNC_TYPE to "full"
        )

        val worker = TestListenableWorkerBuilder<SyncWorker>(context)
            .setInputData(inputData)
            .build()

        val result = worker.doWork()

        assertThat(result).isInstanceOf(Result.Success::class.java)

        val outputData = (result as Result.Success).outputData
        assertThat(outputData.getLong(SyncWorker.KEY_TIMESTAMP, 0L)).isGreaterThan(0L)
    }

    @Test
    fun testSyncWorker_failure() = runTest {
        // Test worker with invalid input
        val worker = TestListenableWorkerBuilder<SyncWorker>(context)
            .setInputData(workDataOf(SyncWorker.KEY_USER_ID to -1L))
            .build()

        val result = worker.doWork()

        assertThat(result).isInstanceOf(Result.Failure::class.java)
    }

    @Test
    fun testSyncWorker_retry() = runTest {
        val worker = TestListenableWorkerBuilder<SyncWorker>(context)
            .setRunAttemptCount(1) // Simulate retry
            .build()

        val result = worker.doWork()

        // Assuming worker retries on transient failures
        assertThat(result).isInstanceOf(Result.Retry::class.java)
    }
}
```

### Testing Worker with Progress

```kotlin
@Test
fun testDownloadWorker_progress() = runTest {
    val worker = TestListenableWorkerBuilder<DownloadWorker>(context)
        .setInputData(workDataOf(DownloadWorker.KEY_URL to "https://example.com/file.zip"))
        .build()

    // Track progress updates
    val progressUpdates = mutableListOf<Int>()

    val job = launch {
        WorkManager.getInstance(context)
            .getWorkInfoByIdFlow(worker.id)
            .collect { workInfo ->
                val progress = workInfo?.progress?.getInt(DownloadWorker.KEY_PROGRESS, 0) ?: 0
                if (progress > 0) {
                    progressUpdates.add(progress)
                }
            }
    }

    val result = worker.doWork()

    job.cancel()

    assertThat(result).isEqualTo(Result.success())
    assertThat(progressUpdates).isNotEmpty()
    assertThat(progressUpdates.last()).isEqualTo(100)
}
```

## Testing with Dependencies

### Using TestWorkerFactory

```kotlin
@RunWith(RobolectricTestRunner::class)
class SyncWorkerWithDITest {

    private lateinit var context: Context
    private lateinit var mockRepository: SyncRepository

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        mockRepository = mock()

        // Configure test WorkManager with custom factory
        val config = Configuration.Builder()
            .setMinimumLoggingLevel(Log.DEBUG)
            .setExecutor(SynchronousExecutor())
            .setWorkerFactory(TestWorkerFactory(mockRepository))
            .build()

        WorkManagerTestInitHelper.initializeTestWorkManager(context, config)
    }

    @Test
    fun testSyncWorker_withMockRepository() = runTest {
        // Setup mock behavior
        `when`(mockRepository.sync()).thenReturn(SyncResult.Success)

        val request = OneTimeWorkRequestBuilder<SyncWorker>().build()

        val workManager = WorkManager.getInstance(context)
        workManager.enqueue(request).result.get()

        // Get work info
        val workInfo = workManager.getWorkInfoById(request.id).get()

        assertThat(workInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
        verify(mockRepository).sync()
    }
}

// Custom test worker factory
class TestWorkerFactory(
    private val repository: SyncRepository
) : WorkerFactory() {

    override fun createWorker(
        appContext: Context,
        workerClassName: String,
        workerParameters: WorkerParameters
    ): ListenableWorker? {
        return when (workerClassName) {
            SyncWorker::class.java.name ->
                SyncWorker(appContext, workerParameters, repository)
            else -> null
        }
    }
}
```

### Testing Worker with Injected Dependencies

```kotlin
class SyncWorker(
    context: Context,
    params: WorkerParameters,
    private val repository: SyncRepository = DefaultSyncRepository()
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            repository.sync()
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}

@Test
fun testSyncWorker_injectedRepository() = runTest {
    val mockRepository = mock<SyncRepository>()
    `when`(mockRepository.sync()).thenReturn(SyncResult.Success)

    val worker = SyncWorker(
        context = context,
        params = WorkerParameters(
            UUID.randomUUID(),
            workDataOf(),
            emptyList(),
            WorkerParameters.RuntimeExtras(),
            1,
            0,
            SynchronousExecutor(),
            mock(),
            mock(),
            mock()
        ),
        repository = mockRepository
    )

    val result = worker.doWork()

    assertThat(result).isEqualTo(Result.success())
    verify(mockRepository).sync()
}
```

## Testing Constraints

### Test Constraint Satisfaction

```kotlin
@Test
fun testWorker_withConstraints() {
    val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.CONNECTED)
        .setRequiresBatteryNotLow(true)
        .build()

    val request = OneTimeWorkRequestBuilder<SyncWorker>()
        .setConstraints(constraints)
        .build()

    val workManager = WorkManager.getInstance(context)
    workManager.enqueue(request).result.get()

    // Initially blocked by constraints
    val workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.state).isEqualTo(WorkInfo.State.ENQUEUED)

    // Simulate constraints met
    val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!
    testDriver.setAllConstraintsMet(request.id)

    // Wait for execution
    val updatedWorkInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(updatedWorkInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
}
```

### Test Individual Constraints

```kotlin
@Test
fun testWorker_networkConstraint() {
    val request = OneTimeWorkRequestBuilder<SyncWorker>()
        .setConstraints(
            Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
        )
        .build()

    val workManager = WorkManager.getInstance(context)
    workManager.enqueue(request).result.get()

    val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!

    // Set only network constraint
    testDriver.setAllConstraintsMet(request.id)

    val workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
}
```

## Testing Chains

### Test Sequential Chain

```kotlin
@Test
fun testWorkerChain_sequential() {
    val downloadRequest = OneTimeWorkRequestBuilder<DownloadWorker>()
        .setInputData(workDataOf("url" to "https://example.com/file.zip"))
        .build()

    val processRequest = OneTimeWorkRequestBuilder<ProcessWorker>().build()

    val uploadRequest = OneTimeWorkRequestBuilder<UploadWorker>().build()

    val workManager = WorkManager.getInstance(context)
    workManager
        .beginWith(downloadRequest)
        .then(processRequest)
        .then(uploadRequest)
        .enqueue()
        .result
        .get()

    // Verify all succeeded
    assertThat(workManager.getWorkInfoById(downloadRequest.id).get().state)
        .isEqualTo(WorkInfo.State.SUCCEEDED)
    assertThat(workManager.getWorkInfoById(processRequest.id).get().state)
        .isEqualTo(WorkInfo.State.SUCCEEDED)
    assertThat(workManager.getWorkInfoById(uploadRequest.id).get().state)
        .isEqualTo(WorkInfo.State.SUCCEEDED)
}
```

### Test Chain with Data Passing

```kotlin
@Test
fun testWorkerChain_dataFlow() {
    val downloadRequest = OneTimeWorkRequestBuilder<DownloadWorker>()
        .setInputData(workDataOf("url" to "https://example.com/data.json"))
        .build()

    val processRequest = OneTimeWorkRequestBuilder<ProcessWorker>().build()

    val workManager = WorkManager.getInstance(context)
    workManager
        .beginWith(downloadRequest)
        .then(processRequest)
        .enqueue()
        .result
        .get()

    // Verify data passed correctly
    val downloadOutput = workManager.getWorkInfoById(downloadRequest.id).get().outputData
    val filePath = downloadOutput.getString("file_path")

    val processInput = workManager.getWorkInfoById(processRequest.id).get().outputData
    // ProcessWorker should have received the file_path from DownloadWorker

    assertThat(filePath).isNotNull()
}
```

### Test Parallel Chain

```kotlin
@Test
fun testWorkerChain_parallel() {
    val compress1 = OneTimeWorkRequestBuilder<CompressWorker>()
        .setInputData(workDataOf("file" to "file1.jpg"))
        .build()

    val compress2 = OneTimeWorkRequestBuilder<CompressWorker>()
        .setInputData(workDataOf("file" to "file2.jpg"))
        .build()

    val compress3 = OneTimeWorkRequestBuilder<CompressWorker>()
        .setInputData(workDataOf("file" to "file3.jpg"))
        .build()

    val merge = OneTimeWorkRequestBuilder<MergeWorker>().build()

    val workManager = WorkManager.getInstance(context)
    workManager
        .beginWith(listOf(compress1, compress2, compress3))
        .then(merge)
        .enqueue()
        .result
        .get()

    // Verify all parallel workers succeeded
    assertThat(workManager.getWorkInfoById(compress1.id).get().state)
        .isEqualTo(WorkInfo.State.SUCCEEDED)
    assertThat(workManager.getWorkInfoById(compress2.id).get().state)
        .isEqualTo(WorkInfo.State.SUCCEEDED)
    assertThat(workManager.getWorkInfoById(compress3.id).get().state)
        .isEqualTo(WorkInfo.State.SUCCEEDED)

    // Verify merge worker received all outputs
    val mergeWorkInfo = workManager.getWorkInfoById(merge.id).get()
    assertThat(mergeWorkInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
}
```

### Test Chain Failure Handling

```kotlin
@Test
fun testWorkerChain_failureCancelsSubsequent() {
    // Create worker that will fail
    val failingRequest = OneTimeWorkRequestBuilder<FailingWorker>().build()

    val subsequentRequest = OneTimeWorkRequestBuilder<SubsequentWorker>().build()

    val workManager = WorkManager.getInstance(context)
    workManager
        .beginWith(failingRequest)
        .then(subsequentRequest)
        .enqueue()
        .result
        .get()

    // Verify first worker failed
    assertThat(workManager.getWorkInfoById(failingRequest.id).get().state)
        .isEqualTo(WorkInfo.State.FAILED)

    // Verify subsequent worker was cancelled
    assertThat(workManager.getWorkInfoById(subsequentRequest.id).get().state)
        .isEqualTo(WorkInfo.State.CANCELLED)
}
```

## Testing Periodic Work

### Test Periodic Execution

```kotlin
@Test
fun testPeriodicWorker() = runTest {
    val request = PeriodicWorkRequestBuilder<SyncWorker>(
        repeatInterval = 15,
        repeatIntervalTimeUnit = TimeUnit.MINUTES
    ).build()

    val workManager = WorkManager.getInstance(context)
    workManager.enqueue(request).result.get()

    val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!

    // Trigger first run
    testDriver.setPeriodDelayMet(request.id)

    var workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.state).isEqualTo(WorkInfo.State.ENQUEUED)

    // Trigger second run
    testDriver.setPeriodDelayMet(request.id)

    workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.runAttemptCount).isGreaterThan(0)
}
```

## Integration Testing

### Android Instrumented Test

```kotlin
@RunWith(AndroidJUnit4::class)
class WorkManagerIntegrationTest {

    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()

        val config = Configuration.Builder()
            .setMinimumLoggingLevel(Log.DEBUG)
            .build()

        WorkManagerTestInitHelper.initializeTestWorkManager(context, config)
    }

    @Test
    fun testRealWorkerExecution() {
        val request = OneTimeWorkRequestBuilder<SyncWorker>().build()

        val workManager = WorkManager.getInstance(context)
        val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!

        workManager.enqueue(request)

        testDriver.setAllConstraintsMet(request.id)

        val workInfo = workManager.getWorkInfoById(request.id).get()

        assertThat(workInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
    }

    @Test
    fun testWorkerWithRealDatabase() {
        // Test worker that actually writes to database
        val request = OneTimeWorkRequestBuilder<DatabaseWorker>()
            .setInputData(workDataOf("data" to "test_value"))
            .build()

        val workManager = WorkManager.getInstance(context)
        workManager.enqueue(request).result.get()

        // Verify data in real database
        val database = AppDatabase.getInstance(context)
        val value = database.dao().getValue()

        assertThat(value).isEqualTo("test_value")
    }
}
```

### Test with Delays

```kotlin
@Test
fun testWorker_withInitialDelay() {
    val request = OneTimeWorkRequestBuilder<SyncWorker>()
        .setInitialDelay(10, TimeUnit.MINUTES)
        .build()

    val workManager = WorkManager.getInstance(context)
    workManager.enqueue(request).result.get()

    val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!

    // Initially enqueued, not running
    var workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.state).isEqualTo(WorkInfo.State.ENQUEUED)

    // Simulate delay met
    testDriver.setInitialDelayMet(request.id)

    workInfo = workManager.getWorkInfoById(request.id).get()
    assertThat(workInfo.state).isEqualTo(WorkInfo.State.SUCCEEDED)
}
```

## Best Practices

### Do's

- Initialize WorkManager in `@Before` with test configuration
- Use `SynchronousExecutor` for synchronous test execution
- Test both success and failure scenarios
- Test retry logic with `setRunAttemptCount()`
- Use TestDriver to simulate constraint satisfaction
- Mock external dependencies (network, database)
- Test data flow between chained workers
- Verify output data correctness

### Don'ts

- Don't rely on actual timing in tests
- Don't skip testing failure cases
- Don't test with production WorkManager configuration
- Don't forget to clean up WorkManager state between tests
- Don't test workers in isolation if they depend on others
- Don't use real network calls in unit tests

## Troubleshooting

### WorkManager Not Initialized

```kotlin
// Always initialize in @Before
@Before
fun setup() {
    context = ApplicationProvider.getApplicationContext()

    val config = Configuration.Builder()
        .setExecutor(SynchronousExecutor())
        .build()

    WorkManagerTestInitHelper.initializeTestWorkManager(context, config)
}
```

### Worker Not Executing

```kotlin
// Ensure TestDriver is used to trigger execution
val testDriver = WorkManagerTestInitHelper.getTestDriver(context)!!
testDriver.setAllConstraintsMet(request.id)
```

### Race Conditions

```kotlin
// Use get() to block until work completes
workManager.enqueue(request).result.get()

// Or use awaitility
await().atMost(5, TimeUnit.SECONDS).until {
    workManager.getWorkInfoById(request.id).get().state.isFinished
}
```
