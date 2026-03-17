package dev.creapolis.pepinillo.feature.settings

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.ui.theme.PepinilloTheme
import dev.creapolis.pepinillo.ui.theme.ThemeMode

@Composable
fun SettingsScreen(
    modifier: Modifier = Modifier,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

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
                onDecrease = { viewModel.updateTimeBlockMinutes(uiState.timeBlockMinutes - 10) },
                onIncrease = { viewModel.updateTimeBlockMinutes(uiState.timeBlockMinutes + 10) },
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── BEHAVIOR SECTION ──
        SectionHeader(icon = Icons.Rounded.Notifications, title = "Behavior")
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

        // ── APPEARANCE SECTION ──
        SectionHeader(icon = Icons.Rounded.Palette, title = "Appearance")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            // Theme mode selector
            Column(modifier = Modifier.padding(vertical = 12.dp)) {
                Text(
                    text = "Theme",
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = "Choose light, dark, or system default",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    ThemeMode.entries.forEach { mode ->
                        ThemeOptionPill(
                            label = mode.label,
                            isSelected = uiState.themeMode == mode,
                            onClick = { viewModel.setThemeMode(mode) },
                        )
                    }
                }
            }
            SettingsDivider()
            SwitchRow(
                label = "Dynamic color",
                subtitle = "Match your wallpaper colors",
                isChecked = uiState.dynamicColor,
                onToggle = viewModel::toggleDynamicColor,
            )
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── ABOUT SECTION ──
        SectionHeader(icon = Icons.Rounded.Info, title = "About")
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            NavigationRow(label = "Version", trailing = uiState.appVersion)
            SettingsDivider()
            NavigationRow(label = "Privacy Policy")
            SettingsDivider()
            NavigationRow(label = "Terms of Service")
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
private fun SectionHeader(icon: ImageVector, title: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
        )
    }
}

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant,
                shape = RoundedCornerShape(24.dp),
            )
            .padding(horizontal = 20.dp, vertical = 4.dp),
    ) {
        Column { content() }
    }
}

@Composable
private fun SettingsDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
    )
}

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
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            IconButton(
                onClick = onDecrease,
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            ) {
                Icon(
                    Icons.Rounded.Remove,
                    contentDescription = "Decrease",
                    modifier = Modifier.size(16.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = value,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            IconButton(
                onClick = onIncrease,
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)),
            ) {
                Icon(
                    Icons.Rounded.Add,
                    contentDescription = "Increase",
                    modifier = Modifier.size(16.dp),
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
private fun ThemeOptionPill(
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
        label = "themeOptionBg",
    )
    val textColor by animateColorAsState(
        targetValue = if (isSelected) {
            MaterialTheme.colorScheme.onPrimary
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        animationSpec = spring(),
        label = "themeOptionText",
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
private fun NavigationRow(
    label: String,
    trailing: String? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { }
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        if (trailing != null) {
            Text(
                text = trailing,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(modifier = Modifier.width(4.dp))
        Icon(
            imageVector = Icons.Rounded.ChevronRight,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
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
