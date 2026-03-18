package dev.creapolis.pepinillo.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PageIndicatorState
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition
import dev.creapolis.pepinillo.data.WearSnapshotStore
import dev.creapolis.pepinillo.data.WearSyncStatusFormatter
import dev.creapolis.pepinillo.viewmodel.WearViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: WearViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WearSnapshotStore.bootstrap(this)
        setContent {
            WearApp(viewModel)
        }
    }
}

@Composable
private fun WearApp(viewModel: WearViewModel) {
    val timerState by viewModel.timerState.collectAsStateWithLifecycle()
    val tasks by viewModel.tasks.collectAsStateWithLifecycle()
    val stats by viewModel.stats.collectAsStateWithLifecycle()
    val pendingCommandCount by viewModel.pendingCommandCount.collectAsStateWithLifecycle()
    val lastSyncAtMillis by viewModel.lastSyncAtMillis.collectAsStateWithLifecycle()
    val diagnostics by viewModel.diagnostics.collectAsStateWithLifecycle()

    val totalPages = 4
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { totalPages })

    val syncStatus = WearSyncStatusFormatter.format(
        lastSyncAtMillis = lastSyncAtMillis,
        isConnected = timerState.isConnected,
    )

    val showTimeText = timerState.status != "Running" && timerState.status != "Paused"

    val pageIndicatorState = rememberPageIndicatorState(pagerState, totalPages)

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
                    .background(MaterialTheme.colors.background),
            ) {
                HorizontalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                ) { page ->
                    when (page) {
                        0 -> TimerScreen(
                            state = timerState,
                            pendingCommandCount = pendingCommandCount,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            onStartMode = viewModel::startTimer,
                            onPause = viewModel::pauseTimer,
                            onResume = viewModel::resumeTimer,
                            onStop = viewModel::stopTimer,
                        )
                        1 -> StatsScreen(
                            state = stats,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                        )
                        2 -> TasksScreen(
                            tasks = tasks,
                            timerState = timerState,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            onCompleteTask = viewModel::completeTask,
                        )
                        else -> DiagnosticsScreen(
                            timerState = timerState,
                            tasks = tasks,
                            stats = stats,
                            pendingCommandCount = pendingCommandCount,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            diagnostics = diagnostics,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun rememberPageIndicatorState(
    pagerState: PagerState,
    totalPages: Int,
): PageIndicatorState {
    return object : PageIndicatorState {
        override val pageCount: Int get() = totalPages
        override val pageOffset: Float get() = pagerState.currentPageOffsetFraction
        override val selectedPage: Int get() = pagerState.currentPage
    }
}
