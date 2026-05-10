package dev.creapolis.pepinillo.feature.more

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.automirrored.rounded.HelpOutline
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.CloudSync
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.ExitToApp
import androidx.compose.material.icons.rounded.FileDownload
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Login
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.PersonAdd
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R

@Composable
fun MoreScreen(
    modifier: Modifier = Modifier,
    viewModel: MoreViewModel = hiltViewModel(),
    onProfileClick: () -> Unit = {},
    onSignInClick: () -> Unit = {},
    onCreateAccountClick: () -> Unit = {},
    onSettingsClick: () -> Unit = {},
    onExportClick: () -> Unit = {},
    onHelpSupportClick: () -> Unit = {},
    onAboutClick: () -> Unit = {},
    onNavigateToPaywall: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(16.dp))

        // ── 1. HEADER ──
        Text(
            text = stringResource(R.string.nav_more),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )

        Spacer(modifier = Modifier.height(28.dp))

        // ── 2. ACCOUNT SECTION ──
        SectionTitle(title = "Account")
        Spacer(modifier = Modifier.height(12.dp))

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
        ) {
            Column(modifier = Modifier.padding(8.dp)) {
                if (uiState.isLoggedIn) {
                    ActionCard(
                        title = stringResource(R.string.cd_profile),
                        subtitle = uiState.user?.name ?: uiState.user?.email ?: "",
                        icon = Icons.Rounded.Person,
                        onClick = onProfileClick,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    ActionCard(
                        title = "Sign Out",
                        subtitle = uiState.user?.email ?: "",
                        icon = Icons.Rounded.ExitToApp,
                        onClick = { viewModel.logout() },
                    )
                } else {
                    ActionCard(
                        title = stringResource(R.string.auth_btn_signin),
                        subtitle = "Sync your data across devices",
                        icon = Icons.Rounded.Login,
                        onClick = onSignInClick,
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    ActionCard(
                        title = stringResource(R.string.auth_btn_register),
                        subtitle = "Join the community",
                        icon = Icons.Rounded.PersonAdd,
                        onClick = onCreateAccountClick,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── 3. SETTINGS & SYNC ──
        SectionTitle(title = "Configuration")
        Spacer(modifier = Modifier.height(12.dp))

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
        ) {
            Column(modifier = Modifier.padding(8.dp)) {
                ActionCard(
                    title = "App Settings",
                    subtitle = "Timer, sound, and appearance",
                    icon = Icons.Rounded.Settings,
                    onClick = onSettingsClick,
                )
                Spacer(modifier = Modifier.height(4.dp))
                ActionCard(
                    title = "Cloud Sychronization",
                    subtitle = if (uiState.isEverywhere) "Active and securing your data" else "Requires Everywhere/AI+",
                    icon = Icons.Rounded.CloudSync,
                    onClick = { if (!uiState.isEverywhere) onNavigateToPaywall() },
                )
            }
        }

        Spacer(modifier = Modifier.height(28.dp))

        // ── 4. DATA & SUPPORT ──
        SectionTitle(title = "Resources")
        Spacer(modifier = Modifier.height(12.dp))

        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
        ) {
            Column(modifier = Modifier.padding(8.dp)) {
                ActionCard(
                    title = "Export Data",
                    subtitle = "Download your focus history",
                    icon = Icons.Rounded.FileDownload,
                    onClick = onExportClick,
                )
                Spacer(modifier = Modifier.height(4.dp))
                ActionCard(
                    title = "Help & Support",
                    subtitle = "Feedback and documentation",
                    icon = Icons.AutoMirrored.Rounded.HelpOutline,
                    onClick = onHelpSupportClick,
                )
                Spacer(modifier = Modifier.height(4.dp))
                ActionCard(
                    title = "About",
                    subtitle = "Version and legal info",
                    icon = Icons.Rounded.Info,
                    onClick = onAboutClick,
                )
            }
        }

        Spacer(modifier = Modifier.height(40.dp))

        // ── 5. PRO BADGE (if not pro) ──
        if (!uiState.isPro) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onNavigateToPaywall() },
                shape = RoundedCornerShape(20.dp),
                color = MaterialTheme.colorScheme.primaryContainer,
            ) {
                Row(
                    modifier = Modifier.padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = Icons.Rounded.Star,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                    }
                    Spacer(modifier = Modifier.width(16.dp))
                    Column {
                        Text(
                            text = "Get Pepinillo+",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        Text(
                            text = "Unlock all features and cloud sync",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f),
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(40.dp))
        }

        // ── 6. FOOTER ──
        Text(
            text = "Made with \u2764 by Creapolis",
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
        )
        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 8.dp),
    )
}

@Composable
private fun ActionCard(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(12.dp))
                .background(MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.4f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = MaterialTheme.colorScheme.primary,
            )
        }
        Spacer(modifier = Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Icon(
            imageVector = Icons.Rounded.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.size(20.dp),
        )
    }
}
