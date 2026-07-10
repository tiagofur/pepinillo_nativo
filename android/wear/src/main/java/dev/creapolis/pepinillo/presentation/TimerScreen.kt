package dev.creapolis.pepinillo.presentation

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Lock
import androidx.wear.compose.material.ChipDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
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
import androidx.wear.compose.material.Icon
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
    isPro: Boolean = false,
    onStartMode: (String) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
    onSkip: () -> Unit = {},
) {
    val haptics = LocalHapticFeedback.current
    val modeColor = WearModeColors.forModeAndPhase(state.mode, state.phase)

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
            isPro = isPro,
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
    var stopCountdown by remember { mutableStateOf(3) }

    if (showStopConfirm) {
        LaunchedEffect(Unit) {
            stopCountdown = 3
            repeat(3) {
                delay(1_000)
                stopCountdown = 2 - it
            }
            showStopConfirm = false
        }
    }

    var localProgress by remember { mutableStateOf(state.progress) }
    var localDisplayTime by remember { mutableStateOf(state.displayTime) }

    // Keys: only restart the countdown loop when the phase/status fundamentally changes.
    // Avoid displayTime/progress as keys — they update every 30s from the phone push
    // and would restart the local tick loop unnecessarily.
    LaunchedEffect(state.status, state.phaseEndEpochMs, state.totalDurationMs) {
        if (state.status == "Running" && state.phaseEndEpochMs > 0 && state.totalDurationMs > 0) {
            while (true) {
                val now = System.currentTimeMillis()
                val rem = (state.phaseEndEpochMs - now).coerceAtLeast(0L)
                localProgress = (1f - (rem.toFloat() / state.totalDurationMs)).coerceIn(0f, 1f)
                
                val totalSeconds = (rem + 999) / 1000
                val minutes = totalSeconds / 60
                val seconds = totalSeconds % 60
                localDisplayTime = String.format(java.util.Locale.US, "%02d:%02d", minutes, seconds)
                
                delay(100)
            }
        } else {
            localProgress = state.progress
            localDisplayTime = state.displayTime
        }
    }

    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Display floor: ensure the ring reads active even at progress ~0 (count-up
        // modes such as Flow and Chrono start empty). Mirrors the phone-side fix.
        val displayProgress = if (localProgress < 0.02f) 0.02f else localProgress
        CircularProgressIndicator(
            progress = displayProgress.coerceIn(0f, 1f),
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

            // Timer display — TalkBack reads a rich description (phase + time + progress)
            // instead of the raw "05:23" string which it parses awkwardly as separate digits.
            val timeAnnouncement = buildString {
                append(state.phaseLabel)
                append(", ")
                append(localDisplayTime)
                state.linkedTaskName?.let { append(", ").append(it) }
            }
            Text(
                text = localDisplayTime,
                fontSize = 32.sp,
                fontWeight = FontWeight.Light,
                color = MaterialTheme.colors.onSurface,
                textAlign = TextAlign.Center,
                modifier = Modifier.clearAndSetSemantics {
                    contentDescription = timeAnnouncement
                    liveRegion = androidx.compose.ui.semantics.LiveRegionMode.Polite
                },
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
                // Stop (44x44) — Material You tonal style
                Button(
                    onClick = {
                        if (showStopConfirm) {
                            showStopConfirm = false
                            onStop()
                        } else {
                            showStopConfirm = true
                        }
                    },
                    modifier = Modifier.size(44.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = if (showStopConfirm) Color(0xFFB71C1C) else MaterialTheme.colors.surface,
                        contentColor = if (showStopConfirm) Color.White else MaterialTheme.colors.onSurface,
                    ),
                ) {
                    if (showStopConfirm) {
                        Text(
                            text = "$stopCountdown",
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Filled.Stop,
                            contentDescription = "Stop",
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }

                // Pause / Resume (52x52, primary action — biggest)
                Button(
                    onClick = if (state.status == "Running") onPause else onResume,
                    modifier = Modifier.size(52.dp),
                    colors = ButtonDefaults.buttonColors(
                        backgroundColor = modeColor,
                        contentColor = Color.White,
                    ),
                ) {
                    Icon(
                        imageVector = if (state.status == "Running") Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = if (state.status == "Running") "Pause" else "Resume",
                        modifier = Modifier.size(24.dp),
                    )
                }

                // Skip (44x44) — only during break phases, tonal style
                if (isBreakPhase) {
                    Button(
                        onClick = onSkip,
                        modifier = Modifier.size(44.dp),
                        colors = ButtonDefaults.buttonColors(
                            backgroundColor = MaterialTheme.colors.surface,
                            contentColor = MaterialTheme.colors.onSurface,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.Filled.SkipNext,
                            contentDescription = "Skip",
                            modifier = Modifier.size(20.dp),
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
    isPro: Boolean = false,
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
            // ... (stats and linked task code remains the same)
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

            // Voice input — the most native watch affordance for "start focus".
            VoiceStartChip(onStartMode = onStartMode)

            Spacer(modifier = Modifier.height(6.dp))

            // Mode buttons in 2x2 grid
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ModeButton(
                    label = stringResource(R.string.mode_pomodoro),
                    color = WearModeColors.Pomodoro,
                    onClick = { onStartMode("Pomodoro") },
                    modifier = Modifier.weight(1f),
                )
                ModeButton(
                    label = stringResource(R.string.mode_flow),
                    color = WearModeColors.Flow,
                    onClick = { onStartMode("Flow") },
                    isLocked = !isPro,
                    modifier = Modifier.weight(1f),
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                ModeButton(
                    label = stringResource(R.string.mode_blocks),
                    color = WearModeColors.Blocks,
                    onClick = { onStartMode("Blocks") },
                    isLocked = !isPro,
                    modifier = Modifier.weight(1f),
                )
                ModeButton(
                    label = stringResource(R.string.mode_chrono),
                    color = WearModeColors.Chrono,
                    onClick = { onStartMode("Chrono") },
                    isLocked = false, // Chrono is free per PRD v3.1
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

/**
 * Voice input chip: launches the system speech recognizer and maps spoken mode names
 * to the corresponding focus mode. "Start focus" / "start pomodoro" → Pomodoro, etc.
 * The most native watch affordance for hands-free timer start.
 */
@Composable
private fun VoiceStartChip(onStartMode: (String) -> Unit) {
    val voiceLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult(),
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val spoken = result.data
                ?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
                ?.lowercase()
            val mode = when {
                spoken == null -> null
                spoken.contains("flow") -> "Flow"
                spoken.contains("block") -> "Blocks"
                spoken.contains("chrono") || spoken.contains("stopwatch") -> "Chrono"
                else -> "Pomodoro"
            }
            if (mode != null) onStartMode(mode)
        }
    }

    Button(
        onClick = {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_WEB_SEARCH)
                putExtra(RecognizerIntent.EXTRA_PROMPT, "Say a focus mode")
            }
            voiceLauncher.launch(intent)
        },
        modifier = Modifier
            .fillMaxWidth()
            .height(40.dp),
        shape = RoundedCornerShape(20.dp),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = MaterialTheme.colors.surface,
            contentColor = MaterialTheme.colors.primary,
        ),
    ) {
        Icon(
            imageVector = Icons.Default.Mic,
            contentDescription = "Voice start",
            modifier = Modifier.size(16.dp),
        )
        Spacer(modifier = Modifier.size(4.dp))
        Text(
            text = "Voice start",
            style = MaterialTheme.typography.caption2,
            color = MaterialTheme.colors.primary,
        )
    }
}

@Composable
private fun ModeButton(
    label: String,
    color: Color,
    onClick: () -> Unit,
    isLocked: Boolean = false,
    modifier: Modifier = Modifier,
) {
    Button(
        onClick = { if (!isLocked) onClick() },
        modifier = modifier.height(40.dp),
        shape = RoundedCornerShape(20.dp),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = if (isLocked) MaterialTheme.colors.surface.copy(alpha = 0.5f) else color.copy(alpha = 0.15f),
            contentColor = if (isLocked) MaterialTheme.colors.onSurface.copy(alpha = 0.4f) else color,
        ),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (isLocked) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Locked",
                    modifier = Modifier.size(12.dp),
                )
                Spacer(modifier = Modifier.width(4.dp))
            }
            Text(
                text = label,
                style = MaterialTheme.typography.caption2,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
