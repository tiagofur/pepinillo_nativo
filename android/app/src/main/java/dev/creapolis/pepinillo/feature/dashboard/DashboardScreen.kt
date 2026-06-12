package dev.creapolis.pepinillo.feature.dashboard

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.DateRange
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Summarize
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.ui.graphics.Color
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PlainTooltip
import androidx.compose.material3.Text
import androidx.compose.material3.TooltipBox
import androidx.compose.material3.TooltipDefaults
import androidx.compose.material3.rememberTooltipState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.feature.dashboard.components.FocusChart
import dev.creapolis.pepinillo.feature.dashboard.components.ModeBreakdown
import dev.creapolis.pepinillo.feature.dashboard.model.Achievement
import dev.creapolis.pepinillo.feature.dashboard.model.AnalyticsPeriod
import dev.creapolis.pepinillo.feature.dashboard.model.isEmpty
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.ui.components.DashboardSkeleton
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(
    modifier: Modifier = Modifier,
    viewModel: DashboardViewModel = hiltViewModel(),
    onCalendarClick: () -> Unit = {},
    onNavigateToPaywall: () -> Unit = {},
    onStartFocusClick: () -> Unit = {},
    onNavigateToAIReport: () -> Unit = {},
) {
    val stats by viewModel.stats.collectAsState()
    val showWeeklyReview by viewModel.showWeeklyReview.collectAsState()
    val weeklyReport by viewModel.weeklyReport.collectAsState()
    val showMonthlyReview by viewModel.showMonthlyReview.collectAsState()
    val monthlyReport by viewModel.monthlyReport.collectAsState()
    val hasLocalPremium by viewModel.hasLocalPremium.collectAsState()
    val canUseAI by viewModel.canUseAI.collectAsState()

    if (stats.isLoading) {
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 16.dp),
        ) {
            Spacer(modifier = Modifier.height(60.dp))
            DashboardSkeleton()
        }
        return
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // ── HEADER + TOOLBAR ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = stringResource(R.string.dashboard_title),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = stringResource(R.string.dashboard_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Row {
                TooltipBox(
                    positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
                    tooltip = {
                        PlainTooltip {
                            Text(stringResource(R.string.ai_report_button))
                        }
                    },
                    state = rememberTooltipState()
                ) {
                    IconButton(onClick = {
                        if (canUseAI) onNavigateToAIReport() else onNavigateToPaywall()
                    }) {
                        Icon(
                            Icons.Rounded.AutoAwesome,
                            contentDescription = stringResource(R.string.ai_report_button),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                TooltipBox(
                    positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
                    tooltip = {
                        PlainTooltip {
                            Text(stringResource(R.string.cd_weekly_review))
                        }
                    },
                    state = rememberTooltipState()
                ) {
                    IconButton(onClick = {
                        if (hasLocalPremium) viewModel.showWeeklyReview() else onNavigateToPaywall()
                    }) {
                        Icon(
                            Icons.Rounded.Summarize,
                            contentDescription = stringResource(R.string.cd_weekly_review),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                TooltipBox(
                    positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
                    tooltip = {
                        PlainTooltip {
                            Text(stringResource(R.string.cd_monthly_review))
                        }
                    },
                    state = rememberTooltipState()
                ) {
                    IconButton(onClick = {
                        if (hasLocalPremium) viewModel.showMonthlyReview() else onNavigateToPaywall()
                    }) {
                        Icon(
                            Icons.Rounded.DateRange,
                            contentDescription = stringResource(R.string.cd_monthly_review),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                TooltipBox(
                    positionProvider = TooltipDefaults.rememberPlainTooltipPositionProvider(),
                    tooltip = {
                        PlainTooltip {
                            Text(stringResource(R.string.cd_calendar))
                        }
                    },
                    state = rememberTooltipState()
                ) {
                    IconButton(onClick = onCalendarClick) {
                        Icon(
                            Icons.Rounded.CalendarMonth,
                            contentDescription = stringResource(R.string.cd_calendar),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // ── EMPTY STATE ──
        if (stats.isEmpty) {
            EmptyDashboardState(
                onStartFocusClick = onStartFocusClick,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            )
            return@Column
        }

        // ── PERIOD PICKER ──
        PeriodPicker(
            selected = stats.selectedPeriod,
            onSelect = { period ->
                if (!hasLocalPremium && period != AnalyticsPeriod.Week) {
                    onNavigateToPaywall()
                } else {
                    viewModel.setPeriod(period)
                }
            },
            isPro = hasLocalPremium,
        )

        Spacer(modifier = Modifier.height(20.dp))

        // ── STREAK HERO ──
        // Streak is the emotional centrepiece of the dashboard — shown prominently
        // above the chart so it anchors the session and motivates continuation.
        StreakHeroCard(
            currentStreak = stats.currentStreak,
            bestStreak = stats.bestStreak,
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(modifier = Modifier.height(12.dp))

        // ── SUMMARY CARDS (Focus Time + Sessions) ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SummaryCard(
                title = stringResource(R.string.dashboard_focus_time),
                value = formatMinutes(stats.periodMinutes, stats.periodSessions > 0),
                icon = Icons.Rounded.AccessTime,
                modifier = Modifier.weight(1f),
            )
            SummaryCard(
                title = stringResource(R.string.dashboard_sessions),
                value = "${stats.periodSessions}",
                icon = Icons.Rounded.TaskAlt,
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // ── REFLECTION ACTION CARDS ──
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            val weeklyPreviewLine = if (!stats.isLoading && (weeklyReport.currentWeekMinutes > 0 || weeklyReport.currentWeekSessions > 0)) {
                stringResource(
                    R.string.dashboard_weekly_review_preview,
                    formatMinutes(weeklyReport.currentWeekMinutes),
                    weeklyReport.currentWeekSessions
                )
            } else {
                stringResource(R.string.dashboard_weekly_review_subtitle)
            }

            ReflectionCard(
                title = stringResource(R.string.cd_weekly_review),
                subtitle = weeklyPreviewLine,
                icon = Icons.Rounded.Summarize,
                tintColor = Color(0xFFFF9800), // Orange
                onClick = {
                    if (hasLocalPremium) viewModel.showWeeklyReview() else onNavigateToPaywall()
                }
            )

            val monthlyPreviewLine = if (!stats.isLoading && stats.selectedPeriod == AnalyticsPeriod.Month && (monthlyReport.currentMonthMinutes > 0 || monthlyReport.currentMonthSessions > 0)) {
                stringResource(
                    R.string.dashboard_monthly_review_preview,
                    formatMinutes(monthlyReport.currentMonthMinutes),
                    monthlyReport.currentMonthSessions
                )
            } else {
                stringResource(R.string.dashboard_monthly_review_subtitle)
            }

            ReflectionCard(
                title = stringResource(R.string.cd_monthly_review),
                subtitle = monthlyPreviewLine,
                icon = Icons.Rounded.DateRange,
                tintColor = Color(0xFF9C27B0), // Purple
                onClick = {
                    if (hasLocalPremium) viewModel.showMonthlyReview() else onNavigateToPaywall()
                }
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── FOCUS CHART ──
        SectionTitle(title = stringResource(R.string.dashboard_focus_minutes))
        Spacer(modifier = Modifier.height(12.dp))

        DashboardCard {
            FocusChart(
                data = stats.chartData,
                accentColor = MaterialTheme.colorScheme.primary,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── PRODUCTIVITY PATTERNS ──
        SectionTitle(title = stringResource(R.string.dashboard_patterns))
        Spacer(modifier = Modifier.height(12.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PatternCard(
                title = stringResource(R.string.dashboard_peak_hours),
                value = stats.peakHourRange.ifEmpty { "\u2013" },
                icon = Icons.Rounded.AccessTime,
                modifier = Modifier.weight(1f),
            )
            PatternCard(
                title = stringResource(R.string.dashboard_best_day),
                value = stats.bestDayOfWeek.ifEmpty { "\u2013" },
                icon = Icons.Rounded.Star,
                modifier = Modifier.weight(1f),
            )
        }
        Spacer(modifier = Modifier.height(12.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            PatternCard(
                title = stringResource(R.string.dashboard_focus_score),
                value = "${stats.focusScore}",
                icon = Icons.Rounded.EmojiEvents,
                modifier = Modifier.weight(1f),
            )
            // Placeholder for balance
            Box(modifier = Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── MODE BREAKDOWN ──
        if (stats.modeBreakdown.isNotEmpty()) {
            SectionTitle(title = stringResource(R.string.dashboard_focus_modes))
            Spacer(modifier = Modifier.height(12.dp))
            DashboardCard {
                ModeBreakdown(modes = stats.modeBreakdown)
            }
            Spacer(modifier = Modifier.height(28.dp))
        }

        // ── ACHIEVEMENTS ──
        if (stats.achievements.isNotEmpty()) {
            SectionTitle(title = stringResource(R.string.dashboard_achievements))
            Spacer(modifier = Modifier.height(12.dp))
            AchievementsRow(achievements = stats.achievements)
            Spacer(modifier = Modifier.height(28.dp))
        }

        Spacer(modifier = Modifier.height(24.dp))
    }

    // Weekly Review Bottom Sheet
    if (showWeeklyReview) {
        WeeklyReviewSheet(
            report = weeklyReport,
            onDismiss = { viewModel.dismissWeeklyReview() },
        )
    }

    // Monthly Review Bottom Sheet
    if (showMonthlyReview) {
        MonthlyReviewSheet(
            report = monthlyReport,
            onDismiss = { viewModel.dismissMonthlyReview() },
        )
    }
}

// ── Reusable Components ──

@Composable
private fun PeriodPicker(
    selected: AnalyticsPeriod,
    onSelect: (AnalyticsPeriod) -> Unit,
    isPro: Boolean = true,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        AnalyticsPeriod.entries.forEach { period ->
            val isSelected = period == selected
            val isLocked = !isPro && period != AnalyticsPeriod.Week
            val bgColor by animateColorAsState(
                targetValue = when {
                    isSelected -> MaterialTheme.colorScheme.primary
                    isLocked -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
                    else -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                },
                animationSpec = spring(),
                label = "periodBg",
            )
            val textColor by animateColorAsState(
                targetValue = when {
                    isSelected -> MaterialTheme.colorScheme.onPrimary
                    isLocked -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f)
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                },
                animationSpec = spring(),
                label = "periodText",
            )
            Row(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(20.dp))
                    .background(bgColor)
                    .clickable { onSelect(period) }
                    .padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (isLocked) {
                    Icon(
                        Icons.Rounded.Lock,
                        contentDescription = stringResource(R.string.cd_pro),
                        modifier = Modifier.size(12.dp),
                        tint = textColor,
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                }
                Text(
                    text = period.label,
                    style = MaterialTheme.typography.labelLarge,
                    color = textColor,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun SummaryCard(
    title: String,
    value: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.height(8.dp))
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
    }
}

@Composable
private fun PatternCard(
    title: String,
    value: String,
    icon: ImageVector,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(22.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/**
 * Streak hero card — the emotional centrepiece of the dashboard.
 * Shows the current streak large and centered with flame iconography,
 * and the personal best as a compact secondary stat.
 */
@Composable
private fun StreakHeroCard(
    currentStreak: Int,
    bestStreak: Int,
    modifier: Modifier = Modifier,
) {
    val streakColor = MaterialTheme.colorScheme.tertiary
    val streakContainerColor = MaterialTheme.colorScheme.tertiaryContainer

    Row(
        modifier = modifier
            .clip(RoundedCornerShape(20.dp))
            .background(streakContainerColor.copy(alpha = 0.7f))
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        // Flame icon + large streak number
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(
                imageVector = Icons.Rounded.LocalFireDepartment,
                contentDescription = null,
                modifier = Modifier.size(40.dp),
                tint = streakColor,
            )
            Column {
                Text(
                    text = stringResource(R.string.dashboard_days_count, currentStreak),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onTertiaryContainer,
                )
                Text(
                    text = stringResource(R.string.day_streak),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onTertiaryContainer.copy(alpha = 0.7f),
                )
            }
        }

        // Personal best — compact secondary stat
        if (bestStreak > 0) {
            Column(horizontalAlignment = Alignment.End) {
                Icon(
                    imageVector = Icons.Rounded.EmojiEvents,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp).align(Alignment.End),
                    tint = streakColor.copy(alpha = 0.7f),
                )
                Text(
                    text = stringResource(R.string.dashboard_days_count, bestStreak),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onTertiaryContainer.copy(alpha = 0.85f),
                )
                Text(
                    text = stringResource(R.string.dashboard_best),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onTertiaryContainer.copy(alpha = 0.6f),
                )
            }
        }
    }
}

@Composable
private fun AchievementsRow(achievements: List<Achievement>) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        achievements.forEach { achievement ->
            AchievementCard(achievement)
        }
    }
}

@Composable
private fun AchievementCard(achievement: Achievement) {
    Column(
        modifier = Modifier
            .width(100.dp)
            .clip(RoundedCornerShape(20.dp))
            .border(
                width = 1.dp,
                color = if (achievement.isUnlocked) MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                else MaterialTheme.colorScheme.outlineVariant,
                shape = RoundedCornerShape(20.dp),
            )
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = if (achievement.isUnlocked) achievement.icon else "\uD83D\uDD12",
            style = MaterialTheme.typography.headlineMedium,
        )
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = achievement.title,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
        if (!achievement.isUnlocked) {
            Spacer(modifier = Modifier.height(4.dp))
            LinearProgressIndicator(
                progress = { achievement.progress },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(RoundedCornerShape(2.dp)),
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceVariant,
                strokeCap = StrokeCap.Round,
            )
            Text(
                text = achievement.progressText,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurface,
    )
}

@Composable
private fun DashboardCard(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant,
                shape = RoundedCornerShape(20.dp),
            )
            .padding(20.dp),
    ) {
        content()
    }
}

@Composable
private fun EmptyDashboardState(
    modifier: Modifier = Modifier,
    onStartFocusClick: () -> Unit = {},
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Rounded.PlayArrow,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = stringResource(R.string.dashboard_no_sessions),
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = stringResource(R.string.dashboard_empty_desc),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            textAlign = TextAlign.Center,
        )
        Spacer(modifier = Modifier.height(20.dp))
        androidx.compose.material3.OutlinedButton(
            onClick = onStartFocusClick,
            shape = RoundedCornerShape(20.dp),
        ) {
            Icon(
                imageVector = Icons.Rounded.PlayArrow,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(stringResource(R.string.dashboard_btn_start))
        }
    }
}

@Composable
private fun ReflectionCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    tintColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(20.dp),
            )
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(tintColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(22.dp),
                tint = tintColor,
            )
        }
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Icon(
            imageVector = Icons.Rounded.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
            modifier = Modifier.size(20.dp),
        )
    }
}

private fun formatMinutes(totalMinutes: Int, hasSessions: Boolean = false): String {
    if (totalMinutes == 0 && hasSessions) return "< 1m"
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h ${minutes}m" else "${minutes}m"
}

@Preview(showBackground = true)
@Composable
private fun DashboardScreenPreview() {
    PepinilloTheme {
        DashboardScreen()
    }
}
