# WorkManager Chaining

Advanced patterns for sequential chains, parallel execution, and complex workflows.

## Table of Contents

- Sequential Chains
- Parallel Chains
- Combined Chains
- Data Passing Between Workers
- Error Handling in Chains
- Chain Observing
- Advanced Patterns

## Sequential Chains

### Basic Sequential Chain

```kotlin
val downloadRequest = OneTimeWorkRequestBuilder<DownloadWorker>().build()
val processRequest = OneTimeWorkRequestBuilder<ProcessWorker>().build()
val uploadRequest = OneTimeWorkRequestBuilder<UploadWorker>().build()

WorkManager.getInstance(context)
    .beginWith(downloadRequest)
    .then(processRequest)
    .then(uploadRequest)
    .enqueue()
```

### Chain with Multiple Steps

```kotlin
WorkManager.getInstance(context)
    .beginWith(validateRequest)
    .then(downloadRequest)
    .then(decompressRequest)
    .then(processRequest)
    .then(compressRequest)
    .then(uploadRequest)
    .then(cleanupRequest)
    .enqueue()
```

### Chain with List of Workers

```kotlin
val workRequests = listOf(
    OneTimeWorkRequestBuilder<Step1Worker>().build(),
    OneTimeWorkRequestBuilder<Step2Worker>().build(),
    OneTimeWorkRequestBuilder<Step3Worker>().build()
)

WorkManager.getInstance(context)
    .beginWith(workRequests)
    .enqueue()
```

## Parallel Chains

### Basic Parallel Execution

```kotlin
val imageCompress = OneTimeWorkRequestBuilder<ImageCompressWorker>().build()
val videoCompress = OneTimeWorkRequestBuilder<VideoCompressWorker>().build()
val audioCompress = OneTimeWorkRequestBuilder<AudioCompressWorker>().build()

// All three run in parallel
WorkManager.getInstance(context)
    .beginWith(listOf(imageCompress, videoCompress, audioCompress))
    .enqueue()
```

### Parallel with Sequential Continuation

```kotlin
val download1 = OneTimeWorkRequestBuilder<Download1Worker>().build()
val download2 = OneTimeWorkRequestBuilder<Download2Worker>().build()
val download3 = OneTimeWorkRequestBuilder<Download3Worker>().build()
val processAll = OneTimeWorkRequestBuilder<ProcessAllWorker>().build()

// Downloads run in parallel, then process all results
WorkManager.getInstance(context)
    .beginWith(listOf(download1, download2, download3))
    .then(processAll)
    .enqueue()
```

## Combined Chains

### Multiple Chains Converging

```kotlin
// Chain 1: Download and process images
val chain1 = WorkManager.getInstance(context)
    .beginWith(downloadImagesRequest)
    .then(processImagesRequest)

// Chain 2: Download and process videos
val chain2 = WorkManager.getInstance(context)
    .beginWith(downloadVideosRequest)
    .then(processVideosRequest)

// Combine chains and upload all
val uploadRequest = OneTimeWorkRequestBuilder<UploadAllWorker>().build()

WorkContinuation.combine(listOf(chain1, chain2))
    .then(uploadRequest)
    .enqueue()
```

### Complex Multi-Stage Pipeline

```kotlin
// Stage 1: Parallel downloads
val downloadChain = WorkManager.getInstance(context)
    .beginWith(listOf(
        OneTimeWorkRequestBuilder<DownloadSource1Worker>().build(),
        OneTimeWorkRequestBuilder<DownloadSource2Worker>().build(),
        OneTimeWorkRequestBuilder<DownloadSource3Worker>().build()
    ))

// Stage 2: Sequential processing
val processChain = downloadChain
    .then(OneTimeWorkRequestBuilder<MergeDataWorker>().build())
    .then(OneTimeWorkRequestBuilder<ValidateDataWorker>().build())

// Stage 3: Parallel transformations
val transformChain = processChain
    .then(listOf(
        OneTimeWorkRequestBuilder<GenerateReportWorker>().build(),
        OneTimeWorkRequestBuilder<GenerateChartsWorker>().build(),
        OneTimeWorkRequestBuilder<GenerateExportWorker>().build()
    ))

// Stage 4: Final upload
transformChain
    .then(OneTimeWorkRequestBuilder<UploadResultsWorker>().build())
    .enqueue()
```

