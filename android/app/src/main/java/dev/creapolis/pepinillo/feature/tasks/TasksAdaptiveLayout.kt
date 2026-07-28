package dev.creapolis.pepinillo.feature.tasks

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.material3.adaptive.layout.ListDetailPaneScaffold
import androidx.compose.material3.adaptive.layout.ListDetailPaneScaffoldRole
import androidx.compose.material3.adaptive.navigation.rememberListDetailPaneScaffoldNavigator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.window.core.layout.WindowWidthSizeClass.Companion.EXPANDED
import androidx.window.core.layout.WindowWidthSizeClass.Companion.MEDIUM
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailScreen
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailViewModel
import kotlinx.coroutines.launch

/**
 * Adaptive wrapper around [TasksScreen] for the Plan tab (Sprint 7, #493).
 */
@OptIn(ExperimentalMaterial3AdaptiveApi::class)
@Composable
fun TasksAdaptiveLayout(
    onNavigateToAnalytics: (String) -> Unit,
    onNavigateToPaywall: () -> Unit,
    onStartFocusTask: () -> Unit,
) {
    // Two-pane on MEDIUM (foldables, landscape tablets 600–839dp) and EXPANDED (≥840dp).
    // Previously only EXPANDED was gated, leaving MEDIUM single-pane (#523). The
    // ListDetailPaneScaffold directive adapts its split policy automatically: at MEDIUM it
    // shows the list full-width with the detail as an animated overlay, at EXPANDED it splits.
    val windowSizeClass = currentWindowAdaptiveInfo().windowSizeClass
    val isExpanded = windowSizeClass.windowWidthSizeClass.let {
        it == MEDIUM || it == EXPANDED
    }

    if (isExpanded) {
        val navigator = rememberListDetailPaneScaffoldNavigator<String>()
        val scope = rememberCoroutineScope()

        BackHandler(navigator.canNavigateBack()) {
            scope.launch { navigator.navigateBack() }
        }

        ListDetailPaneScaffold(
            directive = navigator.scaffoldDirective,
            value = navigator.scaffoldValue,
            listPane = {
                TasksScreen(
                    onTaskClick = { taskId ->
                        scope.launch {
                            navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, taskId)
                        }
                    },
                    onNavigateToAnalytics = onNavigateToAnalytics,
                    onNavigateToPaywall = onNavigateToPaywall,
                    onStartFocusTask = onStartFocusTask,
                    useBottomSheet = false,
                )
            },
            detailPane = {
                val taskId = navigator.currentDestination?.contentKey
                if (taskId != null) {
                    val detailViewModel: TaskDetailViewModel = androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel(key = taskId)
                    LaunchedEffect(taskId) {
                        detailViewModel.initialize(taskId)
                    }
                    TaskDetailScreen(
                        onBack = { scope.launch { navigator.navigateBack() } },
                        onNavigateToPaywall = onNavigateToPaywall,
                        viewModel = detailViewModel,
                        onNavigateToAnalytics = { id ->
                            scope.launch {
                                navigator.navigateBack()
                                onNavigateToAnalytics(id)
                            }
                        },
                        onStartFocusTask = { _ -> onStartFocusTask() },
                    )
                } else {
                    DetailPlaceholder()
                }
            },
        )
    } else {
        TasksScreen(
            onTaskClick = {},
            onNavigateToAnalytics = onNavigateToAnalytics,
            onNavigateToPaywall = onNavigateToPaywall,
            onStartFocusTask = onStartFocusTask,
        )
    }
}

/** Empty-state for the detail pane when no task is selected in two-pane mode. */
@Composable
private fun DetailPlaceholder() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = "📋",
                style = MaterialTheme.typography.displayMedium,
            )
            Text(
                text = stringResource(R.string.select_task_to_view_details),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(24.dp),
            )
        }
    }
}
