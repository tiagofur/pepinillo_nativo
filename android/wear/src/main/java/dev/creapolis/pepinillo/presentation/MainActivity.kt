package dev.creapolis.pepinillo.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import dev.creapolis.pepinillo.data.WearSnapshotStore
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
    val pagerState = rememberPagerState(initialPage = 1, pageCount = { 3 })

    WearTheme {
        Scaffold(
            timeText = { TimeText() },
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize(),
            ) {
                HorizontalPager(state = pagerState) { page ->
                    when (page) {
                        0 -> StatsScreen(stats)
                        1 -> TimerScreen(
                            state = timerState,
                            pendingCommandCount = pendingCommandCount,
                            onStartMode = viewModel::startTimer,
                            onPause = viewModel::pauseTimer,
                            onResume = viewModel::resumeTimer,
                            onStop = viewModel::stopTimer,
                        )
                        else -> TasksScreen(
                            tasks = tasks,
                            onCompleteTask = viewModel::completeTask,
                        )
                    }
                }

                PageDots(
                    currentPage = pagerState.currentPage,
                    totalPages = 3,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 4.dp),
                )
            }
        }
    }
}

@Composable
private fun PageDots(
    currentPage: Int,
    totalPages: Int,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        repeat(totalPages) { index ->
            Text(if (index == currentPage) "●" else "○")
        }
    }
}
