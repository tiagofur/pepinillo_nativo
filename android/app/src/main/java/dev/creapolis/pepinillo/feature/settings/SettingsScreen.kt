package dev.creapolis.pepinillo.feature.settings

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.AvTimer
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Security
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.SyncDisabled
import androidx.compose.material.icons.rounded.CloudOff
import androidx.compose.material.icons.rounded.CloudDone
import androidx.compose.material.icons.rounded.Warning
import dev.creapolis.pepinillo.core.billing.SubscriptionTier
import dev.creapolis.pepinillo.data.sync.SyncState
import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.compose.ui.res.stringResource
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.ThemeMode

private const val PRIVACY_POLICY_URL = "https://creapolis.dev/privacy-policy/"
private const val TERMS_OF_USE_URL = "https://creapolis.dev/terms-of-use/"

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateToAppSetup: () -> Unit = {},
    onNavigateToPaywall: () -> Unit = {},
    modifier: Modifier = Modifier,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    // Check critical permissions for warning badge
    var hasPermissionIssues by remember { mutableStateOf(false) }
    fun checkPermissions() {
        val notificationsOk = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        } else true
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val batteryOk = pm.isIgnoringBatteryOptimizations(context.packageName)
        hasPermissionIssues = !notificationsOk || !batteryOk
    }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { checkPermissions() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // ── HEADER ──
        Text(
            text = "Settings",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = "Customize your experience",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(20.dp))

        // ── APP SETUP BANNER ──
        if (hasPermissionIssues) {
            SettingsCard {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(onClick = onNavigateToAppSetup)
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Rounded.Security,
                        contentDescription = null,
                        modifier = Modifier.size(24.dp),
                        tint = if (hasPermissionIssues) {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.primary
                        },
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "App Setup",
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = if (hasPermissionIssues) {
                                "Action required for best experience"
                            } else {
                                "All permissions configured"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = if (hasPermissionIssues) {
                                MaterialTheme.colorScheme.error
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant
                            },
                        )
                    }
                    if (hasPermissionIssues) {
                        Icon(
                            imageVector = Icons.Rounded.Warning,
                            contentDescription = "Action required",
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                    }
                    Icon(
                        imageVector = Icons.Rounded.ChevronRight,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }

        // ── SUBSCRIPTION SECTION ──
        if (!uiState.isPro) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(24.dp))
                    .background(MaterialTheme.colorScheme.primaryContainer)
                    .clickable(onClick = onNavigateToPaywall)
                    .padding(20.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Rounded.Star,
                        contentDescription = null,
                        modifier = Modifier.size(28.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Upgrade to Pepinillo+",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Text(
                            text = "Unlock all modes, unlimited tasks & more",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.8f),
                        )
                    }
                    Icon(
                        imageVector = Icons.Rounded.ChevronRight,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.5f),
                    )
                }
            }
        } else {
            SettingsCard {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Rounded.CheckCircle,
                        contentDescription = null,
                        modifier = Modifier.size(24.dp),
                        tint = MaterialTheme.colorScheme.primary,
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = when (uiState.subscriptionTier) {
                                SubscriptionTier.EVERYWHERE_MONTHLY,
                                SubscriptionTier.EVERYWHERE_ANNUAL -> "Everywhere / AI+"
                                else -> "Pepinillo+"
                            },
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = when (uiState.subscriptionTier) {
                                SubscriptionTier.PEPINILLO_PLUS -> "Lifetime access"
                                SubscriptionTier.EVERYWHERE_MONTHLY -> "Monthly subscription"
                                SubscriptionTier.EVERYWHERE_ANNUAL -> "Annual subscription"
                                else -> "Lifetime access"
                            },
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── TIMER SECTION ──
        SectionHeader(icon = Icons.Rounded.Timer, title = "Timer")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            StepperRow(
                label = "Focus duration",
                value = "${uiState.pomodoroMinutes} min",
                onDecrease = { viewModel.updatePomodoroMinutes(uiState.pomodoroMinutes - 5) },
                onIncrease = { viewModel.updatePomodoroMinutes(uiState.pomodoroMinutes + 5) },
            )
            SettingsDivider()
            StepperRow(
                label = "Short break",
                value = "${uiState.shortBreakMinutes} min",
                onDecrease = { viewModel.updateShortBreakMinutes(uiState.shortBreakMinutes - 1) },
                onIncrease = { viewModel.updateShortBreakMinutes(uiState.shortBreakMinutes + 1) },
            )
            SettingsDivider()
            StepperRow(
                label = "Long break",
                value = "${uiState.longBreakMinutes} min",
                onDecrease = { viewModel.updateLongBreakMinutes(uiState.longBreakMinutes - 5) },
                onIncrease = { viewModel.updateLongBreakMinutes(uiState.longBreakMinutes + 5) },
            )
            SettingsDivider()
            StepperRow(
                label = "Sessions before long break",
                value = "${uiState.sessionsBeforeLongBreak}",
                onDecrease = { viewModel.updateSessionsBeforeLongBreak(uiState.sessionsBeforeLongBreak - 1) },
                onIncrease = { viewModel.updateSessionsBeforeLongBreak(uiState.sessionsBeforeLongBreak + 1) },
            )
            SettingsDivider()
            StepperRow(
                label = "Time block duration",
                value = "${uiState.timeBlockMinutes} min",
                onDecrease = { viewModel.updateTimeBlockMinutes(uiState.timeBlockMinutes - 15) },
                onIncrease = { viewModel.updateTimeBlockMinutes(uiState.timeBlockMinutes + 15) },
            )
            SettingsDivider()
            SwitchRow(
                label = "Midpoint check-in",
                subtitle = "Reminder at halfway through time blocks",
                isChecked = uiState.midpointCheckIn,
                onToggle = viewModel::toggleMidpointCheckIn,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── FLOWTIME SECTION ──
        SectionHeader(icon = Icons.Rounded.AvTimer, title = "Flowtime")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            StepperRow(
                label = "Minimum session",
                value = "${uiState.flowtimeMinMinutes} min",
                onDecrease = { viewModel.updateFlowtimeMinMinutes(uiState.flowtimeMinMinutes - 1) },
                onIncrease = { viewModel.updateFlowtimeMinMinutes(uiState.flowtimeMinMinutes + 1) },
            )
        }
        Text(
            text = "Minimum focus time before a break is suggested",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp, start = 4.dp),
        )

        Spacer(modifier = Modifier.height(28.dp))

        // ── BEHAVIOR SECTION ──
        SectionHeader(icon = Icons.Rounded.Settings, title = "Behavior")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            SwitchRow(
                label = "Auto-start breaks",
                subtitle = "Start break timer automatically",
                isChecked = uiState.autoStartBreaks,
                onToggle = viewModel::toggleAutoStartBreaks,
            )
            SettingsDivider()
            SwitchRow(
                label = "Auto-start next session",
                subtitle = "Continue after break ends",
                isChecked = uiState.autoStartNextPomodoro,
                onToggle = viewModel::toggleAutoStartNextPomodoro,
            )
            SettingsDivider()
            SwitchRow(
                label = "Post-session reflection",
                subtitle = "Show journal after each focus session",
                isChecked = uiState.showJournalAfterSession,
                onToggle = viewModel::toggleShowJournalAfterSession,
            )
            SettingsDivider()
            SwitchRow(
                label = "Sound",
                subtitle = "Play sound when timer ends",
                icon = Icons.Rounded.VolumeUp,
                isChecked = uiState.soundEnabled,
                onToggle = viewModel::toggleSound,
            )
            SettingsDivider()
            SwitchRow(
                label = "Vibration",
                subtitle = "Vibrate when timer ends",
                icon = Icons.Rounded.Vibration,
                isChecked = uiState.vibrationEnabled,
                onToggle = viewModel::toggleVibration,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── GENERAL SECTION ──
        SectionHeader(icon = Icons.Rounded.Tune, title = "General")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            // Default mode selector
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    text = "Default mode",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "Mode selected when app launches",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(12.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FocusMode.entries.forEach { mode ->
                        val isModeLocked = !mode.isFreeTier && !uiState.isPro
                        val modeName = stringResource(mode.labelRes)
                        OptionPill(
                            label = if (isModeLocked) "$modeName \uD83D\uDD12" else modeName,
                            isSelected = uiState.defaultMode == mode,
                            onClick = {
                                if (!isModeLocked) {
                                    viewModel.setDefaultMode(mode)
                                }
                            },
                        )
                    }
                }
            }
            SettingsDivider()
            SwitchRow(
                label = "Keep screen on",
                subtitle = "Prevent screen from sleeping during focus",
                isChecked = uiState.keepScreenOn,
                onToggle = viewModel::toggleKeepScreenOn,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── APPEARANCE SECTION ──
        SectionHeader(icon = Icons.Rounded.Palette, title = "Appearance")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            // Theme picker
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    "Theme",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    "Choose a color theme for your focus modes",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(modifier = Modifier.height(12.dp))
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(AppTheme.all) { theme ->
                        val displayName = when (theme.id) {
                            "classic" -> "Classic"
                            "materialYou" -> "Material You"
                            "forest" -> "Forest"
                            "ocean" -> "Ocean"
                            "sunset" -> "Sunset"
                            else -> theme.id
                        }
                        val isLocked = !theme.isFree && !uiState.isPro
                        ThemeCard(
                            theme = theme,
                            displayName = displayName,
                            isSelected = uiState.selectedTheme == theme.id,
                            isLocked = isLocked,
                            onClick = {
                                if (!isLocked) {
                                    viewModel.setSelectedTheme(theme.id)
                                }
                            },
                        )
                    }
                }
            }

            SettingsDivider()

            // Light/Dark/System selector
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    "Appearance",
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    "Choose light, dark, or system default",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) {
                    ThemeMode.entries.forEach { mode ->
                        OptionPill(
                            label = mode.label,
                            isSelected = uiState.themeMode == mode,
                            onClick = { viewModel.setThemeMode(mode) },
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── NOTIFICATIONS SECTION ──
        SectionHeader(icon = Icons.Rounded.Notifications, title = "Notifications")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            SwitchRow(
                label = "Timer alerts",
                subtitle = "Show notification when timer finishes",
                isChecked = uiState.timerNotificationsEnabled,
                onToggle = viewModel::toggleTimerNotifications,
            )
            SettingsDivider()
            SwitchRow(
                label = "Daily reminder",
                subtitle = "Get reminded to focus each day",
                isChecked = uiState.dailyReminderEnabled,
                onToggle = viewModel::toggleDailyReminder,
            )
            AnimatedVisibility(visible = uiState.dailyReminderEnabled) {
                Column {
                    SettingsDivider()
                    ReminderTimeRow(
                        hour = uiState.dailyReminderHour,
                        minute = uiState.dailyReminderMinute,
                        onTimeSelected = { h, m -> viewModel.updateDailyReminderTime(h, m) },
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── STREAK SECTION ──
        SectionHeader(icon = Icons.Rounded.LocalFireDepartment, title = "Streak")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Current streak",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = "${uiState.currentStreak} days",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // ── SYNC STATUS SECTION ──
        if (uiState.isLoggedIn) {
            Spacer(modifier = Modifier.height(28.dp))

            SectionHeader(icon = Icons.Rounded.Sync, title = "Sync")
            Spacer(modifier = Modifier.height(12.dp))

            SettingsCard {
                // Online status
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = if (uiState.isOnline) Icons.Rounded.CloudDone else Icons.Rounded.CloudOff,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = if (uiState.isOnline) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Text(
                        text = if (uiState.isOnline) "Online" else "Offline",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                }

                SettingsDivider()

                // Last synced
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = "Last synced",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.weight(1f),
                    )
                    Text(
                        text = formatLastSyncTime(uiState.lastSyncAt),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                // Pending changes
                if (uiState.pendingChangesCount > 0) {
                    SettingsDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = "Pending changes",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f),
                        )
                        Text(
                            text = "${uiState.pendingChangesCount}",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    }
                }

                // Sync error
                if (uiState.syncState is SyncState.Error) {
                    SettingsDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Warning,
                            contentDescription = null,
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = (uiState.syncState as SyncState.Error).message,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.weight(1f),
                            maxLines = 2,
                        )
                    }
                }

                SettingsDivider()

                // Sync Now button
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(
                            enabled = uiState.syncState !is SyncState.Syncing && uiState.isOnline,
                            onClick = { viewModel.requestSync() },
                        )
                        .padding(vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                ) {
                    if (uiState.syncState is SyncState.Syncing) {
                        androidx.compose.material3.CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Syncing...",
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    } else {
                        Icon(
                            imageVector = Icons.Rounded.Sync,
                            contentDescription = null,
                            modifier = Modifier.size(18.dp),
                            tint = if (uiState.isOnline) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                            },
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Sync Now",
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = if (uiState.isOnline) {
                                MaterialTheme.colorScheme.primary
                            } else {
                                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                            },
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── ABOUT SECTION ──
        SectionHeader(icon = Icons.Rounded.Info, title = "About")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            NavigationRow(label = "Version", trailing = uiState.appVersion)
            if (!hasPermissionIssues) {
                SettingsDivider()
                NavigationRow(label = "App Setup", onClick = onNavigateToAppSetup)
            }
            SettingsDivider()
                NavigationRow(
                    label = "Privacy Policy",
                    onClick = { openExternalUrl(context, PRIVACY_POLICY_URL) },
                )
            SettingsDivider()
                NavigationRow(
                    label = "Terms of Service",
                    onClick = { openExternalUrl(context, TERMS_OF_USE_URL) },
                )
            SettingsDivider()
            NavigationRow(label = "Open Source Licenses")
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Footer
        Text(
            text = "Made with \u2764 by Creapolis",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.align(Alignment.CenterHorizontally),
        )

        Spacer(modifier = Modifier.height(24.dp))
    }
}

// ── Reusable components ──

@Composable
private fun StepperRow(
    label: String,
    value: String,
    onDecrease: () -> Unit,
    onIncrease: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = value,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            IconButton(
                onClick = onDecrease,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            ) {
                Icon(
                    Icons.Rounded.Remove,
                    contentDescription = "Decrease",
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            IconButton(
                onClick = onIncrease,
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            ) {
                Icon(
                    Icons.Rounded.Add,
                    contentDescription = "Increase",
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SwitchRow(
    label: String,
    subtitle: String,
    isChecked: Boolean,
    onToggle: () -> Unit,
    icon: ImageVector? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onToggle)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(modifier = Modifier.width(12.dp))
        Switch(
            checked = isChecked,
            onCheckedChange = { onToggle() },
            colors = SwitchDefaults.colors(
                checkedTrackColor = MaterialTheme.colorScheme.primary,
                checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
            ),
        )
    }
}

@Composable
private fun OptionPill(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val bgColor by animateColorAsState(
        targetValue = if (isSelected) {
            MaterialTheme.colorScheme.primary
        } else {
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        },
        animationSpec = spring(),
        label = "optionPillBg",
    )
    val textColor by animateColorAsState(
        targetValue = if (isSelected) {
            MaterialTheme.colorScheme.onPrimary
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        animationSpec = spring(),
        label = "optionPillText",
    )

    Text(
        text = label,
        style = MaterialTheme.typography.labelLarge,
        color = textColor,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bgColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 10.dp),
    )
}

@Composable
private fun ThemeCard(
    theme: AppTheme,
    displayName: String,
    isSelected: Boolean,
    isLocked: Boolean,
    onClick: () -> Unit,
) {
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) theme.pomodoroColor else MaterialTheme.colorScheme.outlineVariant,
        label = "themeBorder",
    )
    val backgroundColor by animateColorAsState(
        targetValue = if (isSelected) theme.pomodoroColor.copy(alpha = 0.08f) else Color.Transparent,
        label = "themeBg",
    )

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .width(80.dp)
            .clip(RoundedCornerShape(12.dp))
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = RoundedCornerShape(12.dp),
            )
            .background(backgroundColor)
            .clickable(enabled = !isLocked, onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 8.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf(
                theme.pomodoroColor,
                theme.flowtimeColor,
                theme.timeBlockColor,
                theme.stopwatchColor,
            ).forEach { color ->
                Box(
                    modifier = Modifier
                        .size(14.dp)
                        .clip(CircleShape)
                        .background(color),
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = displayName,
            style = MaterialTheme.typography.labelSmall,
            color = if (isSelected) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
            textAlign = TextAlign.Center,
            maxLines = 1,
        )
        if (isLocked) {
            Spacer(modifier = Modifier.height(4.dp))
            Icon(
                imageVector = Icons.Rounded.Lock,
                contentDescription = "Pro feature",
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                modifier = Modifier.size(14.dp),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderTimeRow(
    hour: Int,
    minute: Int,
    onTimeSelected: (Int, Int) -> Unit,
) {
    var showPicker by remember { mutableStateOf(false) }
    val formattedTime = remember(hour, minute) {
        val h = if (hour % 12 == 0) 12 else hour % 12
        val amPm = if (hour < 12) "AM" else "PM"
        String.format("%d:%02d %s", h, minute, amPm)
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { showPicker = true }
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "Reminder time",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = formattedTime,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.primary,
        )
    }

    if (showPicker) {
        val timePickerState = rememberTimePickerState(
            initialHour = hour,
            initialMinute = minute,
        )
        Dialog(onDismissRequest = { showPicker = false }) {
            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(28.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = "Select time",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(16.dp))
                TimePicker(state = timePickerState)
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                ) {
                    Text(
                        text = "Cancel",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .clickable { showPicker = false }
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "OK",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .clickable {
                                onTimeSelected(timePickerState.hour, timePickerState.minute)
                                showPicker = false
                            }
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                }
            }
        }
    }
}


@Composable
private fun formatLastSyncTime(lastSyncAt: Long?): String {
    if (lastSyncAt == null) return "Never"
    val now = System.currentTimeMillis()
    val diffMs = now - lastSyncAt
    val diffMinutes = diffMs / (1000 * 60)
    val diffHours = diffMinutes / 60
    val diffDays = diffHours / 24
    return when {
        diffMinutes < 1 -> "Just now"
        diffMinutes < 60 -> "$diffMinutes min ago"
        diffHours < 24 -> "$diffHours hr ago"
        else -> "$diffDays days ago"
    }
}
private fun openExternalUrl(context: Context, url: String) {
    runCatching {
        context.startActivity(
            Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun SettingsScreenPreview() {
    PepinilloTheme {
        SettingsScreen()
    }
}
