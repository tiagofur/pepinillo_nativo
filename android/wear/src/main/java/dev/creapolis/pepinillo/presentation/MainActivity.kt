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
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.ambient.AmbientLifecycleObserver
import androidx.wear.compose.foundation.pager.HorizontalPager
import androidx.wear.compose.foundation.pager.rememberPagerState
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PageIndicatorState
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition
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

private const val TOTAL_PAGES = 3

@OptIn(androidx.wear.compose.foundation.ExperimentalWearFoundationApi::class)
@Composable
private fun WearApp(viewModel: WearViewModel, isAmbient: Boolean = false) {
    val timerState by viewModel.timerState.collectAsStateWithLifecycle()
    val tasks by viewModel.tasks.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val isPro by viewModel.isPro.collectAsStateWithLifecycle()
    val pendingCommandCount by viewModel.pendingCommandCount.collectAsStateWithLifecycle()
    val lastSyncAtMillis by viewModel.lastSyncAtMillis.collectAsStateWithLifecycle()

    val pagerState = rememberPagerState(initialPage = 1, pageCount = { TOTAL_PAGES })
    val syncStatus = WearSyncStatusFormatter.format(
        lastSyncAtMillis = lastSyncAtMillis,
        isConnected = timerState.isConnected,
    )

    // Always show the wall-clock — it's the #1 checked info on a watch.
    // Previously hidden during Running/Paused, which was jarring during 25-min sessions.

    val pageIndicatorState = remember {
        object : PageIndicatorState {
            override val pageCount: Int get() = TOTAL_PAGES
            override val pageOffset: Float get() = pagerState.currentPageOffsetFraction
            override val selectedPage: Int get() = pagerState.currentPage
        }
    }

    WearTheme {
        Scaffold(
            // In ambient mode: hide chrome (TimeText, vignette, page indicator) to minimize
            // lit pixels and burn-in risk — only the dimmed timer display remains.
            timeText = { if (!isAmbient) TimeText() },
            vignette = { if (!isAmbient) Vignette(vignettePosition = VignettePosition.TopAndBottom) },
            pageIndicator = {
                if (!isAmbient) {
                    HorizontalPageIndicator(
                        pageIndicatorState = pageIndicatorState,
                        selectedColor = MaterialTheme.colors.primary,
                        unselectedColor = MaterialTheme.colors.onSurface.copy(alpha = 0.3f),
                    )
                }
            },
        ) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colors.background),
            ) { page ->
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
                    else -> TasksScreen(
                        tasks = tasks,
                        timerState = timerState,
                        syncStatusLabel = syncStatus.label,
                        isSyncStale = syncStatus.isStale,
                        onCompleteTask = viewModel::completeTask,
                        onToggleTaskLink = viewModel::toggleTaskLink,
                        isActive = page == pagerState.settledPage,
                    )
                }
            }
        }
    }
}
