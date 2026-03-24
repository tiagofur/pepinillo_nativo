package dev.creapolis.pepinillo.data.sync

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SyncMetadataStore @Inject constructor(
    @ApplicationContext context: Context,
) {
    private val prefs = context.getSharedPreferences("sync_metadata", Context.MODE_PRIVATE)

    var lastSessionSyncAt: String?
        get() = prefs.getString(KEY_LAST_SESSION_SYNC_AT, null)
        set(value) = prefs.edit().putString(KEY_LAST_SESSION_SYNC_AT, value).apply()

    private companion object {
        const val KEY_LAST_SESSION_SYNC_AT = "last_session_sync_at"
    }
}
