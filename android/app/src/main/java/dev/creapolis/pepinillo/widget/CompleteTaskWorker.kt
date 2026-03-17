package dev.creapolis.pepinillo.widget

import android.content.Context
import android.util.Log
import androidx.glance.appwidget.updateAll
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dev.creapolis.pepinillo.data.repository.TaskRepository

private const val TAG = "CompleteTaskWorker"

@HiltWorker
class CompleteTaskWorker @AssistedInject constructor(
    @Assisted private val appContext: Context,
    @Assisted params: WorkerParameters,
    private val taskRepository: TaskRepository,
) : CoroutineWorker(appContext, params) {

    companion object {
        const val KEY_TASK_ID = "task_id"
    }

    override suspend fun doWork(): Result {
        val taskId = inputData.getString(KEY_TASK_ID) ?: run {
            Log.e(TAG, "No task_id provided")
            return Result.failure()
        }
        return runCatching {
            taskRepository.toggleCompletion(taskId)
            // Widget content will be refreshed by the next WidgetRefreshWorker run (≤ 15 min).
            // For immediate feedback, also trigger an update now.
            TasksWidget().updateAll(appContext)
            Log.d(TAG, "Task $taskId completed from widget")
            Result.success()
        }.getOrElse { e ->
            Log.e(TAG, "Failed to complete task $taskId", e)
            Result.retry()
        }
    }
}
