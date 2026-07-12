package dev.creapolis.pepinillo.data

import android.content.res.Resources
import dev.creapolis.pepinillo.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WearSyncStatus(
    val label: String?,
    val isStale: Boolean,
)

data class SyncStatusStrings(
    val waitingFirst: String,
    val disconnectedLastFormat: String,
    val staleFormat: String,
    val okFormat: String,
) {
    companion object {
        fun from(resources: Resources): SyncStatusStrings = SyncStatusStrings(
            waitingFirst = resources.getString(R.string.sync_waiting_first),
            disconnectedLastFormat = resources.getString(R.string.sync_disconnected_last),
            staleFormat = resources.getString(R.string.sync_stale),
            okFormat = resources.getString(R.string.sync_ok),
        )
    }
}

object WearSyncStatusFormatter {
    private const val STALE_AFTER_MILLIS = 2 * 60 * 1000L

    fun format(
        resources: Resources,
        lastSyncAtMillis: Long?,
        isConnected: Boolean,
        nowMillis: Long = System.currentTimeMillis(),
        locale: Locale = Locale.getDefault(),
    ): WearSyncStatus = format(
        strings = SyncStatusStrings.from(resources),
        lastSyncAtMillis = lastSyncAtMillis,
        isConnected = isConnected,
        nowMillis = nowMillis,
        locale = locale,
    )

    fun format(
        strings: SyncStatusStrings,
        lastSyncAtMillis: Long?,
        isConnected: Boolean,
        nowMillis: Long = System.currentTimeMillis(),
        locale: Locale = Locale.getDefault(),
    ): WearSyncStatus {
        if (lastSyncAtMillis == null) {
            return WearSyncStatus(
                label = if (isConnected) strings.waitingFirst else null,
                isStale = false,
            )
        }

        val time = SimpleDateFormat("HH:mm", locale).format(Date(lastSyncAtMillis))
        if (!isConnected) {
            return WearSyncStatus(
                label = strings.disconnectedLastFormat.format(time),
                isStale = true,
            )
        }

        val isStale = nowMillis - lastSyncAtMillis > STALE_AFTER_MILLIS
        return WearSyncStatus(
            label = if (isStale) {
                strings.staleFormat.format(time)
            } else {
                strings.okFormat.format(time)
            },
            isStale = isStale,
        )
    }
}