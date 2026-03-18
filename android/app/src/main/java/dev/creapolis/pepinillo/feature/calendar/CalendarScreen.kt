package dev.creapolis.pepinillo.feature.calendar

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBackIosNew
import androidx.compose.material.icons.rounded.ArrowForwardIos
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Circle
import androidx.compose.material.icons.rounded.Nightlight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.data.repository.SessionRepository
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

@Composable
fun CalendarScreen(
    onBack: () -> Unit = {},
    modifier: Modifier = Modifier,
    viewModel: CalendarViewModel = hiltViewModel(),
) {
    val displayedMonth by viewModel.displayedMonth.collectAsState()
    val selectedDate by viewModel.selectedDate.collectAsState()
    val activityDays by viewModel.activityDays.collectAsState()
    val dayDetail by viewModel.dayDetail.collectAsState()

    val calendar = remember { Calendar.getInstance() }
    val monthFormat = remember { SimpleDateFormat("MMMM yyyy", Locale.getDefault()) }
    val weekdaySymbols = remember {
        val cal = Calendar.getInstance()
        val fmt = SimpleDateFormat("EEE", Locale.getDefault())
        val firstDay = cal.firstDayOfWeek
        (0 until 7).map { i ->
            cal.set(Calendar.DAY_OF_WEEK, firstDay + i)
            fmt.format(cal.time)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // ── BACK + TITLE ──
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.Rounded.ArrowBackIosNew, contentDescription = "Back", modifier = Modifier.size(20.dp))
            }
            Text(
                text = "Calendar",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // ── MONTH HEADER ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = { viewModel.previousMonth() }) {
                Icon(Icons.Rounded.ArrowBackIosNew, contentDescription = "Previous month", modifier = Modifier.size(18.dp))
            }
            Text(
                text = monthFormat.format(displayedMonth.time),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            IconButton(onClick = { viewModel.nextMonth() }) {
                Icon(Icons.Rounded.ArrowForwardIos, contentDescription = "Next month", modifier = Modifier.size(18.dp))
            }
        }

        Spacer(modifier = Modifier.height(12.dp))

        // ── CALENDAR GRID ──
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(24.dp))
                .padding(16.dp),
        ) {
            Column {
                // Weekday headers
                Row(modifier = Modifier.fillMaxWidth()) {
                    weekdaySymbols.forEach { symbol ->
                        Text(
                            text = symbol,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Calendar days
                val daysData = remember(displayedMonth) {
                    buildCalendarDays(displayedMonth)
                }

                daysData.chunked(7).forEach { week ->
                    Row(modifier = Modifier.fillMaxWidth()) {
                        week.forEach { dayData ->
                            if (dayData == null) {
                                Box(modifier = Modifier.weight(1f).height(48.dp))
                            } else {
                                val dayMillis = dayData.dateMillis
                                val isToday = dayData.isToday
                                val isSelected = selectedDate == dayMillis
                                val hasActivity = activityDays.contains(dayMillis)
                                val isFuture = dayData.isFuture

                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .height(48.dp)
                                        .clickable(enabled = !isFuture) {
                                            viewModel.selectDay(dayMillis)
                                        },
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                        Box(
                                            modifier = Modifier
                                                .size(34.dp)
                                                .then(
                                                    if (isSelected) Modifier
                                                        .clip(CircleShape)
                                                        .background(MaterialTheme.colorScheme.primary)
                                                    else if (isToday) Modifier
                                                        .border(1.5.dp, MaterialTheme.colorScheme.primary, CircleShape)
                                                    else Modifier
                                                ),
                                            contentAlignment = Alignment.Center,
                                        ) {
                                            Text(
                                                text = "${dayData.dayNumber}",
                                                style = MaterialTheme.typography.bodyMedium,
                                                fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
                                                color = when {
                                                    isSelected -> MaterialTheme.colorScheme.onPrimary
                                                    isFuture -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                                                    isToday -> MaterialTheme.colorScheme.primary
                                                    else -> MaterialTheme.colorScheme.onSurface
                                                },
                                            )
                                        }
                                        // Activity dot
                                        Box(
                                            modifier = Modifier
                                                .size(5.dp)
                                                .clip(CircleShape)
                                                .background(
                                                    if (hasActivity && !isSelected) MaterialTheme.colorScheme.primary
                                                    else MaterialTheme.colorScheme.surface // invisible
                                                ),
                                        )
                                    }
                                }
                            }
                        }
                        // Pad incomplete week
                        repeat(7 - week.size) {
                            Box(modifier = Modifier.weight(1f).height(48.dp))
                        }
                    }
                }
            }
        }

        // ── DAY DETAIL ──
        AnimatedVisibility(
            visible = dayDetail != null,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            dayDetail?.let { detail ->
                Spacer(modifier = Modifier.height(16.dp))
                DayDetailCard(detail)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }
}

@Composable
private fun DayDetailCard(detail: DayDetail) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(24.dp))
            .padding(20.dp),
    ) {
        Text(
            text = detail.dateLabel,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
        )

        if (detail.sessionsCompleted > 0 || detail.taskCount > 0) {
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly,
            ) {
                SummaryItem(value = "${detail.totalMinutes}", label = "min")
                SummaryItem(value = "${detail.sessionsCompleted}", label = "sessions")
                SummaryItem(value = "${detail.taskCount}", label = "tasks")
            }
        }

        if (detail.sessions.isNotEmpty()) {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Focus Sessions",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(8.dp))
            detail.sessions.forEach { session ->
                SessionRow(session)
            }
        }

        if (detail.tasks.isNotEmpty()) {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Tasks",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(8.dp))
            detail.tasks.forEach { task ->
                TaskRow(task)
            }
        }

        if (detail.sessions.isEmpty() && detail.tasks.isEmpty()) {
            Spacer(modifier = Modifier.height(16.dp))
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Rounded.Nightlight,
                    contentDescription = null,
                    modifier = Modifier.size(28.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "No activity",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SummaryItem(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun SessionRow(session: SessionSummary) {
    val timeFormat = remember { SimpleDateFormat("h:mm a", Locale.getDefault()) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = modeIcon(session.mode),
            style = MaterialTheme.typography.bodyLarge,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(text = session.mode, style = MaterialTheme.typography.bodyMedium)
            Text(
                text = timeFormat.format(session.startTime),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Text(
            text = "${session.durationMinutes} min",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun TaskRow(task: TaskSummary) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = if (task.isCompleted) Icons.Rounded.CheckCircle else Icons.Rounded.Circle,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = if (task.isCompleted) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = task.title,
            style = MaterialTheme.typography.bodyMedium,
            color = if (task.isCompleted) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
            textDecoration = if (task.isCompleted) TextDecoration.LineThrough else TextDecoration.None,
            modifier = Modifier.weight(1f),
        )
        if (task.isDue) {
            Text(
                text = "Due",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(MaterialTheme.colorScheme.error.copy(alpha = 0.1f))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
    }
}

private fun modeIcon(mode: String): String = when (mode) {
    "Pomodoro" -> "\uD83C\uDF45"
    "Flow" -> "\uD83C\uDF0A"
    "Blocks" -> "\uD83D\uDCE6"
    "Chrono" -> "\u23F1\uFE0F"
    else -> "\uD83C\uDFAF"
}

private data class CalendarDay(
    val dayNumber: Int,
    val dateMillis: Long,
    val isToday: Boolean,
    val isFuture: Boolean,
)

private fun buildCalendarDays(displayedMonth: Calendar): List<CalendarDay?> {
    val cal = displayedMonth.clone() as Calendar
    cal.set(Calendar.DAY_OF_MONTH, 1)
    cal.set(Calendar.HOUR_OF_DAY, 0)
    cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0)
    cal.set(Calendar.MILLISECOND, 0)

    val firstDayOfWeek = cal.firstDayOfWeek
    val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
    val leadingEmpty = (dayOfWeek - firstDayOfWeek + 7) % 7
    val daysInMonth = cal.getActualMaximum(Calendar.DAY_OF_MONTH)

    val today = Calendar.getInstance()
    today.set(Calendar.HOUR_OF_DAY, 0); today.set(Calendar.MINUTE, 0)
    today.set(Calendar.SECOND, 0); today.set(Calendar.MILLISECOND, 0)
    val todayMillis = today.timeInMillis

    val days = mutableListOf<CalendarDay?>()
    repeat(leadingEmpty) { days.add(null) }

    for (day in 1..daysInMonth) {
        cal.set(Calendar.DAY_OF_MONTH, day)
        val millis = cal.timeInMillis
        days.add(
            CalendarDay(
                dayNumber = day,
                dateMillis = millis,
                isToday = millis == todayMillis,
                isFuture = millis > todayMillis,
            )
        )
    }

    return days
}
