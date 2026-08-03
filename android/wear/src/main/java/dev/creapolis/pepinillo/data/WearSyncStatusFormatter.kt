package dev.creapolis.pepinillo.data

import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WearSyncStatus(
    val label: String?,
    val isStale: Boolean,
)

object WearSyncStatusFormatter {
    private const val STALE_AFTER_MILLIS = 2 * 60 * 1000L

    fun format(
        lastSyncAtMillis: Long?,
        isConnected: Boolean,
        nowMillis: Long = System.currentTimeMillis(),
        locale: Locale = Locale.getDefault(),
    ): WearSyncStatus {
        if (lastSyncAtMillis == null) {
            return WearSyncStatus(
                label = if (isConnected) "Esperando primera sync" else null,
                isStale = false,
            )
        }

        val time = SimpleDateFormat("HH:mm", locale).format(Date(lastSyncAtMillis))
        if (!isConnected) {
            return WearSyncStatus(label = "Sin conexion · ultima $time", isStale = true)
        }

        val isStale = nowMillis - lastSyncAtMillis > STALE_AFTER_MILLIS
        return WearSyncStatus(
            label = if (isStale) "Sync atrasada · $time" else "Sync $time",
            isStale = isStale,
        )
    }
}