## Data Passing Between Workers

### Passing Data in Sequential Chain

```kotlin
class DownloadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val url = inputData.getString(KEY_URL) ?: return Result.failure()

        val filePath = downloadFile(url)

        // Pass file path to next worker
        val outputData = workDataOf(KEY_FILE_PATH to filePath)
        return Result.success(outputData)
    }

    companion object {
        const val KEY_URL = "url"
        const val KEY_FILE_PATH = "file_path"
    }
}

class ProcessWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // Receive file path from previous worker
        val filePath = inputData.getString(DownloadWorker.KEY_FILE_PATH)
            ?: return Result.failure()

        val processedPath = processFile(filePath)

        val outputData = workDataOf(KEY_PROCESSED_PATH to processedPath)
        return Result.success(outputData)
    }

    companion object {
        const val KEY_PROCESSED_PATH = "processed_path"
    }
}

// Chain them
val downloadRequest = OneTimeWorkRequestBuilder<DownloadWorker>()
    .setInputData(workDataOf(DownloadWorker.KEY_URL to "https://example.com/file.zip"))
    .build()

val processRequest = OneTimeWorkRequestBuilder<ProcessWorker>().build()

WorkManager.getInstance(context)
    .beginWith(downloadRequest)
    .then(processRequest)
    .enqueue()
```

### Merging Data from Parallel Workers

```kotlin
class MergeWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // inputData contains merged output from ALL previous parallel workers
        val image1Path = inputData.getString("image1_path")
        val image2Path = inputData.getString("image2_path")
        val image3Path = inputData.getString("image3_path")

        // Process all images
        val mergedResult = mergeImages(
            listOfNotNull(image1Path, image2Path, image3Path)
        )

        return Result.success(workDataOf("merged_path" to mergedResult))
    }
}

// Parallel workers with different output keys
val compress1 = OneTimeWorkRequestBuilder<ImageCompress1Worker>()
    .build() // outputs "image1_path"

val compress2 = OneTimeWorkRequestBuilder<ImageCompress2Worker>()
    .build() // outputs "image2_path"

val compress3 = OneTimeWorkRequestBuilder<ImageCompress3Worker>()
    .build() // outputs "image3_path"

val merge = OneTimeWorkRequestBuilder<MergeWorker>().build()

WorkManager.getInstance(context)
    .beginWith(listOf(compress1, compress2, compress3))
    .then(merge)
    .enqueue()
```

### Using ArrayInputMerger

```kotlin
// When parallel workers output same key, use ArrayInputMerger
class CollectWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // Get array of all "file_path" values from parallel workers
        val filePaths = inputData.getStringArray("file_path") ?: emptyArray()

        val result = processAllFiles(filePaths.toList())

        return Result.success(workDataOf("result" to result))
    }
}

val worker1 = OneTimeWorkRequestBuilder<Worker1>()
    .build() // outputs workDataOf("file_path" to "path1")

val worker2 = OneTimeWorkRequestBuilder<Worker2>()
    .build() // outputs workDataOf("file_path" to "path2")

val worker3 = OneTimeWorkRequestBuilder<Worker3>()
    .build() // outputs workDataOf("file_path" to "path3")

val collect = OneTimeWorkRequestBuilder<CollectWorker>()
    .setInputMerger(ArrayCreatingInputMerger::class)
    .build()

WorkManager.getInstance(context)
    .beginWith(listOf(worker1, worker2, worker3))
    .then(collect)
    .enqueue()
```

## Error Handling in Chains

