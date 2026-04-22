package dev.creapolis.pepinillo.feature.focus

import android.app.Activity
import android.view.WindowManager
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.feature.focus.components.CircularTimerRing
import dev.creapolis.pepinillo.feature.focus.components.ModeChip
import dev.creapolis.pepinillo.feature.focus.components.SessionJournalSheet
import dev.creapolis.pepinillo.feature.focus.components.TaskPickerDialog
import dev.creapolis.pepinillo.feature.soundscape.SoundscapePickerSheet
import dev.creapolis.pepinillo.ui.components.SuccessToast
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.colorScheme

@Composable
fun FocusScreen(
    modifier: Modifier = Modifier,
    viewModel: FocusViewModel = hiltViewModel(),
    onMoreClick: () -> Unit = {},
    onNavigateToPaywall: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()
    val activeTasks by viewModel.activeTasks.collectAsState()
    val modeColors = uiState.selectedMode.colorScheme(uiState.currentPhase)
    val haptic = LocalHapticFeedback.current

    // Keep screen on during focus sessions
    val keepScreenActive = uiState.keepScreenOn && (uiState.isRunning || uiState.isPaused)
    val activity = LocalContext.current as? Activity
    DisposableEffect(keepScreenActive) {
        if (keepScreenActive) {
            activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    // Animated colors for smooth mode transitions
    val animatedAccentColor by animateColorAsState(
        targetValue = modeColors.accentColor,
        animationSpec = tween(400),
        label = "accentColor",
    )
    val animatedContentColor by animateColorAsState(
        targetValue = modeColors.contentColor,
        animationSpec = tween(400),
        label = "contentColor",
    )
    val animatedOnAccentColor by animateColorAsState(
        targetValue = modeColors.onAccentColor,
        animationSpec = tween(400),
        label = "onAccentColor",
    )
    val animatedProgress by animateFloatAsState(
        targetValue = uiState.progress,
        animationSpec = tween(500),
        label = "progress",
    )

    val successMsg by viewModel.successMessage.collectAsState()

    Box(modifier = modifier.fillMaxSize()) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // ── 1. GREETING + MORE ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Column {
                Text(
                    text = uiState.greeting,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = uiState.currentDate,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            // More shortcut
            Icon(
                imageVector = Icons.Rounded.MoreHoriz,
                contentDescription = "More",
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .clickable(onClick = onMoreClick),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        // ── 2. TIMER (no card, floats on background) ──
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(260.dp)
                    .semantics {
                        contentDescription = "${uiState.phaseLabel}: ${uiState.displayTime}, ${uiState.selectedMode.label} mode"
                    },
            ) {
                CircularTimerRing(
                    progress = animatedProgress,
                    ringColor = animatedAccentColor,
                    trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
                    strokeWidth = 10.dp,
                    modifier = Modifier.size(260.dp),
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = uiState.displayTime,
                        style = MaterialTheme.typography.displayLarge.copy(
                            fontSize = 56.sp,
                            letterSpacing = 2.sp,
                        ),
                        fontWeight = FontWeight.Normal,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = uiState.phaseLabel,
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(36.dp))

        // ── 3. MODE SELECTOR (circular chips) ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            FocusMode.entries.forEach { mode ->
                ModeChip(
                    mode = mode,
                    isSelected = mode == uiState.selectedMode,
                    onClick = { viewModel.selectMode(mode) },
                    isLocked = !mode.isFreeTier && !uiState.isPro,
                )
            }
        }

        // Navigate to paywall when requested
        if (uiState.showPaywall) {
            viewModel.dismissPaywall()
            onNavigateToPaywall()
        }

        Spacer(modifier = Modifier.height(16.dp))

        // ── SOUNDSCAPE BUTTON ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.outlineVariant,
                    shape = RoundedCornerShape(24.dp),
                )
                .clickable { viewModel.onSoundscapePickerClick() }
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = uiState.selectedSoundscape?.emoji ?: "\uD83D\uDD07",
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = if (uiState.selectedSoundscape != null) {
                    stringResource(uiState.selectedSoundscape!!.displayNameRes)
                } else {
                    stringResource(R.string.soundscape_choose)
                },
                style = MaterialTheme.typography.bodyLarge,
                color = if (uiState.selectedSoundscape != null) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.Rounded.MusicNote,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(20.dp),
            )
        }

        // ── VOLUME SLIDER (only when soundscape is selected) ──
        AnimatedVisibility(
            visible = uiState.selectedSoundscape != null,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "\uD83D\uDD08",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Slider(
                    value = uiState.soundscapeVolume,
                    onValueChange = { viewModel.setSoundscapeVolume(it) },
                    modifier = Modifier
                        .weight(1f)
                        .padding(horizontal = 8.dp),
                    colors = SliderDefaults.colors(
                        thumbColor = animatedAccentColor,
                        activeTrackColor = animatedAccentColor,
                    ),
                )
                Text(
                    text = "\uD83D\uDD0A",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        // ── BREAK SUGGESTION (Flowtime) ──
        AnimatedVisibility(
            visible = uiState.breakSuggested,
            enter = fadeIn(),
            exit = fadeOut(),
        ) {
            Column {
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = "You've been focused for a while — consider a break!",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f))
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                )
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── 4. LINKED TASK (outlined style) ──
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.outlineVariant,
                    shape = RoundedCornerShape(24.dp),
                )
                .clickable { viewModel.onTaskLinkClick() }
                .padding(horizontal = 20.dp, vertical = 16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = Icons.Rounded.Link,
                contentDescription = "Link task",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.size(20.dp),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = uiState.linkedTaskName ?: stringResource(R.string.tap_to_link_task),
                style = MaterialTheme.typography.bodyLarge,
                color = if (uiState.linkedTaskName != null) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant
                },
                modifier = Modifier.weight(1f),
            )
            Icon(
                imageVector = Icons.Rounded.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(20.dp),
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        // ── 5. QUICK STATS ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Sessions today
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(20.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                    .padding(16.dp)
                    .semantics { contentDescription = "${uiState.sessionsToday} sessions today" },
            ) {
                Column {
                    Text(
                        text = "${uiState.sessionsToday}",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = stringResource(R.string.sessions_today),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            // Streak
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(20.dp))
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f))
                    .padding(16.dp)
                    .semantics { contentDescription = "${uiState.currentStreak} day streak" },
            ) {
                Column {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "${uiState.currentStreak}",
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Icon(
                            imageVector = Icons.Rounded.LocalFireDepartment,
                            contentDescription = "Streak",
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = stringResource(R.string.day_streak),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // ── 6. ACTION BUTTONS ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = if (uiState.isRunning || uiState.isPaused || uiState.isWaitingForNext) {
                Arrangement.spacedBy(20.dp, Alignment.CenterHorizontally)
            } else {
                Arrangement.spacedBy(12.dp)
            },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Stop button (only visible when running or paused)
            if (uiState.isRunning || uiState.isPaused || uiState.isWaitingForNext) {
                Button(
                    onClick = {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        viewModel.onStopClick()
                    },
                    modifier = Modifier.size(56.dp),
                    shape = CircleShape,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    ),
                    contentPadding = PaddingValues(0.dp),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Stop,
                        contentDescription = stringResource(R.string.btn_stop),
                        modifier = Modifier.size(28.dp),
                    )
                }
            }

            // Start/Pause button
            Button(
                onClick = {
                    if (uiState.isRunning) {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) // standard impact
                    } else {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    }
                    viewModel.onStartStopClick()
                },
                modifier = if (uiState.isRunning || uiState.isPaused) {
                    Modifier.size(56.dp)
                } else {
                    Modifier
                        .weight(1f)
                        .height(56.dp)
                },
                shape = if (uiState.isRunning || uiState.isPaused) CircleShape else RoundedCornerShape(28.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = animatedAccentColor,
                    contentColor = animatedOnAccentColor,
                ),
                contentPadding = if (uiState.isRunning || uiState.isPaused) PaddingValues(0.dp) else ButtonDefaults.ContentPadding,
            ) {
                AnimatedContent(
                    targetState = uiState.isRunning,
                    label = "startStop",
                ) { isRunning ->
                    if (isRunning || uiState.isPaused) {
                        Icon(
                            imageVector = if (isRunning) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                            contentDescription = if (isRunning) stringResource(R.string.btn_pause) else stringResource(R.string.btn_resume),
                            modifier = Modifier.size(28.dp),
                        )
                    } else {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Rounded.PlayArrow,
                                contentDescription = "Start timer",
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = stringResource(R.string.btn_start_focus),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }
            }

            // Skip button (only during Pomodoro break phases)
            if (uiState.canSkip) {
                Button(
                    onClick = {
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        viewModel.onSkipClick()
                    },
                    modifier = Modifier.size(56.dp),
                    shape = CircleShape,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    ),
                    contentPadding = PaddingValues(0.dp),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.SkipNext,
                        contentDescription = "Skip to next phase",
                        modifier = Modifier.size(28.dp),
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))
    }

    // Success toast overlay
    SuccessToast(
        message = successMsg,
        modifier = Modifier
            .align(Alignment.TopCenter)
            .padding(top = 24.dp),
        onDismiss = { viewModel.dismissSuccessMessage() },
    )
    } // Box

    if (uiState.showTaskPicker) {
        TaskPickerDialog(
            tasks = activeTasks,
            currentLinkedTaskName = uiState.linkedTaskName,
            onTaskSelected = { taskId -> viewModel.linkTask(taskId) },
            onDismiss = { viewModel.dismissTaskPicker() },
        )
    }

    if (uiState.showSoundscapePicker) {
        SoundscapePickerSheet(
            currentSoundscape = uiState.selectedSoundscape,
            onSoundscapeSelected = { viewModel.selectSoundscape(it) },
            onDismiss = { viewModel.dismissSoundscapePicker() },
            onNavigateToPaywall = onNavigateToPaywall,
        )
    }

    if (uiState.showJournalSheet) {
        SessionJournalSheet(
            onSave = { note, rating -> viewModel.saveJournalEntry(note, rating) },
            onSkip = { viewModel.skipJournal() },
            onDismiss = { viewModel.skipJournal() },
        )
    }

    if (uiState.showStopConfirmation) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissStopConfirmation() },
            title = { Text(stringResource(R.string.stop_confirm_title)) },
            text = { Text(stringResource(R.string.stop_confirm_body)) },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.confirmStop() },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error,
                    ),
                ) {
                    Text(stringResource(R.string.btn_stop))
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.dismissStopConfirmation() }) {
                    Text(stringResource(R.string.btn_cancel))
                }
            },
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun FocusScreenPreview() {
    PepinilloTheme {
        FocusScreen()
    }
}
