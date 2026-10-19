package dev.creapolis.pepinillo.presentation

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.wear.compose.foundation.pager.HorizontalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import androidx.wear.compose.material3.AppScaffold
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.TimeText
import dev.creapolis.pepinillo.data.WearDataFetcher
import dev.creapolis.pepinillo.data.WearDataStore
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearSyncStatusFormatter
import dev.creapolis.pepinillo.viewmodel.WearViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.lifecycle.lifecycleScope

class MainActivity : ComponentActivity() {
    private val viewModel: WearViewModel by viewModels()

    private val requestNotificationPermission = registerForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { /* One-shot: result intentionally ignored on first launch. */ }

    // Always-on / ambient support: track ambient state to dim the UI and reduce refresh rate.
    private var isAmbient by mutableStateOf(false)
    private val ambientCallback = object : AmbientLifecycleObserver.AmbientLifecycleCallback {
        override fun onEnterAmbient(ambientDetails: AmbientLifecycleObserver.AmbientDetails) {
            isAmbient = true
        }
        override fun onExitAmbient() {
            isAmbient = false
        }
        override fun onUpdateAmbient() {}
    }
    private lateinit var ambientObserver: AmbientLifecycleObserver

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        ambientObserver = AmbientLifecycleObserver(this, ambientCallback)
        lifecycle.addObserver(ambientObserver)
        WearSnapshotStore.bootstrap(this)
        maybeRequestNotificationPermission()
        lifecycleScope.launch(Dispatchers.IO) {
            WearDataFetcher.fetchAndApplyAll(this@MainActivity)
            WearDataFetcher.requestSyncFromPhone(this@MainActivity)
            // Retry: give the phone time to push data after sync request
            if (WearDataStore.tasks.value.isEmpty()) {
                delay(2_000)
                WearDataFetcher.fetchAndApplyAll(this@MainActivity)
            }
            if (WearDataStore.tasks.value.isEmpty()) {
                delay(5_000)
                WearDataFetcher.fetchAndApplyAll(this@MainActivity)
            }
        }
        setContent {
            WearApp(viewModel, isAmbient = isAmbient)
        }
    }

    /**
     * On API 33+ the foreground notification posted by WearFocusService requires the
     * POST_NOTIFICATIONS runtime permission. Without it the call silently no-ops, so we
     * ask once on first launch.
     */
    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            requestNotificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }
}

private const val TOTAL_PAGES = 4

@OptIn(androidx.wear.compose.foundation.ExperimentalWearFoundationApi::class)
@Composable
private fun WearApp(viewModel: WearViewModel, isAmbient: Boolean = false) {
    val timerState by viewModel.timerState.collectAsStateWithLifecycle()
    val tasks by viewModel.tasks.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val isPro by viewModel.isPro.collectAsStateWithLifecycle()
    val pendingCommandCount by viewModel.pendingCommandCount.collectAsStateWithLifecycle()
    val lastSyncAtMillis by viewModel.lastSyncAtMillis.collectAsStateWithLifecycle()
    val diagnostics by viewModel.diagnostics.collectAsStateWithLifecycle()

    val pagerState = rememberPagerState(initialPage = 1, pageCount = { TOTAL_PAGES })
    val context = androidx.compose.ui.platform.LocalContext.current
    val syncStatus = WearSyncStatusFormatter.format(
        context = context,
        lastSyncAtMillis = lastSyncAtMillis,
        isConnected = timerState.isConnected,
    )

    WearTheme {
        // AppScaffold manages TimeText at the app level and hosts the pager.
        // In ambient mode, TimeText is hidden to minimise lit pixels and burn-in risk.
        AppScaffold(
            timeText = { if (!isAmbient) TimeText() },
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background),
            ) { page ->
                // ScreenScaffold provides the per-page scroll indicator and vignette.
                // It replaces the old Scaffold(vignette, pageIndicator) pattern from M2.
                ScreenScaffold(
                    modifier = Modifier.fillMaxSize(),
                ) {
                    when (page) {
                        0 -> StatsScreen(
                            state = stats,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            isPro = isPro,
                            isActive = page == pagerState.settledPage,
                        )
                        1 -> TimerScreen(
                            state = timerState,
                            stats = stats,
                            pendingCommandCount = pendingCommandCount,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            isPro = isPro,
                            isAmbient = isAmbient,
                            onStartMode = viewModel::startTimer,
                            onPause = viewModel::pauseTimer,
                            onResume = viewModel::resumeTimer,
                            onStop = viewModel::stopTimer,
                            onSkip = viewModel::skipPhase,
                        )
                        2 -> TasksScreen(
                            tasks = tasks,
                            timerState = timerState,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            onCompleteTask = viewModel::completeTask,
                            onToggleTaskLink = viewModel::toggleTaskLink,
                            isActive = page == pagerState.settledPage,
                        )
                        // P2(f): cheap support surface — the diagnostics screen existed but
                        // was unreachable from the 3-page pager.
                        else -> DiagnosticsScreen(
                            timerState = timerState,
                            tasks = tasks,
                            stats = stats,
                            pendingCommandCount = pendingCommandCount,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            diagnostics = diagnostics,
                            isActive = page == pagerState.settledPage,
                        )
                    }
                }
            }
        }
    }
}
