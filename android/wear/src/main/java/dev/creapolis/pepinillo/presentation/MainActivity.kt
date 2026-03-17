package dev.creapolis.pepinillo.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.MaterialTheme
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
    val pagerState = rememberPagerState(initialPage = 1, pageCount = { 4 })
    val syncStatus = WearSyncStatusFormatter.format(
        lastSyncAtMillis = lastSyncAtMillis,
        isConnected = timerState.isConnected,
    )

    // Hide TimeText when timer is active to avoid overlap
    val showTimeText = timerState.status != "Running" && timerState.status != "Paused"

    WearTheme {
        Scaffold(
            timeText = { if (showTimeText) TimeText() },
            vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colors.background),
            ) {
                HorizontalPager(state = pagerState) { page ->
                    when (page) {
                        0 -> StatsScreen(
                            state = stats,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                        )
                        1 -> TimerScreen(
                            state = timerState,
                            pendingCommandCount = pendingCommandCount,
                            syncStatusLabel = syncStatus.label,
                            isSyncStale = syncStatus.isStale,
                            onStartMode = viewModel::startTimer,
                            onPause = viewModel::pauseTimer,
                            onResume = viewModel::resumeTimer,
                            onStop = viewModel::stopTimer,
                        )
                        2 -> TasksScreen(
                            tasks = tasks,
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

                PageIndicator(
                    currentPage = pagerState.currentPage,
                    totalPages = 4,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 8.dp),
                )
            }
        }
    }
}

@Composable
private fun PageIndicator(
    currentPage: Int,
    totalPages: Int,
    modifier: Modifier = Modifier,
) {
    val activeColor = MaterialTheme.colors.primary
    val inactiveColor = MaterialTheme.colors.onSurface.copy(alpha = 0.3f)

    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(totalPages) { index ->
            val color = if (index == currentPage) activeColor else inactiveColor
            val size = if (index == currentPage) 6.dp else 4.dp
            Canvas(modifier = Modifier.size(size)) {
                drawCircle(
                    color = color,
                    radius = this.size.minDimension / 2f,
                    center = Offset(this.size.width / 2f, this.size.height / 2f),
                )
            }
        }
    }
}
