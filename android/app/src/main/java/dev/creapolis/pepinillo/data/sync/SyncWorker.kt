package dev.creapolis.pepinillo.data.sync

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.util.concurrent.TimeUnit

private const val TAG = "SyncWorker"
private const val WORK_NAME = "pepinillo_sync"

@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted appContext: Context,
    @Assisted params: WorkerParameters,
    private val syncEngine: SyncEngine,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return when (val syncResult = syncEngine.syncAll()) {
            is SyncResult.Success -> {
                Log.d(TAG, "Sync completed successfully")
                Result.success()
            }
            is SyncResult.NotAuthenticated -> {
                Log.d(TAG, "Sync skipped: not authenticated")
                Result.success()
            }
            is SyncResult.TransientError -> {
                Log.w(TAG, "Sync failed (transient), will retry: ${syncResult.exception.message}")
                Result.retry()
            }
            is SyncResult.PermanentError -> {
                Log.e(TAG, "Sync failed (permanent), will NOT retry: ${syncResult.exception.message}")
                Result.success()
            }
        }
    }

    companion object {
        private const val ONE_TIME_WORK_NAME = "pepinillo_sync_one_time"

        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    androidx.work.ExistingPeriodicWorkPolicy.KEEP,
                    request,
                )
        }

        fun scheduleOneTime(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<SyncWorker>()
                .setConstraints(constraints)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    ONE_TIME_WORK_NAME,
                    ExistingWorkPolicy.REPLACE,
                    request,
                )
        }
    }
}
