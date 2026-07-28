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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
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
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.ui.theme.AppTheme
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.ThemeMode

private const val PRIVACY_POLICY_URL = "https://creapolis.dev/privacy-policy/"
private const val TERMS_OF_USE_URL = "https://creapolis.dev/terms-of-use/"

@OptIn(ExperimentalLayoutApi::class, ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onNavigateBack: (() -> Unit)? = null,
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
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (onNavigateBack != null) {
                IconButton(
                    onClick = onNavigateBack,
                    modifier = Modifier.padding(end = 4.dp),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = stringResource(R.string.cd_back),
                        tint = MaterialTheme.colorScheme.onSurface,
                    )
                }
            }
            Column {
                Text(
                    text = stringResource(R.string.settings_title),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = stringResource(R.string.settings_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

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
                            text = stringResource(R.string.settings_app_setup),
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = if (hasPermissionIssues) {
                                stringResource(R.string.settings_action_required)
                            } else {
                                stringResource(R.string.settings_all_configured)
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
                            contentDescription = stringResource(R.string.cd_action_required),
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
                    .clip(PepinilloShapeTokens.card)
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
                            text = stringResource(R.string.settings_upgrade_promo),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Text(
                            text = stringResource(R.string.settings_unlock_all),
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
                                SubscriptionTier.EVERYWHERE_ANNUAL -> stringResource(R.string.settings_tier_everywhere)
                                else -> stringResource(R.string.settings_tier_plus)
                            },
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.Medium,
                            color = MaterialTheme.colorScheme.onSurface,
                        )
                        Text(
                            text = when (uiState.subscriptionTier) {
                                SubscriptionTier.PEPINILLO_PLUS -> stringResource(R.string.settings_lifetime_access)
                                SubscriptionTier.EVERYWHERE_MONTHLY -> stringResource(R.string.settings_monthly_sub)
                                SubscriptionTier.EVERYWHERE_ANNUAL -> stringResource(R.string.settings_annual_sub)
                                else -> stringResource(R.string.settings_lifetime_access)
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
        SectionHeader(icon = Icons.Rounded.Timer, title = stringResource(R.string.settings_sec_timer))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            StepperRow(
                label = stringResource(R.string.settings_focus_duration),
                value = stringResource(R.string.minutes_format, uiState.pomodoroMinutes),
                onDecrease = { viewModel.updatePomodoroMinutes(uiState.pomodoroMinutes - 5) },
                onIncrease = { viewModel.updatePomodoroMinutes(uiState.pomodoroMinutes + 5) },
            )
            SettingsDivider()
            StepperRow(
                label = stringResource(R.string.settings_short_break),
                value = stringResource(R.string.minutes_format, uiState.shortBreakMinutes),
                onDecrease = { viewModel.updateShortBreakMinutes(uiState.shortBreakMinutes - 1) },
                onIncrease = { viewModel.updateShortBreakMinutes(uiState.shortBreakMinutes + 1) },
            )
            SettingsDivider()
            StepperRow(
                label = stringResource(R.string.settings_long_break),
                value = stringResource(R.string.minutes_format, uiState.longBreakMinutes),
                onDecrease = { viewModel.updateLongBreakMinutes(uiState.longBreakMinutes - 5) },
                onIncrease = { viewModel.updateLongBreakMinutes(uiState.longBreakMinutes + 5) },
            )
            SettingsDivider()
            StepperRow(
                label = stringResource(R.string.settings_sessions_before_long),
                value = "${uiState.sessionsBeforeLongBreak}",
                onDecrease = { viewModel.updateSessionsBeforeLongBreak(uiState.sessionsBeforeLongBreak - 1) },
                onIncrease = { viewModel.updateSessionsBeforeLongBreak(uiState.sessionsBeforeLongBreak + 1) },
            )
            SettingsDivider()
            StepperRow(
                label = stringResource(R.string.settings_time_block_duration),
                value = stringResource(R.string.minutes_format, uiState.timeBlockMinutes),
                onDecrease = { viewModel.updateTimeBlockMinutes(uiState.timeBlockMinutes - 15) },
                onIncrease = { viewModel.updateTimeBlockMinutes(uiState.timeBlockMinutes + 15) },
            )
            SettingsDivider()
            SwitchRow(
                label = stringResource(R.string.settings_midpoint_checkin),
                subtitle = stringResource(R.string.settings_midpoint_checkin_sub),
                isChecked = uiState.midpointCheckIn,
                onToggle = viewModel::toggleMidpointCheckIn,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── FLOWTIME SECTION ──
        SectionHeader(icon = Icons.Rounded.AvTimer, title = stringResource(R.string.settings_sec_flowtime))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            StepperRow(
                label = stringResource(R.string.settings_flowtime_min),
                value = stringResource(R.string.minutes_format, uiState.flowtimeMinMinutes),
                onDecrease = { viewModel.updateFlowtimeMinMinutes(uiState.flowtimeMinMinutes - 1) },
                onIncrease = { viewModel.updateFlowtimeMinMinutes(uiState.flowtimeMinMinutes + 1) },
            )
        }
        Text(
            text = stringResource(R.string.settings_flowtime_min_sub),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp, start = 4.dp),
        )

        Spacer(modifier = Modifier.height(28.dp))

        // ── BEHAVIOR SECTION ──
        SectionHeader(icon = Icons.Rounded.Settings, title = stringResource(R.string.settings_sec_behavior))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            SwitchRow(
                label = stringResource(R.string.auto_start_breaks),
                subtitle = stringResource(R.string.settings_auto_start_breaks_sub),
                isChecked = uiState.autoStartBreaks,
                onToggle = viewModel::toggleAutoStartBreaks,
            )
            SettingsDivider()
            SwitchRow(
                label = stringResource(R.string.settings_auto_start_next),
                subtitle = stringResource(R.string.settings_auto_start_next_sub),
                isChecked = uiState.autoStartNextPomodoro,
                onToggle = viewModel::toggleAutoStartNextPomodoro,
            )
            SettingsDivider()
            SwitchRow(
                label = stringResource(R.string.settings_post_session_reflection),
                subtitle = stringResource(R.string.settings_post_session_reflection_sub),
                isChecked = uiState.showJournalAfterSession,
                onToggle = viewModel::toggleShowJournalAfterSession,
            )
            SettingsDivider()
            SwitchRow(
                label = stringResource(R.string.sound),
                subtitle = stringResource(R.string.settings_sound_sub),
                icon = Icons.Rounded.VolumeUp,
                isChecked = uiState.soundEnabled,
                onToggle = viewModel::toggleSound,
            )
            SettingsDivider()
            SwitchRow(
                label = stringResource(R.string.settings_haptic_feedback),
                subtitle = stringResource(R.string.settings_haptic_feedback_sub),
                icon = Icons.Rounded.Vibration,
                isChecked = uiState.vibrationEnabled,
                onToggle = viewModel::toggleVibration,
            )
            // Periodic pulse sub-toggle — only meaningful when the master haptic toggle is on.
            AnimatedVisibility(visible = uiState.vibrationEnabled) {
                Column {
                    SettingsDivider()
                    SwitchRow(
                        label = stringResource(R.string.settings_haptic_timer_tick),
                        subtitle = stringResource(R.string.settings_haptic_timer_tick_sub),
                        isChecked = uiState.hapticTimerTickEnabled,
                        onToggle = viewModel::toggleHapticTimerTick,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── GENERAL SECTION ──
        SectionHeader(icon = Icons.Rounded.Tune, title = stringResource(R.string.settings_sec_general))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            // Default mode selector
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    text = stringResource(R.string.settings_default_mode),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = stringResource(R.string.settings_default_mode_sub),
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
                label = stringResource(R.string.settings_keep_screen_on),
                subtitle = stringResource(R.string.settings_keep_screen_on_sub),
                isChecked = uiState.keepScreenOn,
                onToggle = viewModel::toggleKeepScreenOn,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── APPEARANCE SECTION ──
        SectionHeader(icon = Icons.Rounded.Palette, title = stringResource(R.string.settings_sec_appearance))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            // Theme picker
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    text = stringResource(R.string.settings_theme),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.settings_theme_sub),
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
                            "classic" -> stringResource(R.string.theme_classic)
                            "materialYou" -> stringResource(R.string.theme_material_you)
                            "forest" -> stringResource(R.string.theme_forest)
                            "ocean" -> stringResource(R.string.theme_ocean)
                            "sunset" -> stringResource(R.string.theme_sunset)
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

            // Dynamic color toggle (Material You) — exposes the existing VM capability
            // that was previously hidden. Only relevant on Android 12+ (#405).
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                SwitchRow(
                    label = stringResource(R.string.settings_dynamic_color),
                    subtitle = stringResource(R.string.settings_dynamic_color_sub),
                    isChecked = uiState.dynamicColor,
                    onToggle = { viewModel.toggleDynamicColor() },
                )
                SettingsDivider()
            }

            // Light/Dark/System selector
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    text = stringResource(R.string.settings_sec_appearance),
                    style = MaterialTheme.typography.titleSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.settings_appearance_sub),
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
                        val modeLabel = when (mode) {
                            ThemeMode.System -> stringResource(R.string.theme_mode_system)
                            ThemeMode.Light -> stringResource(R.string.theme_mode_light)
                            ThemeMode.Dark -> stringResource(R.string.theme_mode_dark)
                        }
                        OptionPill(
                            label = modeLabel,
                            isSelected = uiState.themeMode == mode,
                            onClick = { viewModel.setThemeMode(mode) },
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── NOTIFICATIONS SECTION ──
        SectionHeader(icon = Icons.Rounded.Notifications, title = stringResource(R.string.settings_sec_notifications))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            SwitchRow(
                label = stringResource(R.string.settings_timer_alerts),
                subtitle = stringResource(R.string.settings_timer_alerts_sub),
                isChecked = uiState.timerNotificationsEnabled,
                onToggle = viewModel::toggleTimerNotifications,
            )
            SettingsDivider()
            SwitchRow(
                label = stringResource(R.string.settings_daily_reminder),
                subtitle = stringResource(R.string.settings_daily_reminder_sub),
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
        SectionHeader(icon = Icons.Rounded.LocalFireDepartment, title = stringResource(R.string.settings_sec_streak))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 14.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.settings_current_streak),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    text = stringResource(R.string.dashboard_days_count, uiState.currentStreak),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // ── SYNC STATUS SECTION ──
        if (uiState.isLoggedIn) {
            Spacer(modifier = Modifier.height(28.dp))

            SectionHeader(icon = Icons.Rounded.Sync, title = stringResource(R.string.settings_sec_sync))
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
                        text = if (uiState.isOnline) stringResource(R.string.settings_sync_online) else stringResource(R.string.settings_sync_offline),
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
                        text = stringResource(R.string.settings_last_synced),
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
                            text = stringResource(R.string.settings_pending_changes),
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
                            text = stringResource(R.string.settings_syncing),
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
                            text = stringResource(R.string.settings_sync_now),
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

        SectionHeader(icon = Icons.Rounded.Security, title = stringResource(R.string.settings_sec_operation))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            NavigationRow(label = stringResource(R.string.settings_app_setup), onClick = onNavigateToAppSetup)
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── ABOUT SECTION ──
        SectionHeader(icon = Icons.Rounded.Info, title = stringResource(R.string.settings_sec_about))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            NavigationRow(label = stringResource(R.string.settings_version), trailing = uiState.appVersion)
            SettingsDivider()
                NavigationRow(
                    label = stringResource(R.string.settings_privacy),
                    onClick = { openExternalUrl(context, PRIVACY_POLICY_URL) },
                )
            SettingsDivider()
                NavigationRow(
                    label = stringResource(R.string.settings_terms),
                    onClick = { openExternalUrl(context, TERMS_OF_USE_URL) },
                )
            SettingsDivider()
            NavigationRow(label = stringResource(R.string.settings_licenses))
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Footer
        Text(
            text = stringResource(R.string.settings_footer),
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
                    contentDescription = stringResource(R.string.cd_decrease),
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
                    contentDescription = stringResource(R.string.cd_increase),
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
            .clip(PepinilloShapeTokens.card)
            .background(bgColor)
            .clickable(onClick = onClick)
            .heightIn(min = 48.dp)
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
            .clip(PepinilloShapeTokens.button)
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = borderColor,
                shape = PepinilloShapeTokens.button,
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
                contentDescription = stringResource(R.string.cd_pro_feature),
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
            text = stringResource(R.string.settings_reminder_time),
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
                    .clip(PepinilloShapeTokens.card)
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = stringResource(R.string.settings_select_time),
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
                        text = stringResource(R.string.btn_cancel),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(PepinilloShapeTokens.button)
                            .clickable { showPicker = false }
                            .padding(horizontal = 16.dp, vertical = 8.dp),
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = stringResource(R.string.btn_ok),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(PepinilloShapeTokens.button)
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
    if (lastSyncAt == null) return stringResource(R.string.settings_sync_never)
    val now = System.currentTimeMillis()
    val diffMs = now - lastSyncAt
    val diffMinutes = diffMs / (1000 * 60)
    val diffHours = diffMinutes / 60
    val diffDays = diffHours / 24
    return when {
        diffMinutes < 1 -> stringResource(R.string.settings_sync_just_now)
        diffMinutes < 60 -> stringResource(R.string.settings_sync_min_ago, diffMinutes)
        diffHours < 24 -> stringResource(R.string.settings_sync_hr_ago, diffHours)
        else -> stringResource(R.string.settings_sync_days_ago, diffDays)
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
