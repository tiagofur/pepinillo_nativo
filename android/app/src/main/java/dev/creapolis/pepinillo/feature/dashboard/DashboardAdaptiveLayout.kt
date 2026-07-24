package dev.creapolis.pepinillo.feature.dashboard

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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.window.core.layout.WindowWidthSizeClass
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.feature.calendar.CalendarScreen
import kotlinx.coroutines.launch

/**
 * Adaptive wrapper around [DashboardScreen] for the Dashboard tab (Sprint 7, #493).
 *
 * - **Compact widths (phones):** renders [DashboardScreen] exactly as before — Calendar and AI
 *   Report open as full NavHost destinations. No visual change.
 * - **Expanded widths (tablets, foldables open):** renders a two-pane [ListDetailPaneScaffold]
 *   with the Dashboard cards on the left and the selected report (Calendar or AI Report) on the
 *   right. Selection state is owned by the scaffold navigator and survives configuration changes.
 *
 * Note: Calendar/AI Report are rendered inline (own VM via `hiltViewModel()`) rather than via the
 * NavHost, so their shared-element transitions are not active in the pane — the pane swap provides
 * the animation instead. The Compact path is unaffected and keeps its NavHost-driven transitions.
 */
@OptIn(ExperimentalMaterial3AdaptiveApi::class)
@Composable
fun DashboardAdaptiveLayout(
    onCalendarClick: () -> Unit,
    onNavigateToPaywall: () -> Unit,
    onStartFocusClick: () -> Unit,
    onNavigateToAIReport: () -> Unit,
) {
    val windowSizeClass = currentWindowAdaptiveInfo().windowSizeClass
    val isExpanded = windowSizeClass.windowWidthSizeClass == WindowWidthSizeClass.EXPANDED

    if (isExpanded) {
        val navigator = rememberListDetailPaneScaffoldNavigator<DashboardDetail>()
        val scope = rememberCoroutineScope()

        BackHandler(navigator.canNavigateBack()) {
            scope.launch { navigator.navigateBack() }
        }

        ListDetailPaneScaffold(
            directive = navigator.scaffoldDirective,
            value = navigator.scaffoldValue,
            listPane = {
                DashboardScreen(
                    onCalendarClick = {
                        scope.launch {
                            navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, DashboardDetail.Calendar)
                        }
                    },
                    onNavigateToPaywall = onNavigateToPaywall,
                    onStartFocusClick = onStartFocusClick,
                    onNavigateToAIReport = {
                        scope.launch {
                            navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, DashboardDetail.AIReport)
                        }
                    },
                )
            },
            detailPane = {
                val currentDestination = navigator.currentDestination
                val detail = currentDestination?.contentKey as? DashboardDetail
                when (detail) {
                    DashboardDetail.Calendar -> CalendarScreen(
                        onBack = { scope.launch { navigator.navigateBack() } },
                    )
                    DashboardDetail.AIReport -> AIReportScreen(
                        onBack = { scope.launch { navigator.navigateBack() } },
                    )
                    null -> DashboardDetailPlaceholder()
                }
            },
        )
    } else {
        DashboardScreen(
            onCalendarClick = onCalendarClick,
            onNavigateToPaywall = onNavigateToPaywall,
            onStartFocusClick = onStartFocusClick,
            onNavigateToAIReport = onNavigateToAIReport,
        )
    }
}

/** Which report is shown in the Dashboard detail pane. */
private enum class DashboardDetail { Calendar, AIReport }

/** Empty-state for the detail pane when no report is selected in two-pane mode. */
@Composable
private fun DashboardDetailPlaceholder() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = "📊",
                style = MaterialTheme.typography.displayMedium,
            )
            Text(
                text = stringResource(R.string.select_dashboard_detail),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(24.dp),
            )
        }
    }
}
