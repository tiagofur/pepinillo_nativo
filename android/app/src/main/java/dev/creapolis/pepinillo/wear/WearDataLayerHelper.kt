package dev.creapolis.pepinillo.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import dev.creapolis.pepinillo.domain.timer.FocusTimerState
import dev.creapolis.pepinillo.domain.timer.displayTime
import dev.creapolis.pepinillo.domain.timer.phaseLabel
import dev.creapolis.pepinillo.domain.timer.progress
import dev.creapolis.pepinillo.domain.timer.TimerStatus
import dev.creapolis.pepinillo.widget.WidgetTask
import org.json.JSONArray
import org.json.JSONObject

private const val TAG = "WearDataLayerHelper"

object WearDataLayerHelper {
    const val PATH_TIMER = "/pepinillo/timer"
    const val PATH_TASKS = "/pepinillo/tasks"
    const val PATH_STATS = "/pepinillo/stats"

    const val CMD_TIMER_START = "/pepinillo/cmd/timer/start"
    const val CMD_TIMER_PAUSE = "/pepinillo/cmd/timer/pause"
    const val CMD_TIMER_RESUME = "/pepinillo/cmd/timer/resume"
    const val CMD_TIMER_STOP = "/pepinillo/cmd/timer/stop"
    const val CMD_TASK_COMPLETE = "/pepinillo/cmd/task/complete"

    fun pushTimer(context: Context, state: FocusTimerState) {
        val request = PutDataMapRequest.create(PATH_TIMER).apply {
            dataMap.putString("mode", state.mode.name)
            dataMap.putString("phase", state.phase.name)
            dataMap.putString("status", state.status.name)
            dataMap.putString("displayTime", state.displayTime)
            dataMap.putString("phaseLabel", state.phaseLabel)
            dataMap.putFloat("progress", state.progress)
            dataMap.putLong("elapsedMillis", state.elapsedMillis)
            dataMap.putLong("totalMillis", state.totalMillis)
            dataMap.putInt("completedSessions", state.completedSessions)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context).putDataItem(request)
            .addOnFailureListener { e -> Log.w(TAG, "Failed pushing timer", e) }
    }

    fun pushTasksAndStats(
        context: Context,
        tasks: List<WidgetTask>,
        totalMinutes: Int,
        sessions: Int,
        streak: Int,
        completedTasksToday: Int,
    ) {
        val tasksRequest = PutDataMapRequest.create(PATH_TASKS).apply {
            dataMap.putString("tasksJson", tasksToJson(tasks))
            dataMap.putInt("count", tasks.size)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context).putDataItem(tasksRequest)
            .addOnFailureListener { e -> Log.w(TAG, "Failed pushing tasks", e) }

        val statsRequest = PutDataMapRequest.create(PATH_STATS).apply {
            dataMap.putInt("totalMinutes", totalMinutes)
            dataMap.putInt("sessions", sessions)
            dataMap.putInt("streak", streak)
            dataMap.putInt("completedTasksToday", completedTasksToday)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context).putDataItem(statsRequest)
            .addOnFailureListener { e -> Log.w(TAG, "Failed pushing stats", e) }
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
        val request = PutDataMapRequest.create(PATH_TIMER).apply {
            dataMap.putString("mode", mode)
            dataMap.putString("phase", "Work")
            dataMap.putString("status", "Idle")
            dataMap.putString("displayTime", displayTime)
            dataMap.putString("phaseLabel", "Listo")
            dataMap.putFloat("progress", 1f)
            dataMap.putLong("elapsedMillis", 0L)
            dataMap.putLong("totalMillis", 0L)
            dataMap.putInt("completedSessions", 0)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        Wearable.getDataClient(context).putDataItem(request)
            .addOnFailureListener { e -> Log.w(TAG, "Failed pushing idle state", e) }
    }

    fun isRunning(status: String): Boolean = status == TimerStatus.Running.name
}
