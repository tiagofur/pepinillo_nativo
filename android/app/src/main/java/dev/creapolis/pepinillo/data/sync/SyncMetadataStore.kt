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

    /**
     * True once [InitialSyncManager] has successfully applied a full server snapshot
     * in a single transaction. Prevents [SyncEngine.hasLocalData] from treating a
     * partial failed initial pull as complete local data (which would trigger upload).
     */
    var initialPullComplete: Boolean
        get() = prefs.getBoolean(KEY_INITIAL_PULL_COMPLETE, false)
        set(value) = prefs.edit().putBoolean(KEY_INITIAL_PULL_COMPLETE, value).apply()

    private companion object {
        const val KEY_LAST_SESSION_SYNC_AT = "last_session_sync_at"
        const val KEY_INITIAL_PULL_COMPLETE = "initial_pull_complete"
    }
}
