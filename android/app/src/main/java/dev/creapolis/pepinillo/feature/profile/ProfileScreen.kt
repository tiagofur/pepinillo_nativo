package dev.creapolis.pepinillo.feature.profile

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
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ExitToApp
import androidx.compose.material.icons.rounded.Backup
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Edit
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.TaskAlt
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import coil.compose.AsyncImage
import dev.creapolis.pepinillo.R
import androidx.compose.ui.res.stringResource

@Composable
fun ProfileScreen(
    modifier: Modifier = Modifier,
    viewModel: ProfileViewModel = hiltViewModel(),
    onBackClick: () -> Unit = {},
    onSignInClick: () -> Unit = {},
    onSignOutClick: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()
    var showDeleteConfirmation by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(8.dp))

        // ── TOP BAR with back arrow ──
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onBackClick) {
                Icon(
                    imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                    contentDescription = "Back",
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // ── HEADER ──
        Text(
            text = "Profile",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = "Your productivity journey",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(modifier = Modifier.height(28.dp))

        if (uiState.isLoggedIn && uiState.isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 32.dp),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }
        } else if (uiState.isLoggedIn) {
            ProfileCard {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.primaryContainer),
                        contentAlignment = Alignment.Center,
                    ) {
                        val imageUrl = uiState.user?.imageUrl
                        if (imageUrl != null) {
                            AsyncImage(
                                model = imageUrl,
                                contentDescription = "Profile photo",
                                modifier = Modifier.fillMaxSize(),
                                contentScale = ContentScale.Crop,
                            )
                        } else {
                            Icon(
                                imageVector = Icons.Rounded.Person,
                                contentDescription = null,
                                modifier = Modifier.size(36.dp),
                                tint = MaterialTheme.colorScheme.onPrimaryContainer,
                            )
                        }
                    }
                    Spacer(modifier = Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Text(
                                text = uiState.user?.name ?: "Guest User",
                                style = MaterialTheme.typography.titleLarge,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface,
                            )
                            val tier = uiState.user?.subscriptionTier
                            if (!tier.isNullOrEmpty() && tier != "free") {
                                Surface(
                                    color = MaterialTheme.colorScheme.primary,
                                    shape = RoundedCornerShape(6.dp),
                                ) {
                                    Text(
                                        text = "PRO",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onPrimary,
                                        modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                                    )
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = uiState.user?.email ?: "",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    IconButton(onClick = { viewModel.showEditSheet() }) {
                        Icon(
                            imageVector = Icons.Rounded.Edit,
                            contentDescription = "Edit profile",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        } else {
            GuestSignInCard(onSignInClick = onSignInClick)
        }

        Spacer(modifier = Modifier.height(24.dp))

        // ── LIFETIME STATS ──
        Text(
            text = "Lifetime Stats",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 4.dp),
        )
        Spacer(modifier = Modifier.height(12.dp))

        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            StatMiniCard(
                icon = Icons.Rounded.Timer,
                value = "${uiState.totalFocusTimeMinutes / 60}h",
                label = "Focus time",
                modifier = Modifier.weight(1f),
            )
            StatMiniCard(
                icon = Icons.Rounded.TaskAlt,
                value = "${uiState.totalSessions}",
                label = "Sessions",
                modifier = Modifier.weight(1f),
            )
            StatMiniCard(
                icon = Icons.Rounded.LocalFireDepartment,
                value = "${uiState.bestStreak}",
                label = "Best streak",
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(modifier = Modifier.height(24.dp))

        // ── ACHIEVEMENTS ──
        Text(
            text = "Achievements",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 4.dp),
        )
        Spacer(modifier = Modifier.height(12.dp))

        ProfileCard {
            uiState.achievements.forEachIndexed { index, achievement ->
                if (index > 0) ProfileDivider()
                AchievementRow(
                    icon = achievementIcon(achievement.icon),
                    title = achievement.title,
                    subtitle = achievement.subtitle,
                    isUnlocked = achievement.isUnlocked,
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // ── ACCOUNT ACTIONS ──
        Text(
            text = "Account",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 4.dp),
        )
        Spacer(modifier = Modifier.height(12.dp))

        if (uiState.isLoggedIn) {
            ProfileCard {
                ActionRow(
                    icon = Icons.Rounded.Backup,
                    label = "Backup & Sync",
                    subtitle = "Cloud sync is active",
                    onClick = {},
                )
                ProfileDivider()
                ActionRow(
                    icon = Icons.AutoMirrored.Rounded.ExitToApp,
                    label = "Sign Out",
                    subtitle = uiState.user?.email ?: "",
                    onClick = {
                        viewModel.logout()
                        onSignOutClick()
                    },
                )
                ProfileDivider()
                ActionRow(
                    icon = Icons.Rounded.Person,
                    label = "Delete Account",
                    subtitle = "Irreversible data removal",
                    isDestructive = true,
                    onClick = { showDeleteConfirmation = true },
                )
            }
        }

        Spacer(modifier = Modifier.height(32.dp))

        // Footer
        Text(
            text = "Pepinillo v1.0.0",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(24.dp))
    }

    if (uiState.isEditSheetVisible) {
        val context = LocalContext.current
        EditProfileSheet(
            uiState = uiState,
            onDismiss = { viewModel.hideEditSheet() },
            onSave = { name -> viewModel.saveProfile(name) },
            onPhotoSelected = { uri -> viewModel.uploadPhoto(context, uri) },
        )
    }

    if (showDeleteConfirmation) {
        androidx.compose.material3.AlertDialog(
            onDismissRequest = { showDeleteConfirmation = false },
            title = { Text(stringResource(R.string.delete_account_title)) },
            text = { Text(stringResource(R.string.delete_account_desc)) },
            confirmButton = {
                androidx.compose.material3.TextButton(
                    onClick = {
                        showDeleteConfirmation = false
                        viewModel.deleteAccount { onSignOutClick() }
                    },
                    colors = androidx.compose.material3.ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                ) {
                    Text(stringResource(R.string.delete_account_btn_forever))
                }
            },
            dismissButton = {
                androidx.compose.material3.TextButton(onClick = { showDeleteConfirmation = false }) {
                    Text(stringResource(R.string.btn_cancel))
                }
            },
        )
    }
}

// ── Reusable components ──

@Composable
private fun ProfileCard(content: @Composable () -> Unit) {
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
private fun ProfileDivider() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)),
    )
}

@Composable
private fun StatMiniCard(
    icon: ImageVector,
    value: String,
    label: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(24.dp))
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant,
                shape = RoundedCornerShape(24.dp),
            )
            .padding(vertical = 20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(24.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Spacer(modifier = Modifier.height(10.dp))
        Text(
            text = value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(modifier = Modifier.height(2.dp))
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun AchievementRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    isUnlocked: Boolean,
) {
    val alpha = if (isUnlocked) 1f else 0.35f

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(
                    if (isUnlocked) {
                        MaterialTheme.colorScheme.tertiaryContainer
                    } else {
                        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                    },
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(20.dp),
                tint = if (isUnlocked) {
                    MaterialTheme.colorScheme.onTertiaryContainer
                } else {
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                },
            )
        }
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (isUnlocked) FontWeight.Medium else FontWeight.Normal,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = alpha),
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = alpha),
            )
        }
        if (isUnlocked) {
            Text(
                text = "\u2713",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.tertiary,
            )
        }
    }
}

