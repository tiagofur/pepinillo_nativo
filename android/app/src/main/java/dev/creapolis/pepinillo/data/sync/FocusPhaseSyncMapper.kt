package dev.creapolis.pepinillo.data.sync

/**
 * Canonical mapping between local focus phase names (FocusPhase.name / SessionRepository)
 * and server wire strings used by the sync API.
 *
 * Local pomodoro phases: Work, ShortBreak, LongBreak
 * Server: work, short_break, long_break (+ flow/break/check_in/freeform for other modes)
 */
object FocusPhaseSyncMapper {

    fun toServerPhase(local: String): String = when (normalize(local)) {
        "work" -> "work"
        "shortbreak" -> "short_break"
        "longbreak" -> "long_break"
        "flow" -> "flow"
        "break" -> "break"
        "checkin" -> "check_in"
        "freeform" -> "freeform"
        else -> "work"
    }

    fun toLocalPhase(server: String): String = when (normalize(server)) {
        "work" -> "Work"
        "short_break", "shortbreak" -> "ShortBreak"
        "long_break", "longbreak" -> "LongBreak"
        "flow" -> "Flow"
        "break" -> "Break"
        "check_in", "checkin" -> "CheckIn"
        "freeform" -> "Freeform"
        else -> legacyLocalPhase(server)
    }

    /** Collapse spaces/underscores for case-insensitive matching. */
    private fun normalize(value: String): String =
        value.lowercase().replace(" ", "").replace("_", "")

    /** Legacy display strings previously stored by inbound sync. */
    private fun legacyLocalPhase(server: String): String = when (server) {
        "Short Break" -> "ShortBreak"
        "Long Break" -> "LongBreak"
        "Check In" -> "CheckIn"
        else -> server
    }
}