### Automatic Chain Cancellation

```kotlin
// If any worker in chain fails, subsequent workers are CANCELLED
WorkManager.getInstance(context)
    .beginWith(downloadRequest)
    .then(processRequest)  // Cancelled if download fails
    .then(uploadRequest)   // Cancelled if download or process fails
    .enqueue()
```

### Handling Failures

```kotlin
class DownloadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            downloadFile()
            Result.success()
        } catch (e: NetworkException) {
            // Retry on network errors
            if (runAttemptCount < 3) {
                Result.retry()
            } else {
                // Chain will be cancelled after 3 retries
                Result.failure(workDataOf("error" to "Network failed"))
            }
        } catch (e: Exception) {
            // Fail immediately for other errors
            Result.failure(workDataOf("error" to e.message))
        }
    }
}
```

### Fallback Chains

```kotlin
// Primary chain
val primaryChain = WorkManager.getInstance(context)
    .beginWith(downloadFromServerRequest)
    .then(processRequest)

// Observe primary chain for failures
WorkManager.getInstance(context)
    .getWorkInfoByIdLiveData(downloadFromServerRequest.id)
    .observe(lifecycleOwner) { workInfo ->
        if (workInfo?.state == WorkInfo.State.FAILED) {
            // Start fallback chain
            val fallbackChain = WorkManager.getInstance(context)
                .beginWith(downloadFromCacheRequest)
                .then(processRequest)
            fallbackChain.enqueue()
        }
    }

primaryChain.enqueue()
```

## Chain Observing

### Observe Entire Chain

```kotlin
val downloadRequest = OneTimeWorkRequestBuilder<DownloadWorker>().build()
val processRequest = OneTimeWorkRequestBuilder<ProcessWorker>().build()
val uploadRequest = OneTimeWorkRequestBuilder<UploadWorker>().build()

val continuation = WorkManager.getInstance(context)
    .beginWith(downloadRequest)
    .then(processRequest)
    .then(uploadRequest)

// Observe chain completion
continuation.workInfosLiveData.observe(lifecycleOwner) { workInfos ->
    val allFinished = workInfos.all { it.state.isFinished }
    val anyFailed = workInfos.any { it.state == WorkInfo.State.FAILED }

    when {
        anyFailed -> handleChainFailure()
        allFinished -> handleChainSuccess()
        else -> updateProgress(workInfos)
    }
}

continuation.enqueue()
```

### Observe Individual Workers

```kotlin
val downloadId = downloadRequest.id
val processId = processRequest.id
val uploadId = uploadRequest.id

WorkManager.getInstance(context).apply {
    getWorkInfoByIdLiveData(downloadId).observe(lifecycleOwner) { workInfo ->
        when (workInfo?.state) {
            WorkInfo.State.RUNNING -> updateUI("Downloading...")
            WorkInfo.State.SUCCEEDED -> updateUI("Download complete")
            WorkInfo.State.FAILED -> handleDownloadError()
            else -> {}
        }
    }

    getWorkInfoByIdLiveData(processId).observe(lifecycleOwner) { workInfo ->
        when (workInfo?.state) {
            WorkInfo.State.RUNNING -> updateUI("Processing...")
            WorkInfo.State.SUCCEEDED -> updateUI("Processing complete")
            else -> {}
        }
    }

    getWorkInfoByIdLiveData(uploadId).observe(lifecycleOwner) { workInfo ->
        when (workInfo?.state) {
            WorkInfo.State.RUNNING -> updateUI("Uploading...")
            WorkInfo.State.SUCCEEDED -> {
                val resultUrl = workInfo.outputData.getString("url")
                handleSuccess(resultUrl)
            }
            else -> {}
        }
    }
}
```

### Progress Tracking