@Composable
private fun ActionRow(
    icon: ImageVector,
    label: String,
    subtitle: String,
    isDestructive: Boolean = false,
    onClick: () -> Unit = {},
) {
    val labelColor = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(22.dp),
            tint = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                color = labelColor,
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = if (isDestructive) MaterialTheme.colorScheme.error.copy(alpha = 0.7f) else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Icon(
            imageVector = Icons.Rounded.ChevronRight,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = if (isDestructive) MaterialTheme.colorScheme.error.copy(alpha = 0.5f) else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
        )
    }
}

@Composable
private fun GuestSignInCard(onSignInClick: () -> Unit) {
    ProfileCard {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Rounded.Person,
                    contentDescription = null,
                    modifier = Modifier.size(28.dp),
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Welcome to Pepinillo",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Sign in to sync your data across devices",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(modifier = Modifier.height(16.dp))
            Button(
                onClick = onSignInClick,
                shape = RoundedCornerShape(12.dp),
                contentPadding = ButtonDefaults.ButtonWithIconContentPadding,
            ) {
                Text("Sign In", style = MaterialTheme.typography.labelLarge)
            }
        }
    }
}

private fun achievementIcon(name: String): ImageVector = when (name) {
    "EmojiEvents" -> Icons.Rounded.EmojiEvents
    "LocalFireDepartment" -> Icons.Rounded.LocalFireDepartment
    "Star" -> Icons.Rounded.Star
    "Timer" -> Icons.Rounded.Timer
    else -> Icons.Rounded.EmojiEvents
}
