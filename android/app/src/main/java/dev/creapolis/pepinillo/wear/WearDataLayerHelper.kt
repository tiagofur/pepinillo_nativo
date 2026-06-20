package dev.creapolis.pepinillo.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.nio.charset.StandardCharsets
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabelRes
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.feature.focus.FocusMode
import androidx.compose.ui.graphics.toArgb
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.widget.WidgetTask
import org.json.JSONArray
import org.json.JSONObject

private const val TAG = "WearDataLayerHelper"

object WearDataLayerHelper {
    const val PATH_TIMER = "/pepinillo/timer"
    const val PATH_TASKS = "/pepinillo/tasks"
    const val PATH_STATS = "/pepinillo/stats"
    private const val PATH_THEME = "/pepinillo/theme"
    private const val PATH_USER = "/pepinillo/user"

    const val CMD_TIMER_START = "/pepinillo/cmd/timer/start"
    const val CMD_TIMER_PAUSE = "/pepinillo/cmd/timer/pause"
    const val CMD_TIMER_RESUME = "/pepinillo/cmd/timer/resume"
    const val CMD_TIMER_STOP = "/pepinillo/cmd/timer/stop"
    const val CMD_TIMER_SKIP = "/pepinillo/cmd/timer/skip"
    const val CMD_TASK_COMPLETE = "/pepinillo/cmd/task/complete"
    const val CMD_TASK_LINK = "/pepinillo/cmd/task/link"
    const val CMD_TASK_UNLINK = "/pepinillo/cmd/task/unlink"
    const val CMD_REQUEST_SYNC = "/pepinillo/cmd/request_sync"