```kotlin
class ProgressReportingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val files = inputData.getStringArray(KEY_FILES) ?: return Result.failure()

        files.forEachIndexed { index, file ->
            processFile(file)

            // Update progress
            val progress = ((index + 1) * 100) / files.size
            setProgress(workDataOf(KEY_PROGRESS to progress))
        }

        return Result.success()
    }
}

// Observe progress
WorkManager.getInstance(context)
    .getWorkInfoByIdLiveData(workId)
    .observe(lifecycleOwner) { workInfo ->
        val progress = workInfo?.progress?.getInt(KEY_PROGRESS, 0) ?: 0
        updateProgressBar(progress)
    }
```

## Advanced Patterns

### Conditional Branching

```kotlin
class ValidationWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val data = inputData.getString("data")

        return if (isValid(data)) {
            Result.success(workDataOf("valid" to true))
        } else {
            Result.success(workDataOf("valid" to false))
        }
    }
}

// Observe and branch
WorkManager.getInstance(context)
    .getWorkInfoByIdLiveData(validationRequest.id)
    .observe(lifecycleOwner) { workInfo ->
        if (workInfo?.state == WorkInfo.State.SUCCEEDED) {
            val isValid = workInfo.outputData.getBoolean("valid", false)

            val nextRequest = if (isValid) {
                OneTimeWorkRequestBuilder<ProcessValidDataWorker>().build()
            } else {
                OneTimeWorkRequestBuilder<HandleInvalidDataWorker>().build()
            }

            WorkManager.getInstance(context).enqueue(nextRequest)
        }
    }
```

### Dynamic Chain Building

```kotlin
fun buildDynamicChain(files: List<String>): WorkContinuation {
    val workManager = WorkManager.getInstance(context)

    // Create worker for each file
    val fileWorkers = files.map { file ->
        OneTimeWorkRequestBuilder<ProcessFileWorker>()
            .setInputData(workDataOf("file" to file))
            .build()
    }

    // Create parallel chain
    return workManager
        .beginWith(fileWorkers)
        .then(OneTimeWorkRequestBuilder<MergeResultsWorker>().build())
}

// Use dynamic chain
val files = listOf("file1.txt", "file2.txt", "file3.txt")
buildDynamicChain(files).enqueue()
```

### Retry Entire Chain

```kotlin
fun enqueueWithRetry(maxRetries: Int = 3) {
    val uniqueName = "retry_chain"

    WorkManager.getInstance(context)
        .getWorkInfosForUniqueWorkLiveData(uniqueName)
        .observe(lifecycleOwner) { workInfos ->
            val failed = workInfos.any { it.state == WorkInfo.State.FAILED }

            if (failed) {
                val currentAttempt = workInfos.first()
                    .outputData
                    .getInt("attempt", 0)

                if (currentAttempt < maxRetries) {
                    // Retry chain with incremented attempt
                    val retryChain = buildChain(currentAttempt + 1)
                    WorkManager.getInstance(context)
                        .enqueueUniqueWork(
                            uniqueName,
                            ExistingWorkPolicy.REPLACE,
                            retryChain
                        )
                } else {
                    handleMaxRetriesExceeded()
                }
            }
        }

    // Initial enqueue
    WorkManager.getInstance(context)
        .enqueueUniqueWork(uniqueName, ExistingWorkPolicy.REPLACE, buildChain(0))
}

fun buildChain(attempt: Int): OneTimeWorkRequest {
    return OneTimeWorkRequestBuilder<ChainStartWorker>()
        .setInputData(workDataOf("attempt" to attempt))
        .build()
}
```

## Best Practices

### Do's

- Use meaningful worker names and tags
- Pass minimal data between workers (use file paths, not content)
- Handle failures gracefully with retry logic
- Use parallel chains for independent operations
- Observe chain progress for user feedback
- Clean up temporary files in final worker

### Don'ts

- Don't create excessively long chains (>10 workers)
- Don't pass large data through WorkData
- Don't rely on exact execution order in parallel chains
- Don't create circular dependencies
- Don't forget to handle partial failures
- Don't chain workers that could be parallelized
