package dev.creapolis.pepinillo.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
import kotlin.math.abs

class MainActivity : ComponentActivity() {
    private val viewModel: WearViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WearSnapshotStore.bootstrap(this)
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
            WearApp(viewModel)
        }
    }
}

private const val TOTAL_PAGES = 3
private const val SWIPE_THRESHOLD = 50f // minimum pixels to register as a swipe

@Composable
private fun WearApp(viewModel: WearViewModel) {
    val timerState by viewModel.timerState.collectAsStateWithLifecycle()
    val tasks by viewModel.tasks.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val pendingCommandCount by viewModel.pendingCommandCount.collectAsStateWithLifecycle()
    val lastSyncAtMillis by viewModel.lastSyncAtMillis.collectAsStateWithLifecycle()

    // Hub-and-spoke: Dashboard(0) ← Timer(1) → Tasks(2)
    var currentPage by remember { mutableIntStateOf(1) }

    val syncStatus = WearSyncStatusFormatter.format(
        lastSyncAtMillis = lastSyncAtMillis,
        isConnected = timerState.isConnected,
    )

    val showTimeText = timerState.status != "Running" && timerState.status != "Paused"

    val pageIndicatorState = remember(currentPage) {
        object : PageIndicatorState {
            override val pageCount: Int get() = TOTAL_PAGES
            override val pageOffset: Float get() = 0f
            override val selectedPage: Int get() = currentPage
        }
    }

    WearTheme {
        Scaffold(
            timeText = { if (showTimeText) TimeText() },
            vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
            pageIndicator = {
                HorizontalPageIndicator(
                    pageIndicatorState = pageIndicatorState,
                    selectedColor = MaterialTheme.colors.primary,
                    unselectedColor = MaterialTheme.colors.onSurface.copy(alpha = 0.3f),
                )
            },
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colors.background)
                    .pointerInput(currentPage) {
                        var totalDrag = 0f
                        detectHorizontalDragGestures(
                            onDragStart = { totalDrag = 0f },
                            onDragEnd = {
                                if (abs(totalDrag) > SWIPE_THRESHOLD) {
                                    if (totalDrag < 0 && currentPage < TOTAL_PAGES - 1) {
                                        // Swipe left → next page
                                        currentPage++
                                    } else if (totalDrag > 0 && currentPage > 0) {
                                        // Swipe right → previous page
                                        currentPage--
                                    }
                                }
                            },
                            onHorizontalDrag = { _, dragAmount ->
                                totalDrag += dragAmount
                            },
                        )
                    },
            ) {
                when (currentPage) {
                    0 -> StatsScreen(
                        state = stats,
                        syncStatusLabel = syncStatus.label,
                        isSyncStale = syncStatus.isStale,
                    )
                    1 -> TimerScreen(
                        state = timerState,
                        stats = stats,
                        pendingCommandCount = pendingCommandCount,
                        syncStatusLabel = syncStatus.label,
                        isSyncStale = syncStatus.isStale,
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
                    )
                }
            }
        }
    }
}
