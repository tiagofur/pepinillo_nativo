package dev.creapolis.pepinillo.data.sync

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.wear.WearDataLayerHelper
import dev.creapolis.pepinillo.widget.WidgetStateManager
import dev.creapolis.pepinillo.widget.WidgetTask
import dev.creapolis.pepinillo.widget.WidgetTaskStateManager
import kotlinx.coroutines.flow.first
import java.util.Calendar
import java.util.concurrent.TimeUnit

private const val TAG = "WidgetRefreshWorker"
private const val WORK_NAME = "widget_refresh_periodic"

@HiltWorker
class WidgetRefreshWorker @AssistedInject constructor(
    @Assisted private val appContext: Context,
    @Assisted params: WorkerParameters,
    private val sessionRepository: SessionRepository,
    private val taskRepository: TaskRepository,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        return runCatching {
            // ── 1. Focus stats ──────────────────────────────────────────────
            val stats = sessionRepository.getTodayStats().first()
            val allDays = sessionRepository.getAllDaysWithSessions().first()
            val streak = sessionRepository.calculateCurrentStreak(allDays)
            val totalMinutes = stats?.totalMinutes ?: 0
            val sessions = stats?.sessionsCompleted ?: 0

            // ── 2. Tasks ────────────────────────────────────────────────────
            val activeTasks = taskRepository.getActiveTasks().first()
            val startOfDay = startOfDay()
            val completedToday = taskRepository.getCompletedTodayCount(startOfDay)

            val widgetTasks = activeTasks.take(5).map { task ->
                val energyEmoji = when (task.energyLevel) {
                    EnergyLevel.Deep -> "\uD83D\uDD25" // 🔥
                    EnergyLevel.Regular -> "\u26A1"     // ⚡
                    EnergyLevel.Light -> "\uD83D\uDCA7" // 💧
                }
                val pomodoroProgress = if (task.estimatedPomodoros > 0) {
                    "${task.completedPomodoros}/${task.estimatedPomodoros} \uD83C\uDF45"
                } else {
                    ""
                }
                WidgetTask(
                    id = task.id,
                    title = task.title,
                    energyEmoji = energyEmoji,
                    pomodoroProgress = pomodoroProgress,
                )
            }

            // ── 3. Push to widgets ──────────────────────────────────────────
            WidgetStateManager.updateDailyStats(
                context = appContext,
                totalMinutes = totalMinutes,
                sessions = sessions,
                streak = streak,
                completedTasksToday = completedToday,
            )

            WidgetTaskStateManager.updateTasks(
                context = appContext,
                tasks = widgetTasks,
                completedToday = completedToday,
            )

            WearDataLayerHelper.pushTasksAndStats(
                context = appContext,
                tasks = widgetTasks,
                totalMinutes = totalMinutes,
                sessions = sessions,
                streak = streak,
                completedTasksToday = completedToday,
            )

            Log.d(TAG, "Widget refresh done — ${totalMinutes}m focus, $sessions sessions, $streak streak, $completedToday tasks done")
            Result.success()
        }.getOrElse { e ->
            Log.e(TAG, "Widget refresh failed", e)
            Result.retry()
        }
    }

    companion object {
        fun schedule(context: Context) {
            val request = PeriodicWorkRequestBuilder<WidgetRefreshWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().build()) // no network required
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request,
            )

            // Also run once immediately so widgets show real data right away
            WorkManager.getInstance(context).enqueue(
                OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
            )
        }
    }

    private fun startOfDay(): Long {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }
}
