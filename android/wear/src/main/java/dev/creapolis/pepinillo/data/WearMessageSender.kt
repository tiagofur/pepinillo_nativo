package dev.creapolis.pepinillo.data

import android.content.Context
import com.google.android.gms.wearable.Wearable
import dev.creapolis.pepinillo.data.WearDataPaths.CMD_TASK_COMPLETE
import dev.creapolis.pepinillo.data.WearDataPaths.CMD_TIMER_PAUSE
import dev.creapolis.pepinillo.data.WearDataPaths.CMD_TIMER_RESUME
import dev.creapolis.pepinillo.data.WearDataPaths.CMD_TIMER_START
import dev.creapolis.pepinillo.data.WearDataPaths.CMD_TIMER_STOP
import kotlinx.coroutines.tasks.await
import java.nio.charset.StandardCharsets

object WearDataPaths {
    const val PATH_TIMER = "/pepinillo/timer"
    const val PATH_TASKS = "/pepinillo/tasks"
    const val PATH_STATS = "/pepinillo/stats"

    const val CMD_TIMER_START = "/pepinillo/cmd/timer/start"
    const val CMD_TIMER_PAUSE = "/pepinillo/cmd/timer/pause"
    const val CMD_TIMER_RESUME = "/pepinillo/cmd/timer/resume"
    const val CMD_TIMER_STOP = "/pepinillo/cmd/timer/stop"
    const val CMD_TASK_COMPLETE = "/pepinillo/cmd/task/complete"
}

class WearMessageSender(private val context: Context) {

    private val prefs by lazy {
        context.getSharedPreferences("wear_pending_commands", Context.MODE_PRIVATE)
    }

    init {
        // Restore pending count from persisted state on start
        WearDataStore.updatePendingCount(readPendingCommands().size)
    }

    private companion object {
        const val KEY_PENDING = "pending"
    }

    suspend fun sendCommand(path: String, data: ByteArray = byteArrayOf()): Boolean {
        val nodes = Wearable.getNodeClient(context).connectedNodes.await()
        if (nodes.isEmpty()) {
            enqueuePendingCommand(path, data)
            return false
        }

        flushPendingCommands(nodes.map { it.id })

        nodes.forEach { node ->
            Wearable.getMessageClient(context).sendMessage(node.id, path, data).await()
        }
        return true
    }

    suspend fun flushPendingCommands() {
        val nodes = Wearable.getNodeClient(context).connectedNodes.await()
        if (nodes.isEmpty()) return
        flushPendingCommands(nodes.map { it.id })
    }

    private suspend fun flushPendingCommands(nodeIds: List<String>) {
        val pending = readPendingCommands()
        if (pending.isEmpty()) return

        val stillPending = WearPendingCommandQueue.flush(pending, nodeIds) { nodeId, command ->
            Wearable.getMessageClient(context).sendMessage(nodeId, command.path, command.data).await()
        }

        writePendingCommands(stillPending)
    }

    private fun enqueuePendingCommand(path: String, data: ByteArray) {
        val bounded = WearPendingCommandQueue.enqueue(readPendingCommands(), path, data)
        writePendingCommands(bounded)
    }

    private fun readPendingCommands(): List<PendingCommand> {
        val json = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        return WearPendingCommandQueue.deserialize(json)
    }

    private fun clearPendingCommands() {
        prefs.edit().putString(KEY_PENDING, "[]").apply()
    }

    private fun writePendingCommands(commands: List<PendingCommand>) {
        prefs.edit().putString(KEY_PENDING, WearPendingCommandQueue.serialize(commands)).apply()
        WearDataStore.updatePendingCount(commands.size)
    }

    suspend fun startTimer(mode: String): Boolean =
        sendCommand(CMD_TIMER_START, mode.toByteArray(StandardCharsets.UTF_8))

    suspend fun pauseTimer(): Boolean = sendCommand(CMD_TIMER_PAUSE)

    suspend fun resumeTimer(): Boolean = sendCommand(CMD_TIMER_RESUME)

    suspend fun stopTimer(): Boolean = sendCommand(CMD_TIMER_STOP)

    suspend fun completeTask(taskId: String): Boolean =
        sendCommand(CMD_TASK_COMPLETE, taskId.toByteArray(StandardCharsets.UTF_8))
}
