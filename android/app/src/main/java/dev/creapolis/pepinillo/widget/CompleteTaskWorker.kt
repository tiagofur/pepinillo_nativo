package dev.creapolis.pepinillo.widget

import android.content.Context
import android.util.Log
import androidx.glance.appwidget.updateAll
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.core.billing.FeatureGate
import kotlinx.coroutines.flow.first

private const val TAG = "CompleteTaskWorker"

@HiltWorker
class CompleteTaskWorker @AssistedInject constructor(
    @Assisted private val appContext: Context,
    @Assisted params: WorkerParameters,
    private val taskRepository: TaskRepository,
    private val sessionRepository: SessionRepository,
    private val featureGate: FeatureGate,
) : CoroutineWorker(appContext, params) {

    companion object {
        const val KEY_TASK_ID = "task_id"
        const val WORK_PREFIX = "complete_task_"

        fun uniqueWorkName(taskId: String): String = "$WORK_PREFIX$taskId"
    }

    override suspend fun doWork(): Result {
        val taskId = inputData.getString(KEY_TASK_ID) ?: run {
            Log.e(TAG, "No task_id provided")
            return Result.failure()
        }

        val result = taskRepository.completeTaskFromWear(taskId)
        return result.fold(
            onSuccess = {
                TasksWidget().updateAll(appContext)
                refreshDailyStatsWidget()
                Log.d(TAG, "Task $taskId completed from widget")
                Result.success()
            },
            onFailure = { e ->
                Log.e(TAG, "Failed to complete task $taskId", e)
                Result.retry()
            },
        )
    }

    private suspend fun refreshDailyStatsWidget() {
        runCatching {
            val stats = sessionRepository.getTodayStats().first()
            val allDays = sessionRepository.getAllDaysWithSessions().first()
            val streak = StreakProtectionService.computeProtectedStreak(
                history = allDays,
                isPro = featureGate.isPro,
            ).days
            val startOfDay = SessionRepository.startOfDay(System.currentTimeMillis())
            val completedToday = taskRepository.getCompletedTodayCount(startOfDay)

            WidgetStateManager.updateDailyStats(
                context = appContext,
                totalMinutes = stats?.totalMinutes ?: 0,
                sessions = stats?.sessionsCompleted ?: 0,
                streak = streak,
                completedTasksToday = completedToday,
            )
        }.onFailure { e ->
            Log.w(TAG, "Direct stats widget refresh failed — enqueueing WidgetRefreshWorker", e)
            WorkManager.getInstance(appContext).enqueue(
                OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
            )
        }
    }
}