package dev.creapolis.pepinillo.feature.dashboard

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
import androidx.compose.material.icons.rounded.LocalFireDepartment
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
import dev.creapolis.pepinillo.feature.dashboard.model.Trend
import dev.creapolis.pepinillo.feature.dashboard.model.WeeklyReportData
import dev.creapolis.pepinillo.R
import kotlin.math.abs

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WeeklyReviewSheet(
    report: WeeklyReportData,
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
                text = stringResource(R.string.review_weekly_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(20.dp))

            // ── COMPARISON CARDS ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TrendCard(
                    title = stringResource(R.string.review_focus_time),
                    value = formatMinutes(report.currentWeekMinutes, report.currentWeekSessions > 0),
                    delta = report.minutesDelta,
                    deltaLabel = stringResource(R.string.review_delta_minutes, abs(report.minutesDelta)),
                    trend = report.minutesTrend,
                    modifier = Modifier.weight(1f),
                )
                TrendCard(
                    title = stringResource(R.string.review_sessions),
                    value = "${report.currentWeekSessions}",
                    delta = report.sessionsDelta,
                    deltaLabel = "${abs(report.sessionsDelta)}",
                    trend = report.sessionsTrend,
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ── WEEK CHART ──
            Text(
                text = stringResource(R.string.review_this_week),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(modifier = Modifier.height(12.dp))
            SheetCard {
                FocusChart(
                    data = report.weeklyChartData,
                    accentColor = MaterialTheme.colorScheme.primary,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ── DOMINANT MODE ──
            if (report.dominantMode != null) {
                SheetCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = modeEmoji(report.dominantMode),
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

            // ── BEST DAY ──
            if (report.bestDayName != null && report.bestDayMinutes > 0) {
                SheetCard {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            Icons.Rounded.Star,
                            contentDescription = null,
                            modifier = Modifier.size(28.dp),
                            tint = Color(0xFFFFD700),
                        )
                        Spacer(modifier = Modifier.width(12.dp))
                        Column {
                            Text(
                                text = stringResource(R.string.review_best_day),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            Text(
                                text = "${report.bestDayName} \u2014 ${formatMinutes(report.bestDayMinutes)}",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // ── MODE DISTRIBUTION ──
            if (report.modeDistribution.isNotEmpty()) {
                Text(
                    text = stringResource(R.string.review_mode_distribution),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.height(12.dp))
                SheetCard {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        report.modeDistribution.forEach { mode ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                            ) {
                                Row {
                                    Text(text = modeEmoji(mode.modeLabel))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = mode.modeLabel,
                                        style = MaterialTheme.typography.bodyMedium,
                                    )
                                }
                                Text(
                                    text = formatMinutes(mode.totalMinutes),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
            }

            // ── STREAK ──
            SheetCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Rounded.LocalFireDepartment,
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = stringResource(R.string.review_current_streak),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Text(
                            text = stringResource(R.string.dashboard_days_count, report.currentStreak),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun TrendCard(
    title: String,
    value: String,
    delta: Int,
    deltaLabel: String,
    trend: Trend,
    modifier: Modifier = Modifier,
) {
    val trendColor = when (trend) {
        Trend.Up -> Color(0xFF4CAF50)
        Trend.Down -> Color(0xFFF44336)
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
private fun SheetCard(content: @Composable () -> Unit) {
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

private fun modeEmoji(mode: String): String = when (mode) {
    "Pomodoro" -> "\uD83C\uDF45"
    "Flow" -> "\uD83C\uDF0A"
    "Blocks" -> "\uD83D\uDCE6"
    "Chrono" -> "\u23F1\uFE0F"
    else -> "\uD83C\uDFAF"
}

private fun formatMinutes(totalMinutes: Int, hasSessions: Boolean = false): String {
    if (totalMinutes == 0 && hasSessions) return "< 1m"
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}
