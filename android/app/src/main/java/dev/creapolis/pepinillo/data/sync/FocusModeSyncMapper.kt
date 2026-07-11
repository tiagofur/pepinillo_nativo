package dev.creapolis.pepinillo.data.sync

/**
 * Canonical mapping between local Focus mode names (FocusMode.name / SessionRepository)
 * and server wire strings used by the sync API.
 *
 * Local: Pomodoro, Flow, Blocks, Chrono
 * Server: pomodoro, flowtime, timeblock, stopwatch
 */
object FocusModeSyncMapper {

    fun toServerMode(local: String): String = when (local.lowercase()) {
        "pomodoro" -> "pomodoro"
        "flow", "flowtime" -> "flowtime"
        "blocks", "timeblock", "time block", "timeblocking" -> "timeblock"
        "chrono", "stopwatch" -> "stopwatch"
        else -> "pomodoro"
    }

    fun toLocalMode(server: String): String = when (server.lowercase()) {
        "pomodoro" -> "Pomodoro"
        "flow", "flowtime" -> "Flow"
        "blocks", "timeblock", "time block", "timeblocking" -> "Blocks"
        "chrono", "stopwatch" -> "Chrono"
        // Legacy wrong names previously written by inbound sync
        else -> when (server) {
            "Flowtime" -> "Flow"
            "TimeBlock" -> "Blocks"
            "Stopwatch" -> "Chrono"
            else -> "Pomodoro"
        }
    }
}