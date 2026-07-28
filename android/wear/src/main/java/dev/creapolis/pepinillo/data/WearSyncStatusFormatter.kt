package dev.creapolis.pepinillo.data

import android.content.Context
import dev.creapolis.pepinillo.R
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
        context: Context,
        lastSyncAtMillis: Long?,
        isConnected: Boolean,
        nowMillis: Long = System.currentTimeMillis(),
        locale: Locale = Locale.getDefault(),
    ): WearSyncStatus {
        if (lastSyncAtMillis == null) {
            return WearSyncStatus(
                label = if (isConnected) context.getString(R.string.sync_waiting) else null,
                isStale = false,
            )
        }

        val time = SimpleDateFormat("HH:mm", locale).format(Date(lastSyncAtMillis))
        if (!isConnected) {
            return WearSyncStatus(label = context.getString(R.string.sync_no_connection, time), isStale = true)
        }

        val isStale = nowMillis - lastSyncAtMillis > STALE_AFTER_MILLIS
        return WearSyncStatus(
            label = if (isStale) {
                context.getString(R.string.sync_stale, time)
            } else {
                context.getString(R.string.sync_ok, time)
            },
            isStale = isStale,
        )
    }
}
