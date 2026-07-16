package dev.creapolis.pepinillo.feature.settings

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Alarm
import androidx.compose.material.icons.rounded.BatterySaver
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.PhonelinkSetup
import androidx.compose.material.icons.rounded.Security
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import dev.creapolis.pepinillo.util.ManufacturerUtils
import androidx.compose.ui.res.stringResource
import dev.creapolis.pepinillo.R

@Composable
fun AppSetupScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: AppSetupViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current

    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        viewModel.refreshPermissions()
    }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { viewModel.refreshPermissions() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(8.dp))

        // ── TOP BAR ──
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(
                    imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                    contentDescription = stringResource(R.string.cd_go_back),
                )
            }
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = stringResource(R.string.setup_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
        }

        Spacer(modifier = Modifier.height(20.dp))

        // ── SUMMARY CARD ──
        SettingsCard {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = if (uiState.allConfigured) {
                        Icons.Rounded.CheckCircle
                    } else {
                        Icons.Rounded.Security
                    },
                    contentDescription = stringResource(R.string.cd_permission_status),
                    modifier = Modifier.size(40.dp),
                    tint = if (uiState.allConfigured) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        MaterialTheme.colorScheme.error
                    },
                )
                Spacer(modifier = Modifier.width(16.dp))
                Column {
                    Text(
                        text = if (uiState.allConfigured) {
                            stringResource(R.string.setup_all_set)
                        } else {
                            stringResource(
                                R.string.setup_configured_count,
                                uiState.grantedCount,
                                uiState.totalCount,
                            )
                        },
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = if (uiState.allConfigured) {
                            stringResource(R.string.setup_all_set_sub)
                        } else {
                            stringResource(R.string.setup_action_required_sub)
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── PERMISSIONS ──
        SectionHeader(icon = Icons.Rounded.Security, title = stringResource(R.string.setup_sec_permissions))
        Spacer(modifier = Modifier.height(12.dp))

        SettingsCard {
            // 1. Notifications
            PermissionItemRow(
                icon = Icons.Rounded.Notifications,
                title = stringResource(R.string.setup_notifications),
                description = stringResource(R.string.setup_notifications_sub),
                isGranted = uiState.notificationsGranted,
                actionLabel = stringResource(R.string.setup_btn_enable),
                onAction = {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        openAppNotificationSettings(context)
                    }
                },
            )

            SettingsDivider()

            // 2. Battery optimization
            PermissionItemRow(
                icon = Icons.Rounded.BatterySaver,
                title = stringResource(R.string.setup_battery),
                description = stringResource(R.string.setup_battery_sub),
                isGranted = uiState.batteryOptimizationExcluded,
                actionLabel = stringResource(R.string.setup_btn_disable_restriction),
                onAction = {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:${context.packageName}"),
                        )
                        context.startActivity(intent)
                    } catch (_: ActivityNotFoundException) {
                        try {
                            context.startActivity(
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                            )
                        } catch (_: ActivityNotFoundException) {
                            Toast.makeText(context, context.getString(R.string.toast_battery_settings_error), Toast.LENGTH_SHORT).show()
                        }
                    }
                },
            )

            // 3. Exact alarms (API 31+)
            if (uiState.showExactAlarmsRow) {
                SettingsDivider()
                PermissionItemRow(
                    icon = Icons.Rounded.Alarm,
                    title = stringResource(R.string.setup_alarms),
                    description = stringResource(R.string.setup_alarms_sub),
                    isGranted = uiState.exactAlarmsAllowed,
                    actionLabel = stringResource(R.string.setup_btn_allow),
                    onAction = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                context.startActivity(
                                    Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                        data = Uri.parse("package:${context.packageName}")
                                    },
                                )
                            } catch (_: ActivityNotFoundException) {
                                Toast.makeText(context, context.getString(R.string.toast_alarm_settings_error), Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                )
            }

            // 4. Auto-start (manufacturer-specific)
            if (uiState.showAutoStartRow) {
                SettingsDivider()
                PermissionItemRow(
                    icon = Icons.Rounded.PhonelinkSetup,
                    title = stringResource(R.string.setup_autostart),
                    description = stringResource(R.string.setup_autostart_sub, uiState.manufacturerName),
                    isGranted = uiState.autoStartAcknowledged,
                    actionLabel = stringResource(R.string.setup_btn_configure),
                    grantedLabel = stringResource(R.string.setup_btn_reviewed),
                    onAction = {
                        val intent = ManufacturerUtils.getAutoStartIntent(context)
                        if (intent != null) {
                            try {
                                context.startActivity(intent)
                                viewModel.markAutoStartAcknowledged()
                            } catch (_: ActivityNotFoundException) {
                                openFallbackBatterySettings(context)
                                viewModel.markAutoStartAcknowledged()
                            }
                        } else {
                            openFallbackBatterySettings(context)
                            viewModel.markAutoStartAcknowledged()
                        }
                    },
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = stringResource(R.string.setup_footer),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
            modifier = Modifier.padding(horizontal = 4.dp),
        )

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun PermissionItemRow(
    icon: ImageVector,
    title: String,
    description: String,
    isGranted: Boolean,
    actionLabel: String,
    grantedLabel: String = stringResource(R.string.setup_btn_granted),
    onAction: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .let { if (!isGranted) it.clickable(onClick = onAction) else it }
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = stringResource(R.string.cd_permission_icon),
            modifier = Modifier
                .padding(top = 2.dp)
                .size(24.dp),
            tint = if (isGranted) {
                MaterialTheme.colorScheme.primary
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            },
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(modifier = Modifier.width(8.dp))
        StatusBadge(
            isGranted = isGranted,
            actionLabel = actionLabel,
            grantedLabel = grantedLabel,
            onAction = onAction,
        )
    }
}

@Composable
private fun StatusBadge(
    isGranted: Boolean,
    actionLabel: String,
    grantedLabel: String,
    onAction: () -> Unit,
) {
    val bgColor by animateColorAsState(
        targetValue = if (isGranted) {
            MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
        } else {
            MaterialTheme.colorScheme.error.copy(alpha = 0.12f)
        },
        animationSpec = spring(),
        label = "badgeBg",
    )
    val textColor by animateColorAsState(
        targetValue = if (isGranted) {
            MaterialTheme.colorScheme.primary
        } else {
            MaterialTheme.colorScheme.error
        },
        animationSpec = spring(),
        label = "badgeText",
    )

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(bgColor)
            .let { if (!isGranted) it.clickable(onClick = onAction) else it }
            .padding(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            if (isGranted) {
                Icon(
                    imageVector = Icons.Rounded.CheckCircle,
                    contentDescription = stringResource(R.string.cd_granted),
                    modifier = Modifier.size(14.dp),
                    tint = textColor,
                )
            }
            Text(
                text = if (isGranted) grantedLabel else actionLabel,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = textColor,
            )
        }
    }
}

private fun openAppNotificationSettings(context: Context) {
    try {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        Toast.makeText(context, context.getString(R.string.toast_notification_settings_error), Toast.LENGTH_SHORT).show()
    }
}

private fun openFallbackBatterySettings(context: Context) {
    try {
        context.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
    } catch (_: ActivityNotFoundException) {
        try {
            context.startActivity(Intent(Settings.ACTION_SETTINGS))
        } catch (_: ActivityNotFoundException) {
            // Nothing we can do
        }
    }
}
