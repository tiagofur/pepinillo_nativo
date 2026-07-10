package dev.creapolis.pepinillo.feature.dashboard

import dev.creapolis.pepinillo.ui.theme.DomainColors

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.feature.dashboard.components.FocusChart
import dev.creapolis.pepinillo.feature.dashboard.model.MonthlyReportData
import dev.creapolis.pepinillo.feature.dashboard.model.Trend
import dev.creapolis.pepinillo.R
import kotlin.math.abs

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MonthlyReviewSheet(
    report: MonthlyReportData,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp),
        ) {
            Text(
                text = stringResource(R.string.review_monthly_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(12.dp))

            // ── HERO HEADLINE — emotional "wrap-up" sentence ──
            MonthlyReviewHeadline(
                minutes = report.currentMonthMinutes,
                hasSessions = report.currentMonthSessions > 0,
                trend = report.minutesTrend,
                deltaMinutes = abs(report.minutesDelta),
            )

            Spacer(modifier = Modifier.height(20.dp))

            // -- COMPARISON CARDS --
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                MonthlyTrendCard(
                    title = stringResource(R.string.review_focus_time),
                    value = formatMonthlyMinutes(report.currentMonthMinutes, report.currentMonthSessions > 0),
                    delta = report.minutesDelta,
                    deltaLabel = stringResource(R.string.review_delta_minutes, abs(report.minutesDelta)),
                    trend = report.minutesTrend,
                    modifier = Modifier.weight(1f),
                )
                MonthlyTrendCard(
                    title = stringResource(R.string.review_sessions),
                    value = "${report.currentMonthSessions}",
                    delta = report.sessionsDelta,
                    deltaLabel = "${abs(report.sessionsDelta)}",
                    trend = report.sessionsTrend,
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // -- COMPLETION RATE --
            MonthlySheetCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Rounded.CheckCircle,
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        tint = DomainColors.Positive,
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = stringResource(R.string.review_completion_rate),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = "${(report.completionRate * 100).toInt()}%",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // -- MONTH CHART --
            Text(
                text = stringResource(R.string.review_this_month),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.height(12.dp))
            MonthlySheetCard {
                FocusChart(
                    data = report.monthlyChartData,
                    accentColor = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // -- BEST WEEK --
            if (report.bestWeekLabel != null && report.bestWeekMinutes > 0) {
                val resolvedLabel = if (report.bestWeekLabel.startsWith("WEEK_LABEL:")) {
                    val weekNum = report.bestWeekLabel.removePrefix("WEEK_LABEL:").toIntOrNull() ?: 0
                    stringResource(R.string.more_week_label, weekNum)
                } else {
                    report.bestWeekLabel
                }

                MonthlySheetCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Rounded.Star,
                            contentDescription = null,
                            modifier = Modifier.size(28.dp),
                            tint = DomainColors.Gold,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = stringResource(R.string.review_best_week),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                text = "$resolvedLabel \u2014 ${formatMonthlyMinutes(report.bestWeekMinutes)}",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // -- TOP TASKS --
            if (report.topTasks.isNotEmpty()) {
                Text(
                    text = stringResource(R.string.review_top_tasks),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.height(12.dp))
                MonthlySheetCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        report.topTasks.forEach { task ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Text(
                                    text = task.taskTitle,
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier.weight(1f),
                                    maxLines = 1,
                                )
                                Text(
                                    text = formatMonthlyMinutes(task.totalMinutes),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // -- DOMINANT MODE --
            if (report.dominantMode != null) {
                MonthlySheetCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = monthlyModeEmoji(report.dominantMode),
                            style = MaterialTheme.typography.headlineMedium,
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = stringResource(R.string.review_dominant_mode),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                text = report.dominantMode,
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // -- MODE DISTRIBUTION --
            if (report.modeDistribution.isNotEmpty()) {
                Text(
                    text = stringResource(R.string.review_mode_distribution),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.height(12.dp))
                MonthlySheetCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        report.modeDistribution.forEach { mode ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Row {
                                    Text(text = monthlyModeEmoji(mode.modeLabel))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = mode.modeLabel,
                                        style = MaterialTheme.typography.bodyMedium,
                                    )
                                }
                                Text(
                                    text = formatMonthlyMinutes(mode.totalMinutes),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MonthlyTrendCard(
    title: String,
    value: String,
    delta: Int,
    deltaLabel: String,
    trend: Trend,
    modifier: Modifier = Modifier,
) {
    val trendColor = when (trend) {
        Trend.Up -> DomainColors.Positive
        Trend.Down -> DomainColors.Negative
        Trend.Neutral -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val trendIcon = when (trend) {
        Trend.Up -> Icons.Rounded.ArrowUpward
        Trend.Down -> Icons.Rounded.ArrowDownward
        Trend.Neutral -> Icons.Rounded.Remove
    }

    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                trendIcon,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = trendColor,
            )
            Spacer(modifier = Modifier.width(2.dp))
            Text(
                text = if (delta == 0) "\u2014" else if (delta > 0) "+$deltaLabel" else "-$deltaLabel",
                style = MaterialTheme.typography.labelSmall,
                color = trendColor,
            )
        }
    }
}

@Composable
private fun MonthlySheetCard(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant,
                shape = RoundedCornerShape(20.dp),
            )
            .padding(16.dp),
    ) {
        content()
    }
}

private fun monthlyModeEmoji(mode: String): String = when (mode) {
    "Pomodoro" -> "\uD83C\uDF45"
    "Flow" -> "\uD83C\uDF0A"
    "Blocks" -> "\uD83D\uDCE6"
    "Chrono" -> "\u23F1\uFE0F"
    else -> "\uD83C\uDFAF"
}

private fun formatMonthlyMinutes(totalMinutes: Int, hasSessions: Boolean = false): String {
    if (totalMinutes == 0 && hasSessions) return "< 1m"
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

/** Monthly version of the hero headline — trend only (monthly data has no streak). */
@Composable
private fun MonthlyReviewHeadline(
    minutes: Int,
    hasSessions: Boolean,
    trend: dev.creapolis.pepinillo.feature.dashboard.model.Trend,
    deltaMinutes: Int,
) {
    val timeStr = formatMonthlyMinutes(minutes, hasSessions)
    val headlineRes = when (trend) {
        dev.creapolis.pepinillo.feature.dashboard.model.Trend.Up -> R.string.review_monthly_headline_up
        dev.creapolis.pepinillo.feature.dashboard.model.Trend.Down -> R.string.review_monthly_headline_down
        dev.creapolis.pepinillo.feature.dashboard.model.Trend.Neutral -> R.string.review_monthly_headline_steady
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f))
            .padding(16.dp),
    ) {
        Text(
            text = stringResource(headlineRes, timeStr, "${deltaMinutes}m"),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
        )
    }
}
