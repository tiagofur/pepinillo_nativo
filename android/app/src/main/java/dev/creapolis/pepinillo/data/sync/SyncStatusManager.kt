package dev.creapolis.pepinillo.data.sync

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.creapolis.pepinillo.data.local.dao.FocusSessionDao
import dev.creapolis.pepinillo.data.local.dao.PreferenceSyncDao
import dev.creapolis.pepinillo.data.local.dao.TaskDao
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import javax.inject.Inject
import javax.inject.Singleton

sealed class SyncState {
    data object Idle : SyncState()
    data object Syncing : SyncState()
    data class Error(val message: String) : SyncState()
}

private const val TAG = "SyncStatusManager"
private const val IMMEDIATE_SYNC_WORK = "pepinillo_immediate_sync"

@Singleton
class SyncStatusManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val taskDao: TaskDao,
    private val sessionDao: FocusSessionDao,
    private val preferenceSyncDao: PreferenceSyncDao,
) {

    // ── Network connectivity ──

    private val _isOnline = MutableStateFlow(true)
    val isOnline: StateFlow<Boolean> = _isOnline.asStateFlow()

    // ── Sync state ──

    private val _syncState = MutableStateFlow<SyncState>(SyncState.Idle)
    val syncState: StateFlow<SyncState> = _syncState.asStateFlow()

    // ── Last successful sync ──

    private val _lastSyncAt = MutableStateFlow<Long?>(null)
    val lastSyncAt: StateFlow<Long?> = _lastSyncAt.asStateFlow()

    // ── Pending dirty count (reactive from Room) ──

    val pendingChangesCount: Flow<Int> = combine(
        taskDao.getDirtyTaskCount(),
        sessionDao.getDirtySessionCount(),
        preferenceSyncDao.getDirtyPreferenceCount(),
    ) { dirtyTasks, dirtySessions, dirtyPrefs ->
        dirtyTasks + dirtySessions + dirtyPrefs
    }

    // ── Network callback ──

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            _isOnline.value = true
            Log.d(TAG, "Network available")
        }

        override fun onLost(network: Network) {
            _isOnline.value = false
            Log.d(TAG, "Network lost")
        }

        override fun onCapabilitiesChanged(
            network: Network,
            capabilities: NetworkCapabilities,
        ) {
            val hasInternet = capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            _isOnline.value = hasInternet
        }
    }

    init {
        val connectivityManager =
            context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        // Set initial state
        val activeNetwork = connectivityManager.activeNetwork
        val capabilities = activeNetwork?.let { connectivityManager.getNetworkCapabilities(it) }
        _isOnline.value = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true

        // Register for updates
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
        connectivityManager.registerNetworkCallback(request, networkCallback)
    }

    // ── State updates (called by SyncEngine) ──

    fun onSyncStarted() {
        _syncState.value = SyncState.Syncing
    }

    fun onSyncSuccess() {
        _syncState.value = SyncState.Idle
        _lastSyncAt.value = System.currentTimeMillis()
    }

    fun onSyncError(message: String) {
        _syncState.value = SyncState.Error(message)
    }

    // ── Trigger immediate sync ──

    fun requestImmediateSync() {
        Log.d(TAG, "Requesting immediate sync")
        val request = OneTimeWorkRequestBuilder<SyncWorker>().build()
        WorkManager.getInstance(context)
            .enqueueUniqueWork(
                IMMEDIATE_SYNC_WORK,
                ExistingWorkPolicy.REPLACE,
                request,
            )
    }
}
