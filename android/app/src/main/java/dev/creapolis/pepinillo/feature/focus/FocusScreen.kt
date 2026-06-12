package dev.creapolis.pepinillo.feature.focus

import android.app.Activity
import android.view.WindowManager
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.material.icons.rounded.Link
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.feature.focus.components.CircularTimerRing
import dev.creapolis.pepinillo.feature.focus.components.ModeChip
import dev.creapolis.pepinillo.feature.focus.components.SessionJournalSheet
import dev.creapolis.pepinillo.feature.focus.components.TaskPickerDialog
import dev.creapolis.pepinillo.feature.soundscape.SoundscapePickerSheet
import dev.creapolis.pepinillo.ui.components.SuccessToast
import dev.creapolis.pepinillo.ui.components.GlassBox
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.colorScheme

@Composable
fun FocusScreen(
    modifier: Modifier = Modifier,
    viewModel: FocusViewModel = hiltViewModel(),
    isPipMode: Boolean = false,
    onMoreClick: () -> Unit = {},
    onNavigateToPaywall: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()
    val activeTasks by viewModel.activeTasks.collectAsState()
    val modeColors = uiState.selectedMode.colorScheme(uiState.currentPhase)
    val haptic = LocalHapticFeedback.current

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
    val sessionActive = uiState.isRunning || uiState.isPaused || uiState.isWaitingForNext
    val timerSize by animateFloatAsState(
        targetValue = if (sessionActive) 292f else 268f,
        animationSpec = tween(500),
        label = "timerSize",
    )
    val buttonWidth by animateDpAsState(
        targetValue = if (sessionActive) 72.dp else 280.dp,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 300f),
        label = "buttonWidth",
    )
    val buttonHeight by animateDpAsState(
        targetValue = if (sessionActive) 72.dp else 60.dp,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 300f),
        label = "buttonHeight",
    )
    val buttonCornerRadius by animateDpAsState(
        targetValue = if (sessionActive) 36.dp else 30.dp,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 300f),
        label = "buttonCornerRadius",
    )
    val successMsg by viewModel.successMessage.collectAsState()

    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = if (isPipMode) 16.dp else 24.dp)
                .padding(top = if (isPipMode) 8.dp else 18.dp, bottom = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            AnimatedVisibility(
                visible = !isPipMode && !sessionActive,
                enter = fadeIn(tween(240)) + slideInVertically { -it / 3 },
                exit = fadeOut(tween(180)) + slideOutVertically { -it / 3 },
            ) {
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
            }

            if (!isPipMode && !sessionActive) {
                Spacer(modifier = Modifier.height(22.dp))
            }

            if (uiState.showPaywall) {
                viewModel.dismissPaywall()
                onNavigateToPaywall()
            }

            Spacer(modifier = Modifier.weight(if (sessionActive) 0.55f else 0.28f))

            val phaseLabel = if (uiState.selectedMode == FocusMode.Pomodoro &&
                uiState.currentPhase == FocusPhase.Work &&
                sessionActive
            ) {
                stringResource(R.string.phase_focus_numbered, uiState.completedSessions + 1)
            } else {
                stringResource(uiState.phaseLabelRes)
            }
            val modeLabel = stringResource(uiState.selectedMode.labelRes)

            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(timerSize.dp)
                    .semantics {
                        contentDescription = "$phaseLabel: ${uiState.displayTime}, $modeLabel mode"
                    },
            ) {
                CircularTimerRing(
                    progress = animatedProgress,
                    ringColor = animatedAccentColor,
                    trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
                    strokeWidth = if (sessionActive) 12.dp else 10.dp,
                    modifier = Modifier.size(timerSize.dp),
                    isRunning = uiState.isRunning,
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = uiState.selectedMode.icon,
                        contentDescription = null,
                        tint = animatedContentColor,
                        modifier = Modifier.size(34.dp),
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = uiState.displayTime,
                        style = MaterialTheme.typography.displayLarge.copy(
                            fontSize = if (sessionActive) 62.sp else 56.sp,
                            letterSpacing = 1.5.sp,
                        ),
                        fontWeight = FontWeight.Normal,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    AnimatedVisibility(visible = uiState.selectedMode == FocusMode.Pomodoro && sessionActive) {
                        Text(
                            text = "${uiState.completedSessions + 1}",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            Text(
                text = phaseLabel.uppercase(),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                letterSpacing = 2.sp,
                color = animatedContentColor.copy(alpha = 0.72f),
                modifier = Modifier.padding(top = 14.dp),
            )

            CompactFocusChip(
                text = uiState.linkedTaskName ?: stringResource(R.string.tap_to_link_task),
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Rounded.Link,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                },
                onClick = { viewModel.onTaskLinkClick() },
                modifier = Modifier.padding(top = 8.dp),
            )

            AnimatedVisibility(
                visible = uiState.breakSuggested,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                Text(
                    text = stringResource(R.string.break_suggestion_text),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .padding(top = 10.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f))
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                )
            }

            Spacer(modifier = Modifier.weight(if (sessionActive) 0.8f else 1f))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = if (sessionActive) {
                    Arrangement.spacedBy(20.dp, Alignment.CenterHorizontally)
                } else {
                    Arrangement.Center
                },
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (sessionActive) {
                    CircleControlButton(
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                            viewModel.onStopClick()
                        },
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Stop,
                            contentDescription = stringResource(R.string.btn_stop),
                            modifier = Modifier.size(28.dp),
                        )
                    }
                }

                Button(
                    onClick = {
                        if (uiState.isRunning) {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                        } else {
                            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        }
                        viewModel.onStartStopClick()
                    },
                    modifier = Modifier.size(width = buttonWidth, height = buttonHeight),
                    shape = RoundedCornerShape(buttonCornerRadius),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = animatedAccentColor,
                        contentColor = animatedOnAccentColor,
                    ),
                    contentPadding = if (sessionActive) PaddingValues(0.dp) else ButtonDefaults.ContentPadding,
                ) {
                    AnimatedContent(
                        targetState = uiState.isRunning,
                        label = "startStop",
                    ) { isRunning ->
                        if (isRunning || uiState.isPaused) {
                            Icon(
                                imageVector = if (isRunning) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                                contentDescription = if (isRunning) stringResource(R.string.btn_pause) else stringResource(R.string.btn_resume),
                                modifier = Modifier.size(32.dp),
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

                if (uiState.canSkip) {
                    CircleControlButton(
                        onClick = {
                            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                            viewModel.onSkipClick()
                        },
                        containerColor = MaterialTheme.colorScheme.surfaceVariant,
                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.SkipNext,
                            contentDescription = "Skip to next phase",
                            modifier = Modifier.size(28.dp),
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            CompactFocusChip(
                text = if (uiState.selectedSoundscape != null) {
                    stringResource(uiState.selectedSoundscape!!.displayNameRes)
                } else {
                    stringResource(R.string.soundscape_choose)
                },
                leadingIcon = {
                    Text(
                        text = uiState.selectedSoundscape?.emoji ?: "\uD83D\uDD07",
                        style = MaterialTheme.typography.titleMedium,
                    )
                },
                trailingIcon = {
                    Icon(
                        imageVector = Icons.Rounded.MusicNote,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp),
                    )
                },
                onClick = { viewModel.onSoundscapePickerClick() },
            )

            AnimatedVisibility(
                visible = uiState.selectedSoundscape != null && !sessionActive,
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
        }

        SuccessToast(
            message = successMsg,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 24.dp),
            onDismiss = { viewModel.dismissSuccessMessage() },
        )
    }

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

    if (uiState.showBatteryWarningDialog) {
        AlertDialog(
            onDismissRequest = { viewModel.dismissBatteryWarning() },
            title = { Text(stringResource(R.string.setup_battery)) },
            text = { Text(stringResource(R.string.setup_battery_sub)) },
            confirmButton = {
                TextButton(
                    onClick = { viewModel.openBatterySettings() },
                ) {
                    Text(stringResource(R.string.setup_btn_disable_restriction))
                }
            },
            dismissButton = {
                TextButton(
                    onClick = { viewModel.startTimerAnyway() },
                ) {
                    Text(stringResource(R.string.btn_start_focus))
                }
            },
        )
    }
}

@Composable
private fun CircleControlButton(
    onClick: () -> Unit,
    containerColor: Color,
    contentColor: Color,
    content: @Composable () -> Unit,
) {
    Button(
        onClick = onClick,
        modifier = Modifier.size(56.dp),
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = containerColor,
            contentColor = contentColor,
        ),
        contentPadding = PaddingValues(0.dp),
    ) {
        content()
    }
}

@Composable
private fun CompactFocusChip(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leadingIcon: @Composable (() -> Unit)? = null,
    trailingIcon: @Composable (() -> Unit)? = null,
    minHeight: Dp = 40.dp,
) {
    GlassBox(
        modifier = modifier,
        cornerRadius = 22.dp
    ) {
        Row(
            modifier = Modifier
                .clickable(onClick = onClick)
                .height(minHeight)
                .padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (leadingIcon != null) {
                leadingIcon()
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(
                text = text,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (trailingIcon != null) {
                Spacer(modifier = Modifier.width(8.dp))
                trailingIcon()
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun FocusScreenPreview() {
    PepinilloTheme {
        FocusScreen()
    }
}
