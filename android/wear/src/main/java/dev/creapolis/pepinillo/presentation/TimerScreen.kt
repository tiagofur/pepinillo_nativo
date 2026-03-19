package dev.creapolis.pepinillo.presentation

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.creapolis.pepinillo.R
import kotlinx.coroutines.delay
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTimerState

@Composable
fun TimerScreen(
    state: WearTimerState,
    stats: WearStatsState = WearStatsState(),
    pendingCommandCount: Int = 0,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
    onStartMode: (String) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
    onSkip: () -> Unit = {},
) {
    val haptics = LocalHapticFeedback.current
    val modeColor = WearModeColors.forMode(state.mode)

    when (state.status) {
        "Running", "Paused" -> TimerActiveLayout(
            state = state,
            modeColor = modeColor,
            onPause = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onPause()
            },
            onResume = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onResume()
            },
            onStop = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onStop()
            },
            onSkip = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onSkip()
            },
        )

        "WaitingForNext" -> WaitingForNextLayout(
            state = state,
            modeColor = modeColor,
            onResume = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onResume()
            },
            onStop = {
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onStop()
            },
        )

        "Disconnected" -> DisconnectedLayout(
            pendingCommandCount = pendingCommandCount,
        )

        else -> IdleLayout(
            stats = stats,
            linkedTaskName = state.linkedTaskName,
            onStartMode = { mode ->
                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                onStartMode(mode)
            },
        )
    }
}

// ─────────────────────────── Active Session ───────────────────────────────