    /**
     * Dedicated scope for put-item retries so the work (and its recursive
     * retries) never runs on the Main looper. A SupervisorJob keeps one
     * failed put from cancelling sibling pushes.
     */
    private val wearIoScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun pushTimer(context: Context, state: FocusTimerState, linkedTaskName: String?) {
        val appContext = context.applicationContext
        val request = PutDataMapRequest.create(PATH_TIMER).apply {
            dataMap.putString("mode", state.mode.name)
            dataMap.putString("phase", state.phase.name)
            dataMap.putString("status", state.status.name)
            dataMap.putString("displayTime", state.displayTime)
            val phaseLabel = if (state.mode == FocusMode.Pomodoro && state.phase == FocusPhase.Work) {
                appContext.getString(state.phaseLabelRes, state.completedSessions + 1)
            } else {
                appContext.getString(state.phaseLabelRes)
            }
            dataMap.putString("phaseLabel", phaseLabel)
            dataMap.putFloat("progress", state.progress)
            dataMap.putLong("elapsedMillis", state.elapsedMillis)
            dataMap.putLong("totalMillis", state.totalMillis)
            dataMap.putInt("completedSessions", state.completedSessions)
            dataMap.putString("linkedTaskId", state.linkedTaskId ?: "")
            dataMap.putString("linkedTaskName", linkedTaskName ?: "")
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        putWithRetry(appContext, request, "pushTimer")
    }

    fun pushTasksAndStats(
        context: Context,
        tasks: List<WidgetTask>,
        totalMinutes: Int,
        sessions: Int,
        streak: Int,
        completedTasksToday: Int,
    ) {
        val appContext = context.applicationContext
        val json = tasksToJson(tasks)
        Log.d(TAG, "Pushing ${tasks.size} tasks to wear, json length=${json.length}")
        val tasksRequest = PutDataMapRequest.create(PATH_TASKS).apply {
            dataMap.putString("tasksJson", json)
            dataMap.putInt("count", tasks.size)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        putWithRetry(appContext, tasksRequest, "pushTasks(${tasks.size})")

        val statsRequest = PutDataMapRequest.create(PATH_STATS).apply {
            dataMap.putInt("totalMinutes", totalMinutes)
            dataMap.putInt("sessions", sessions)
            dataMap.putInt("streak", streak)
            dataMap.putInt("completedTasksToday", completedTasksToday)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        putWithRetry(appContext, statsRequest, "pushStats")
    }

    private fun tasksToJson(tasks: List<WidgetTask>): String {
        val arr = JSONArray()
        tasks.forEach { task ->
            arr.put(
                JSONObject().apply {
                    put("id", task.id)
                    put("title", task.title)
                    put("energyEmoji", task.energyEmoji)
                    put("pomodoroProgress", task.pomodoroProgress)
                },
            )
        }
        return arr.toString()
    }

    /** Push the current idle state so the watch knows the phone is connected. */
    fun pushIdleState(context: Context, mode: String, displayTime: String) {
        val appContext = context.applicationContext
        val request = PutDataMapRequest.create(PATH_TIMER).apply {
            dataMap.putString("mode", mode)
            dataMap.putString("phase", "Work")
            dataMap.putString("status", "Idle")
            dataMap.putString("displayTime", displayTime)
            dataMap.putString("phaseLabel", appContext.getString(R.string.state_ready))
            dataMap.putFloat("progress", 1f)
            dataMap.putLong("elapsedMillis", 0L)
            dataMap.putLong("totalMillis", 0L)
            dataMap.putInt("completedSessions", 0)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        putWithRetry(appContext, request, "pushIdleState")
    }

    private const val EVENT_PHASE_COMPLETE = "/pepinillo/event/phase_complete"

    /** Notify the watch that a timer phase just completed (vibration trigger). */
    fun pushPhaseComplete(context: Context, mode: String, completedPhase: String, scope: CoroutineScope? = null) {
        val appContext = context.applicationContext
        val payload = "$mode|$completedPhase".toByteArray(StandardCharsets.UTF_8)
        val effectiveScope = scope ?: CoroutineScope(Dispatchers.IO + kotlinx.coroutines.SupervisorJob())
        effectiveScope.launch {
            runCatching {
                val nodes = Wearable.getNodeClient(appContext).connectedNodes.await()
                nodes.forEach { node ->
                    Wearable.getMessageClient(appContext)
                        .sendMessage(node.id, EVENT_PHASE_COMPLETE, payload)
                        .await()
                }
            }.onFailure { e -> Log.w(TAG, "Failed pushing phase complete event", e) }
        }
    }

    fun pushTheme(context: Context, themeId: String, theme: AppTheme) {
        val appContext = context.applicationContext
        try {
            val request = PutDataMapRequest.create(PATH_THEME).apply {
                dataMap.putString("themeId", themeId)
                dataMap.putLong("pomodoroColor", theme.pomodoroColor.toArgb().toLong())
                dataMap.putLong("flowtimeColor", theme.flowtimeColor.toArgb().toLong())
                dataMap.putLong("timeBlockColor", theme.timeBlockColor.toArgb().toLong())
                dataMap.putLong("stopwatchColor", theme.stopwatchColor.toArgb().toLong())
                dataMap.putLong("streakColor", theme.streakColor.toArgb().toLong())
                dataMap.putLong("timestamp", System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()

            putWithRetry(appContext, request, "pushTheme")
        } catch (e: Exception) {
            // Silently fail - watch will use defaults
        }
    }

    fun pushUserStatus(context: Context, isPro: Boolean) {
        val appContext = context.applicationContext
        val request = PutDataMapRequest.create(PATH_USER).apply {
            dataMap.putBoolean("isPro", isPro)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        putWithRetry(appContext, request, "pushUserStatus($isPro)")
    }

    /**
     * Put a data item with bounded retry. Runs entirely on [wearIoScope]
     * (Dispatchers.IO) so retries and their blocking Play services calls never
     * run on the Main looper. Each push function wraps this in a launch so
     * callers can keep their synchronous (non-suspend) signatures.
     */
    private fun putWithRetry(
        context: Context,
        request: PutDataRequest,
        tag: String,
        maxRetries: Int = DEFAULT_PUT_RETRIES,
    ) {
        val appContext = context.applicationContext
        wearIoScope.launch {
            var attempt = 0
            while (true) {
                try {
                    Wearable.getDataClient(appContext).putDataItem(request).await()
                    return@launch
                } catch (e: Exception) {
                    attempt++
                    if (attempt > maxRetries) {
                        Log.e(TAG, "$tag failed after $maxRetries retries", e)
                        return@launch
                    }
                    Log.w(TAG, "$tag failed, retrying ($attempt/$maxRetries)", e)
                    delay(PUT_RETRY_DELAY_MS)
                }
            }
        }
    }

    fun isRunning(status: String): Boolean = status == TimerStatus.Running.name

    private const val DEFAULT_PUT_RETRIES = 2
    private const val PUT_RETRY_DELAY_MS = 1_000L
}
