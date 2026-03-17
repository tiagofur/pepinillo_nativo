package dev.creapolis.pepinillo.presentation

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.creapolis.pepinillo.viewmodel.WearViewModel
import androidx.wear.compose.material.HorizontalPageIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.TimeText

class MainActivity : ComponentActivity() {
    private val viewModel: WearViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
    val pagerState = rememberPagerState(initialPage = 1, pageCount = { 3 })

    WearTheme {
        Scaffold(
            timeText = { TimeText() },
            pageIndicator = {
                HorizontalPageIndicator(
                    pageCount = 3,
                    currentPage = pagerState.currentPage,
                    modifier = Modifier,
                )
            },
        ) {
            HorizontalPager(state = pagerState) { page ->
                when (page) {
                    0 -> StatsScreen(stats)
                    1 -> TimerScreen(
                        state = timerState,
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
        }
    }
}
