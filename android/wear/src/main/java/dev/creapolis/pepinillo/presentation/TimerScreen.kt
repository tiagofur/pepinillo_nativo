package dev.creapolis.pepinillo.presentation

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.SkipNext
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.widget.Toast
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableFloatStateOf
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.ChildButton
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ProgressIndicatorDefaults
import androidx.wear.compose.material3.Text
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.data.WearStatsState
import dev.creapolis.pepinillo.data.WearTimerDisplay
import dev.creapolis.pepinillo.data.WearTimerState
import kotlinx.coroutines.delay

@Composable
fun TimerScreen(
    state: WearTimerState,
    stats: WearStatsState = WearStatsState(),
    pendingCommandCount: Int = 0,
    syncStatusLabel: String? = null,
    isSyncStale: Boolean = false,
    isPro: Boolean = false,
    isAmbient: Boolean = false,
    onStartMode: (String) -> Unit,
    onPause: () -> Unit,
    onResume: () -> Unit,
    onStop: () -> Unit,
    onSkip: () -> Unit = {},
) {
    val haptics = LocalHapticFeedback.current
    val modeColor = WearModeColors.forModeAndPhase(state.mode, state.phase)

    when {
        // Ambient: render minimal — dimmed time text on black, no colors/icons/chrome.
        // Minimises lit pixels and burn-in risk during always-on.
        isAmbient && (state.status == "Running" || state.status == "Paused") -> {
            var ambientDisplayTime by remember { mutableStateOf(state.displayTime) }
            LaunchedEffect(
                state.status,
                state.phaseEndEpochMs,
                state.phaseStartEpochMs,
                state.totalDurationMs,
                state.mode,
            ) {
                if (state.status == "Running") {
                    while (true) {
                        ambientDisplayTime = WearTimerDisplay.tick(state).displayTime
                        delay(100)
                    }
                } else {
                    ambientDisplayTime = state.displayTime
                }
            }
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = ambientDisplayTime,
                    fontSize = 36.sp,
                    fontWeight = FontWeight.Light,
                    color = Color.White.copy(alpha = 0.4f),
                    textAlign = TextAlign.Center,
                )
            }
        }

        state.status == "Running" || state.status == "Paused" -> TimerActiveLayout(
            state = state,
            modeColor = modeColor,
            onPause = {
                WearHaptics.onControlTap(haptics)
                onPause()
            },
            onResume = {
                WearHaptics.onControlTap(haptics)
                onResume()
            },
            onStop = {
                WearHaptics.onControlTap(haptics)
                onStop()
            },
            onSkip = {
                WearHaptics.onControlTap(haptics)
                onSkip()
            },
        )

        state.status == "WaitingForNext" -> WaitingForNextLayout(
            state = state,
            modeColor = modeColor,
            onResume = {
                WearHaptics.onControlTap(haptics)
                onResume()
            },
            onStop = {
                WearHaptics.onControlTap(haptics)
                onStop()
            },
        )

        state.status == "Disconnected" -> DisconnectedLayout(
            pendingCommandCount = pendingCommandCount,
        )

        else -> IdleLayout(
            stats = stats,
            linkedTaskName = state.linkedTaskName,
            isPro = isPro,
            onStartMode = { mode ->
                WearHaptics.onModeSelect(haptics)
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
    var stopCountdown by remember { mutableIntStateOf(3) }

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

    var localProgress by remember { mutableFloatStateOf(state.progress) }
    var localDisplayTime by remember { mutableStateOf(state.displayTime) }

    // Keys: only restart the countdown loop when the phase/status fundamentally changes.
    LaunchedEffect(
        state.status,
        state.phaseEndEpochMs,
        state.phaseStartEpochMs,
        state.totalDurationMs,
        state.mode,
    ) {
        val canTick = state.status == "Running" && (
            (state.phaseEndEpochMs > 0 && state.totalDurationMs > 0) ||
                (WearTimerDisplay.isCountUpMode(state.mode) && state.phaseStartEpochMs > 0)
            )
        if (canTick) {
            while (true) {
                val ticked = WearTimerDisplay.tick(state)
                localProgress = ticked.progress
                localDisplayTime = ticked.displayTime
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
        // Sprint 6 (#492): circular→squircle morph during the last 20% of countdown sessions.
        // Count-up modes (Flow, Chrono), inactive sessions, and Reduce Motion stay circular,
        // matching the phone. This layout only renders for Running/Paused (see TimerScreen),
        // so the countdown is always active here; localProgress is the REMAINING fraction
        // (WearTimerDisplay returns REMAINING for countdown modes — #502 unified polarity).
        val hasCountdown = !WearTimerDisplay.isCountUpMode(state.mode)
        val rawMorphTarget = WearTimerMorph.calculateMorphTarget(
            progress = localProgress,
            hasCountdown = hasCountdown,
            sessionActive = state.status == "Running" || state.status == "Paused",
            reduceMotion = isReduceMotionEnabled(),
        )
        val morphProgress by animateFloatAsState(
            targetValue = rawMorphTarget,
            animationSpec = spring(stiffness = Spring.StiffnessLow),
            label = "wearMorphProgress",
        )
        WearTimerRing(
            progress = localProgress,
            color = modeColor,
            trackColor = modeColor.copy(alpha = 0.15f),
            strokeWidth = 6.dp,
            modifier = Modifier.padding(8.dp),
            morphProgress = morphProgress,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // Mode + pomodoro number (#508: localize)
            val modeLabel = if (state.mode == "Pomodoro" && state.completedSessions >= 0) {
                stringResource(R.string.phase_focus_numbered, state.completedSessions + 1)
            } else {
                stringResource(when(state.mode) {
                    "Pomodoro" -> R.string.mode_pomodoro
                    "Flow" -> R.string.mode_flow
                    "Blocks" -> R.string.mode_blocks
                    "Chrono" -> R.string.mode_chrono
                    else -> R.string.mode_pomodoro
                })
            }
            Text(
                text = modeLabel,
                style = MaterialTheme.typography.labelSmall,
                color = modeColor,
                textAlign = TextAlign.Center,
            )

            // Timer display — TalkBack reads a rich description.
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
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                modifier = Modifier.clearAndSetSemantics {
                    contentDescription = timeAnnouncement
                    liveRegion = androidx.compose.ui.semantics.LiveRegionMode.Polite
                },
            )

            // Phase label (#508: Phase label is already localized from ViewModel/Push)
            Text(
                text = state.phaseLabel,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            // Linked task
            state.linkedTaskName?.let { taskName ->
                Text(
                    text = "🔗 $taskName",
                    style = MaterialTheme.typography.labelSmall,
                    color = modeColor.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            val isBreakPhase = state.phase == "ShortBreak" || state.phase == "LongBreak"

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // Stop (44×44)
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
                        containerColor = if (showStopConfirm) Color(0xFFB71C1C) else MaterialTheme.colorScheme.surfaceContainer,
                        contentColor = if (showStopConfirm) Color.White else MaterialTheme.colorScheme.onSurface,
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
                            contentDescription = stringResource(R.string.cd_stop),
                            modifier = Modifier.size(20.dp),
                        )
                    }
                }

                // Pause / Resume (52×52, primary action) (#508: localize CD)
                Button(
                    onClick = if (state.status == "Running") onPause else onResume,
                    modifier = Modifier.size(52.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = modeColor,
                        contentColor = Color.White,
                    ),
                ) {
                    Icon(
                        imageVector = if (state.status == "Running") Icons.Filled.Pause else Icons.Filled.PlayArrow,
                        contentDescription = if (state.status == "Running") stringResource(R.string.cd_pause) else stringResource(R.string.cd_resume),
                        modifier = Modifier.size(24.dp),
                    )
                }

                // Skip (44×44) — only during break phases (#508: localize CD)
                if (isBreakPhase) {
                    Button(
                        onClick = onSkip,
                        modifier = Modifier.size(44.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.surfaceContainer,
                            contentColor = MaterialTheme.colorScheme.onSurface,
                        ),
                    ) {
                        Icon(
                            imageVector = Icons.Filled.SkipNext,
                            contentDescription = stringResource(R.string.cd_skip_phase),
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
        // Sprint 6 (#492, #509): Use WearTimerRing for shape consistency (morph=0).
        WearTimerRing(
            progress = 1f,
            color = modeColor.copy(alpha = 0.4f),
            trackColor = modeColor.copy(alpha = 0.1f),
            strokeWidth = 6.dp,
            modifier = Modifier.padding(8.dp),
            morphProgress = 0f,
        )

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = completionEmoji,
                fontSize = 28.sp,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = completionTitle,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )

            if (state.mode == "Pomodoro" && state.completedSessions > 0) {
                Spacer(modifier = Modifier.height(4.dp))
                PomodoroDots(
                    completed = state.completedSessions,
                    total = state.sessionsBeforeLongBreak,
                    activeColor = modeColor,
                )
            }

            state.linkedTaskName?.let { taskName ->
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "🔗 $taskName",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 24.dp),
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Primary action: Start next phase
            Button(
                onClick = onResume,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = modeColor,
                    contentColor = Color.White,
                ),
            ) {
                Text(
                    text = actionLabel,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Secondary: Stop
            ChildButton(
                onClick = onStop,
                colors = ButtonDefaults.childButtonColors(),
            ) {
                Text(
                    text = stringResource(R.string.stop),
                    maxLines = 1,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
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
                    .clip(CircleShape),
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
            colors = ProgressIndicatorDefaults.colors(
                indicatorColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f),
                trackColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.08f),
            ),
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
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )
            if (pendingCommandCount > 0) {
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.queued, pendingCommandCount),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
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
            // Today's stats (compact row)
            if (stats.totalMinutes > 0 || stats.sessions > 0 || stats.streak > 0) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (stats.totalMinutes > 0) {
                        Text(
                            text = "⏱ ${formatMinutes(stats.totalMinutes)}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (stats.sessions > 0) {
                        Text(
                            text = "✅ ${stats.sessions}",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    if (stats.streak > 0) {
                        Text(
                            text = "🔥 ${stats.streak}d",
                            style = MaterialTheme.typography.labelSmall,
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
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.primary,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(horizontal = 8.dp),
                )
                Spacer(modifier = Modifier.height(4.dp))
            }

            Text(
                text = stringResource(R.string.start),
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
            )

            Spacer(modifier = Modifier.height(6.dp))

            VoiceStartChip(isPro = isPro, onStartMode = onStartMode)

            Spacer(modifier = Modifier.height(6.dp))

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
                    isLocked = false,
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
private fun VoiceStartChip(isPro: Boolean, onStartMode: (String) -> Unit) {
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
                spoken.contains("flow") -> if (isPro) "Flow" else null
                spoken.contains("block") -> if (isPro) "Blocks" else null
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
        shape = WearShapeTokens.card,
        colors = ButtonDefaults.buttonColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
            contentColor = MaterialTheme.colorScheme.primary,
        ),
    ) {
        Icon(
            imageVector = Icons.Default.Mic,
            contentDescription = stringResource(R.string.cd_voice_start),
            modifier = Modifier.size(16.dp),
        )
        Spacer(modifier = Modifier.size(4.dp))
        Text(
            text = stringResource(R.string.btn_voice_start),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.primary,
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
    val context = LocalContext.current
    Button(
        onClick = {
            if (isLocked) {
                Toast.makeText(context, R.string.msg_pro_required, Toast.LENGTH_SHORT).show()
            } else {
                onClick()
            }
        },
        modifier = modifier.height(40.dp),
        shape = WearShapeTokens.card,
        colors = ButtonDefaults.buttonColors(
            containerColor = if (isLocked) MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.5f) else color.copy(alpha = 0.15f),
            contentColor = if (isLocked) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f) else color,
        ),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (isLocked) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = stringResource(R.string.state_locked),
                    modifier = Modifier.size(12.dp),
                )
                Spacer(modifier = Modifier.width(4.dp))
            }
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