@Composable
private fun TimerActiveLayout(
    state: WearTimerState,
    modeColor: Color,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
    onSkip: () -> Unit,
) {
    var showStopConfirm by remember { mutableStateOf(false) }

    if (showStopConfirm) {
        LaunchedEffect(Unit) {
            delay(3_000)
            showStopConfirm = false
        }
    }

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Progress ring
        CircularProgressIndicator(
            progress = state.progress.coerceIn(0f, 1f),
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            indicatorColor = modeColor,
            trackColor = modeColor.copy(alpha = 0.15f),
            strokeWidth = 6.dp,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // Mode + pomodoro number
            val modeLabel = if (state.mode == "Pomodoro" && state.completedSessions >= 0) {
                "${state.mode} #${state.completedSessions + 1}"
            } else {
                state.mode
            }
            Text(
                text = modeLabel,
                style = MaterialTheme.typography.caption2,
                color = modeColor,
                textAlign = TextAlign.Center,
            )

            // Timer display
            Text(
                text = state.displayTime,
                fontSize = 32.sp,
                fontWeight = FontWeight.Light,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )

            // Phase label
            Text(
                text = state.phaseLabel,
                style = MaterialTheme.typography.caption2,
                color = MaterialTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            // Linked task
            state.linkedTaskName?.let { taskName ->
                Text(
                    text = "🔗 $taskName",
                    style = MaterialTheme.typography.caption2,
                    color = modeColor.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            val isBreakPhase = state.phase == "ShortBreak" || state.phase == "LongBreak"

            // Action buttons — round, large touch targets (48dp+)
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Stop (40x40)
                Button(
                    onClick = {
                        if (showStopConfirm) {
                            showStopConfirm = false
                            onStop()
                        } else {
                            showStopConfirm = true
                        }
                    },
                    modifier = Modifier.size(40.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = if (showStopConfirm) Color(0xFFB71C1C) else Color.White.copy(alpha = 0.12f),
                        contentColor = if (showStopConfirm) Color.White else Color.White.copy(alpha = 0.8f),
                    ),
                ) {
                    Text(
                        text = if (showStopConfirm) "✓" else "⏹",
                        fontSize = 16.sp,
                        textAlign = TextAlign.Center,
                    )
                }

                // Pause / Resume (48x48, primary action — biggest)
                Button(
                    onClick = if (state.status == "Running") onPause else onResume,
                    modifier = Modifier.size(48.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = modeColor,
                        contentColor = Color.White,
                    ),
                ) {
                    Text(
                        text = if (state.status == "Running") "⏸" else "▶",
                        fontSize = 20.sp,
                        textAlign = TextAlign.Center,
                    )
                }

                // Skip (40x40) — only during break phases
                if (isBreakPhase) {
                    Button(
                        onClick = onSkip,
                        modifier = Modifier.size(40.dp),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = Color.White.copy(alpha = 0.12f),
                            contentColor = Color.White.copy(alpha = 0.8f),
                        ),
                    ) {
                        Text(
                            text = "⏭",
                            fontSize = 16.sp,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }
        }
    }
}

// ─────────────────────────── WaitingForNext ───────────────────────────────

@Composable
private fun WaitingForNextLayout(
    state: WearTimerState,
    modeColor: Color,
    onResume: () -> Unit,
    onStop: () -> Unit,
) {
    val isBreakNext = state.phase == "ShortBreak" || state.phase == "LongBreak"
    val completionEmoji = if (isBreakNext) "✅" else "☕"
    val completionTitle = if (isBreakNext) stringResource(R.string.focus_complete) else stringResource(R.string.break_finished)
    val actionLabel = if (isBreakNext) stringResource(R.string.start_break) else stringResource(R.string.start_focus)

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Pulsing completed ring
        CircularProgressIndicator(
            progress = 1f,
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            indicatorColor = modeColor.copy(alpha = 0.4f),
            trackColor = modeColor.copy(alpha = 0.1f),
            strokeWidth = 6.dp,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // Celebration emoji
            Text(
                text = completionEmoji,
                fontSize = 28.sp,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(4.dp))

            // Title
            Text(
                text = completionTitle,
                style = MaterialTheme.typography.body2,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )

            // Pomodoro progress dots (for Pomodoro mode)
            if (state.mode == "Pomodoro" && state.completedSessions > 0) {
                Spacer(modifier = Modifier.height(4.dp))
                PomodoroDots(
                    completed = state.completedSessions,
                    total = 4,
                    activeColor = modeColor,
                )
            }

            // Linked task
            state.linkedTaskName?.let { taskName ->
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "🔗 $taskName",
                    style = MaterialTheme.typography.caption2,
                    color = MaterialTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Primary action: Start next phase (large, easy to tap)
            Button(
                onClick = onResume,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    backgroundColor = modeColor,
                    contentColor = Color.White,
                ),
            ) {
                Text(
                    text = actionLabel,
                    style = MaterialTheme.typography.body2,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Secondary: Stop (also tappable)
            CompactChip(
                onClick = onStop,
                label = { Text(stringResource(R.string.stop), maxLines = 1) },
                colors = androidx.wear.compose.material.ChipDefaults.secondaryChipColors(),
            )
        }
    }
}

@Composable
private fun PomodoroDots(
    completed: Int,
    total: Int,
    activeColor: Color,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(total) { index ->
            val isFilled = index < completed
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .then(
                        if (isFilled) {
                            Modifier.padding(0.dp) // filled handled by background
                        } else {
                            Modifier.padding(0.dp)
                        },
                    ),
            ) {
                androidx.compose.foundation.Canvas(modifier = Modifier.fillMaxSize()) {
                    if (isFilled) {
                        drawCircle(color = activeColor)
                    } else {
                        drawCircle(color = activeColor.copy(alpha = 0.25f))
                    }
                }
            }
        }
    }
}

// ─────────────────────────── Disconnected ─────────────────────────────────

@Composable
private fun DisconnectedLayout(
    pendingCommandCount: Int,
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(
            modifier = Modifier
                .fillMaxSize()
                .padding(8.dp),
            indicatorColor = MaterialTheme.colors.onSurfaceVariant.copy(alpha = 0.3f),
            trackColor = MaterialTheme.colors.onSurfaceVariant.copy(alpha = 0.08f),
            strokeWidth = 4.dp,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(horizontal = 24.dp),
        ) {
            Text(text = "📱", fontSize = 28.sp, textAlign = TextAlign.Center)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.connecting_to_phone),
                style = MaterialTheme.typography.body2,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )
            if (pendingCommandCount > 0) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.queued, pendingCommandCount),
                    style = MaterialTheme.typography.caption2,
                    color = MaterialTheme.colors.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ─────────────────────────── Idle ─────────────────────────────────────────

@Composable
private fun IdleLayout(
    stats: WearStatsState = WearStatsState(),
    linkedTaskName: String? = null,
    onStartMode: (String) -> Unit,
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(horizontal = 16.dp),
        ) {
            // Today's stats (compact row)
            if (stats.totalMinutes > 0 || stats.sessions > 0 || stats.streak > 0) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (stats.totalMinutes > 0) {
                        Text(
                            text = "⏱ ${formatMinutes(stats.totalMinutes)}",
                            style = MaterialTheme.typography.caption2,
                            color = MaterialTheme.colors.onSurfaceVariant,
                        )
                    }
                    if (stats.sessions > 0) {
                        Text(
                            text = "✅ ${stats.sessions}",
                            style = MaterialTheme.typography.caption2,
                            color = MaterialTheme.colors.onSurfaceVariant,
                        )
                    }
                    if (stats.streak > 0) {
                        Text(
                            text = "🔥 ${stats.streak}d",
                            style = MaterialTheme.typography.caption2,
                            color = Color(0xFFFF9800),
                        )
                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
            }

            // Linked task
            linkedTaskName?.let { name ->
                Text(
                    text = "🔗 $name",
                    style = MaterialTheme.typography.caption2,
                    color = MaterialTheme.colors.primary,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
                Spacer(modifier = Modifier.height(4.dp))
            }

            Text(
                text = stringResource(R.string.start),
                style = MaterialTheme.typography.title3,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(6.dp))

            // Mode buttons in 2x2 grid
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ModeButton(
                    label = "Pomodoro",
                    color = WearModeColors.Pomodoro,
                    onClick = { onStartMode("Pomodoro") },
                    modifier = Modifier.weight(1f),
                )
                ModeButton(
                    label = "Flow",
                    color = WearModeColors.Flow,
                    onClick = { onStartMode("Flow") },
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ModeButton(
                    label = "Blocks",
                    color = WearModeColors.Blocks,
                    onClick = { onStartMode("Blocks") },
                    modifier = Modifier.weight(1f),
                )
                ModeButton(
                    label = "Chrono",
                    color = WearModeColors.Chrono,
                    onClick = { onStartMode("Chrono") },
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

private fun formatMinutes(totalMinutes: Int): String {
    val hours = totalMinutes / 60
    val minutes = totalMinutes % 60
    return if (hours > 0) "${hours}h${minutes}m" else "${minutes}m"
}

// ─────────────────────────── Shared ───────────────────────────────────────

@Composable
private fun ModeButton(
    label: String,
    color: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(36.dp),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = color.copy(alpha = 0.2f),
            contentColor = color,
        ),
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.caption2,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
