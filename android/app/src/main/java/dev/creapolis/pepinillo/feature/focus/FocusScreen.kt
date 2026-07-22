package dev.creapolis.pepinillo.feature.focus

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import dev.creapolis.pepinillo.ui.theme.isAppInDarkTheme
import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import kotlinx.coroutines.delay
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
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.timer.FocusPhase
import dev.creapolis.pepinillo.feature.focus.components.CircularTimerRing
import dev.creapolis.pepinillo.feature.focus.components.ModeChip
import dev.creapolis.pepinillo.feature.focus.components.SessionJournalSheet
import dev.creapolis.pepinillo.feature.focus.components.TaskPickerDialog
import dev.creapolis.pepinillo.feature.soundscape.SoundscapePickerSheet
import dev.creapolis.pepinillo.ui.components.LocalSnackbarController
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

    // Spring scale on mode change
    var ringScaleTarget by remember { mutableStateOf(1f) }
    val ringScale by animateFloatAsState(
        targetValue = ringScaleTarget,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "ringScale"
    )
    LaunchedEffect(uiState.selectedMode) {
        ringScaleTarget = 0.92f
        delay(80)
        ringScaleTarget = 1.0f
    }

    // Phase-completion celebration: when a Pomodoro completes (completedSessions bumps),
    // fire a punch-out ring scale to mark the moment. Previously the ring silently swapped phase.
    LaunchedEffect(uiState.completedSessions, uiState.selectedMode) {
        if (uiState.completedSessions > 0 && uiState.selectedMode == FocusMode.Pomodoro) {
            ringScaleTarget = 1.08f
            delay(120)
            ringScaleTarget = 1.0f
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        }
    }

    // Breathing scale for emoji when running — disabled when reduce-motion is on (#401).
    val reduceMotion = isReduceMotionEnabled()
    val breatheScale by if (uiState.isRunning && !reduceMotion) {
        val infiniteTransition = rememberInfiniteTransition(label = "breathe")
        infiniteTransition.animateFloat(
            initialValue = 1f,
            targetValue = 1.06f,
            animationSpec = infiniteRepeatable(
                animation = tween(1000, easing = FastOutSlowInEasing),
                repeatMode = RepeatMode.Reverse
            ),
            label = "breatheScale"
        )
    } else {
        remember { mutableStateOf(1f) }
    }

    val context = LocalContext.current
    // Request POST_NOTIFICATIONS on the first session start (Android 13+).
    // The session always starts regardless of the user's choice.
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { /* granted or denied — session already started, nothing to do */ }

    val keepScreenActive = uiState.keepScreenOn && (uiState.isRunning || uiState.isPaused)
    val activity = context as? Activity
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
    val primaryTimerActionVisual = when {
        uiState.isRunning -> PrimaryTimerActionVisual.Pause
        uiState.isPaused || uiState.isWaitingForNext -> PrimaryTimerActionVisual.PlayCompact
        else -> PrimaryTimerActionVisual.StartExpanded
    }
    val timerSize by animateFloatAsState(
        targetValue = if (sessionActive) 292f else 268f,
        animationSpec = tween(500),
        label = "timerSize",
    )
    val buttonWidth by animateDpAsState(
        targetValue = if (primaryTimerActionVisual == PrimaryTimerActionVisual.StartExpanded) 280.dp else 72.dp,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 300f),
        label = "buttonWidth",
    )
    val buttonHeight by animateDpAsState(
        targetValue = if (primaryTimerActionVisual == PrimaryTimerActionVisual.StartExpanded) 60.dp else 72.dp,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 300f),
        label = "buttonHeight",
    )
    val buttonCornerRadius by animateDpAsState(
        targetValue = if (primaryTimerActionVisual == PrimaryTimerActionVisual.StartExpanded) 30.dp else 36.dp,
        animationSpec = spring(dampingRatio = 0.65f, stiffness = 300f),
        label = "buttonCornerRadius",
    )
    val snackbarController = LocalSnackbarController.current
    LaunchedEffect(viewModel.successMessage) {
        viewModel.successMessage.collect { resId ->
            if (resId != null) {
                snackbarController?.show(message = resId)
                viewModel.dismissSuccessMessage()
            }
        }
    }
    // Surface session-save failures with a Retry action instead of silent data loss.
    val failedSession by viewModel.lastFailedSession.collectAsState()
    LaunchedEffect(failedSession) {
        val failed = failedSession ?: return@LaunchedEffect
        snackbarController?.show(
            message = R.string.msg_session_save_failed,
            actionLabel = R.string.btn_retry,
            duration = androidx.compose.material3.SnackbarDuration.Long,
            onAction = { viewModel.retrySessionSave() },
        )
    }

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
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    FocusMode.entries.forEach { mode ->
                        ModeChip(
                            mode = mode,
                            isSelected = mode == uiState.selectedMode,
                            onClick = { viewModel.selectMode(mode) },
                            isLocked = !mode.isFreeTier && !uiState.isPro,
                            modifier = Modifier.weight(1f)
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
                    .scale(ringScale)
                    .semantics {
                        contentDescription = "$phaseLabel: ${uiState.displayTime}, $modeLabel mode"
                    },
            ) {
                // Ambient Radial Glow
                Box(
                    modifier = Modifier
                        .size(timerSize.dp)
                        .background(
                            Brush.radialGradient(
                                colors = listOf(
                                    animatedAccentColor.copy(alpha = if (isAppInDarkTheme()) 0.04f else 0.07f),
                                    Color.Transparent
                                )
                            )
                        )
                )

                CircularTimerRing(
                    progress = animatedProgress,
                    ringColor = animatedAccentColor,
                    trackColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
                    strokeWidth = if (sessionActive) 13.dp else 11.dp,
                    modifier = Modifier.size(timerSize.dp),
                    isRunning = uiState.isRunning,
                    showDashedOverlay = !uiState.isRunning && uiState.selectedMode.defaultTotalSeconds == null,
                )
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = uiState.selectedMode.emoji,
                        fontSize = 28.sp,
                        modifier = Modifier.scale(breatheScale),
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
                        CycleProgressPips(
                            completed = uiState.completedSessions,
                            total = uiState.sessionsBeforeLongBreak.coerceAtLeast(1),
                            modifier = Modifier.padding(top = 6.dp),
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

            // Distinguish "Waiting for next phase" from "Paused": surface a confirmation
            // banner so the user knows the previous phase finished and a tap starts the next one.
            AnimatedVisibility(
                visible = uiState.isWaitingForNext && !uiState.breakSuggested,
                enter = fadeIn(),
                exit = fadeOut(),
            ) {
                Text(
                    text = stringResource(R.string.msg_focus_complete_text),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.tertiary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .padding(top = 10.dp)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.4f))
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
                        containerColor = MaterialTheme.colorScheme.error.copy(alpha = 0.16f),
                        contentColor = MaterialTheme.colorScheme.error,
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
                        // On the first session start (idle state), request POST_NOTIFICATIONS
                        // on Android 13+. The session starts regardless of the user's choice.
                        if (!uiState.isRunning && !uiState.isPaused && !uiState.isWaitingForNext &&
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            ContextCompat.checkSelfPermission(
                                context, Manifest.permission.POST_NOTIFICATIONS,
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                        viewModel.onStartStopClick()
                    },
                    modifier = Modifier.size(width = buttonWidth, height = buttonHeight),
                    shape = RoundedCornerShape(buttonCornerRadius),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = animatedAccentColor,
                        contentColor = animatedOnAccentColor,
                    ),
                    contentPadding = if (primaryTimerActionVisual == PrimaryTimerActionVisual.StartExpanded) {
                        ButtonDefaults.ContentPadding
                    } else {
                        PaddingValues(0.dp)
                    },
                ) {
                    AnimatedContent(
                        targetState = primaryTimerActionVisual,
                        label = "startStop",
                    ) { visual ->
                        when (visual) {
                            PrimaryTimerActionVisual.Pause -> {
                                Icon(
                                    imageVector = Icons.Rounded.Pause,
                                    contentDescription = stringResource(R.string.btn_pause),
                                    modifier = Modifier.size(32.dp),
                                )
                            }

                            PrimaryTimerActionVisual.PlayCompact -> {
                                Icon(
                                    imageVector = Icons.Rounded.PlayArrow,
                                    contentDescription = if (uiState.isPaused) {
                                        stringResource(R.string.btn_resume)
                                    } else {
                                        stringResource(R.string.cd_start_timer)
                                    },
                                    modifier = Modifier.size(32.dp),
                                )
                            }

                            PrimaryTimerActionVisual.StartExpanded -> {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Rounded.PlayArrow,
                                        contentDescription = null,
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = stringResource(R.string.btn_start_focus),
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.SemiBold,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                }
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
                            contentDescription = stringResource(R.string.cd_skip_phase),
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
                        .padding(horizontal = 8.dp, vertical = 4.dp)
                        .semantics {
                            contentDescription = context.getString(R.string.cd_volume_control)
                        },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "\uD83D\uDD08",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.semantics {
                            contentDescription = context.getString(R.string.cd_volume_low)
                        },
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
                        modifier = Modifier.semantics {
                            contentDescription = context.getString(R.string.cd_volume_high)
                        },
                    )
                }
            }
        }
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

private enum class PrimaryTimerActionVisual {
    StartExpanded,
    Pause,
    PlayCompact,
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
    minHeight: Dp = 48.dp,
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(22.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.62f))
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

@Preview(showBackground = true)
@Composable
private fun FocusScreenPreview() {
    PepinilloTheme {
        FocusScreen()
    }
}

/**
 * Row of pips showing progress through the Pomodoro cycle toward the long break.
 * Filled pips = completed work sessions; the current/active pip is emphasized;
 * remaining pips are dimmed. Replaces the bare "completedSessions + 1" number.
 */
@Composable
private fun CycleProgressPips(
    completed: Int,
    total: Int,
    modifier: Modifier = Modifier,
) {
    val activeColor = MaterialTheme.colorScheme.primary
    val dimColor = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
    val activeIndex = completed.coerceIn(0, total - 1)
    val context = LocalContext.current
    Row(
        modifier = modifier.semantics {
            contentDescription = context.getString(R.string.cd_cycle_progress, completed, total)
        },
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        for (i in 0 until total) {
            val isDone = i < completed
            val isActive = i == activeIndex && completed < total
            val color = when {
                isDone -> activeColor
                isActive -> activeColor.copy(alpha = 0.6f)
                else -> dimColor
            }
            Box(
                modifier = Modifier
                    .size(width = 14.dp, height = 5.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(3.dp))
                    .background(color),
            )
        }
    }
}
