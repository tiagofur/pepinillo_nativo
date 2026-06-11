package dev.creapolis.pepinillo.wear

import android.content.Intent
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.WearableListenerService
import dagger.hilt.android.AndroidEntryPoint
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.data.repository.SessionRepository
import dev.creapolis.pepinillo.data.repository.TaskRepository
import dev.creapolis.pepinillo.data.sync.WidgetRefreshWorker
import dev.creapolis.pepinillo.domain.streak.StreakProtectionService
import dev.creapolis.pepinillo.domain.timer.FocusEngine
import dev.creapolis.pepinillo.data.local.preferences.UserPreferencesRepository
import dev.creapolis.pepinillo.service.FocusTimerService
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.widget.WidgetTask
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.nio.charset.StandardCharsets
import java.util.Calendar
import javax.inject.Inject

private const val TAG = "PhoneWearListener"

@AndroidEntryPoint
class PhoneWearListenerService : WearableListenerService() {

    @Inject lateinit var focusEngine: FocusEngine
    @Inject lateinit var taskRepository: TaskRepository
    @Inject lateinit var sessionRepository: SessionRepository
    @Inject lateinit var prefsRepo: UserPreferencesRepository
    @Inject lateinit var featureGate: FeatureGate

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onPeerConnected(peer: Node) {
        super.onPeerConnected(peer)
        Log.d(TAG, "Watch connected: ${peer.displayName}")

        val state = focusEngine.state.value
        scope.launch {
            val linkedTaskName = state.linkedTaskId
                ?.takeIf { it.isNotBlank() }
                ?.let { taskRepository.getTaskById(it)?.title }
            WearDataLayerHelper.pushTimer(this@PhoneWearListenerService, state, linkedTaskName)
        }

        // Push tasks + stats directly (bypass WorkManager)
        pushTasksAndStatsDirectly()

        // Push current theme to watch
        pushThemeDirectly()

        // Also trigger widget refresh
        WorkManager.getInstance(this).enqueue(
            OneTimeWorkRequestBuilder<WidgetRefreshWorker>().build(),
        )
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            WearDataLayerHelper.CMD_TIMER_START -> {
                val mode = messageEvent.data.toString(StandardCharsets.UTF_8).ifBlank { "Pomodoro" }
                startForegroundService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_START_MODE
                        putExtra("mode", mode)
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_PAUSE -> {
                startService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_PAUSE
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_RESUME -> {
                startForegroundService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_RESUME
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_STOP -> {
                startService(
                    Intent(this, FocusTimerService::class.java).apply {
                        action = FocusTimerService.ACTION_STOP
                    },
                )
            }

            WearDataLayerHelper.CMD_TIMER_SKIP -> {
                Log.d(TAG, "Skip phase from watch")
                // Skip = start the next phase (works from WaitingForNext or Running)
                focusEngine.start()
            }

            WearDataLayerHelper.CMD_TASK_COMPLETE -> {
                val taskId = messageEvent.data.toString(StandardCharsets.UTF_8)
                if (taskId.isNotBlank()) {
                    Log.d(TAG, "Completing task $taskId from watch")
                    scope.launch {
                        runCatching {
                            taskRepository.toggleCompletion(taskId)
                            Log.d(TAG, "Task $taskId completed — pushing updated tasks")
                            pushTasksAndStatsDirectly()
                        }.onFailure { e ->
                            Log.e(TAG, "Failed to complete task $taskId", e)
                        }
                    }
                }
            }

            WearDataLayerHelper.CMD_TASK_LINK -> {
                val taskId = messageEvent.data.toString(StandardCharsets.UTF_8)
                if (taskId.isNotBlank()) {
                    Log.d(TAG, "Linking task $taskId from watch")
                    scope.launch {
                        focusEngine.linkTask(taskId)
                        val taskName = taskRepository.getTaskById(taskId)?.title
                        WearDataLayerHelper.pushTimer(
                            this@PhoneWearListenerService,
                            focusEngine.state.value,
                            taskName,
                        )
                    }
                }
            }

            WearDataLayerHelper.CMD_TASK_UNLINK -> {
                Log.d(TAG, "Unlinking task from watch")
                scope.launch {
                    focusEngine.linkTask(null)
                    WearDataLayerHelper.pushTimer(
                        this@PhoneWearListenerService,
                        focusEngine.state.value,
                        null,
                    )
                }
            }

            WearDataLayerHelper.CMD_REQUEST_SYNC -> {
                Log.d(TAG, "Watch requested sync — pushing directly")
                pushTasksAndStatsDirectly()
            }

            else -> {
                Log.d(TAG, "Ignored path: ${messageEvent.path}")
            }
        }
    }

    private fun pushTasksAndStatsDirectly() {
        scope.launch {
            runCatching {
                val activeTasks = taskRepository.getActiveTasks().first()
                Log.d(TAG, "Direct push: ${activeTasks.size} active tasks")

                val widgetTasks = activeTasks.take(5).map { WidgetTask.fromTask(it) }

                val stats = sessionRepository.getTodayStats().first()
                val allDays = sessionRepository.getAllDaysWithSessions().first()
                val streak = StreakProtectionService.computeProtectedStreak(
                    history = allDays,
                    isPro = featureGate.isPro,
                ).days
                val cal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
                }
                val completedToday = taskRepository.getCompletedTodayCount(cal.timeInMillis)

                WearDataLayerHelper.pushTasksAndStats(
                    context = this@PhoneWearListenerService,
                    tasks = widgetTasks,
                    totalMinutes = stats?.totalMinutes ?: 0,
                    sessions = stats?.sessionsCompleted ?: 0,
                    streak = streak,
                    completedTasksToday = completedToday,
                )
                Log.d(TAG, "Direct push completed: ${widgetTasks.size} tasks")
            }.onFailure { e ->
                Log.e(TAG, "Direct push failed", e)
            }
        }
    }

    private fun pushThemeDirectly() {
        scope.launch {
            runCatching {
                val prefs = prefsRepo.preferences.first()
                val themeId = prefs.selectedTheme
                val theme = AppTheme.named(themeId)
                WearDataLayerHelper.pushTheme(this@PhoneWearListenerService, themeId, theme)
                Log.d(TAG, "Theme pushed: $themeId")
            }.onFailure { e ->
                Log.e(TAG, "Failed to push theme", e)
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
