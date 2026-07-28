package dev.creapolis.pepinillo.feature.soundscape

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Stop
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.soundscape.Soundscape
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SoundscapePickerSheet(
    currentSoundscape: Soundscape?,
    onSoundscapeSelected: (Soundscape?) -> Unit,
    onDismiss: () -> Unit,
    onNavigateToPaywall: () -> Unit,
    viewModel: SoundscapePickerViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // Sync the current selection from the parent
    DisposableEffect(currentSoundscape) {
        viewModel.updateSelected(currentSoundscape)
        onDispose { }
    }

    // Stop preview when sheet is dismissed
    DisposableEffect(Unit) {
        onDispose {
            viewModel.stopPreview()
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier.padding(bottom = 24.dp),
        ) {
            // Title
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.soundscape_title),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Rounded.Close,
                        contentDescription = stringResource(R.string.btn_cancel),
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            LazyColumn(
                contentPadding = PaddingValues(horizontal = 24.dp),
            ) {
                // "None" option
                item {
                    SoundscapeRow(
                        emoji = "\uD83D\uDD07",
                        displayName = stringResource(R.string.soundscape_none),
                        isSelected = uiState.selectedSoundscape == null,
                        isPreviewing = false,
                        isLocked = false,
                        onSelect = {
                            onSoundscapeSelected(null)
                        },
                        onPreview = null,
                    )
                }

                // Free Sounds section
                item {
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = stringResource(R.string.soundscape_section_free),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 8.dp),
                    )
                }

                items(Soundscape.free) { soundscape ->
                    SoundscapeRow(
                        emoji = soundscape.emoji,
                        displayName = stringResource(soundscape.displayNameRes),
                        isSelected = uiState.selectedSoundscape == soundscape,
                        isPreviewing = uiState.previewingSoundscape == soundscape,
                        isLocked = false,
                        onSelect = {
                            onSoundscapeSelected(soundscape)
                        },
                        onPreview = { viewModel.togglePreview(soundscape) },
                    )
                }

                // Pro Sounds section
                item {
                    Spacer(modifier = Modifier.height(12.dp))
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                    Text(
                        text = stringResource(R.string.soundscape_section_pro),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 8.dp),
                    )
                }

                items(Soundscape.pro) { soundscape ->
                    val isLocked = !viewModel.canUseSoundscape(soundscape)
                    SoundscapeRow(
                        emoji = soundscape.emoji,
                        displayName = stringResource(soundscape.displayNameRes),
                        isSelected = uiState.selectedSoundscape == soundscape,
                        isPreviewing = uiState.previewingSoundscape == soundscape,
                        isLocked = isLocked,
                        onSelect = {
                            if (isLocked) {
                                onNavigateToPaywall()
                            } else {
                                onSoundscapeSelected(soundscape)
                            }
                        },
                        onPreview = { viewModel.togglePreview(soundscape) },
                    )
                }

                item {
                    Spacer(modifier = Modifier.height(16.dp))
                }
            }
        }
    }
}

@Composable
private fun SoundscapeRow(
    emoji: String,
    displayName: String,
    isSelected: Boolean,
    isPreviewing: Boolean,
    isLocked: Boolean,
    onSelect: () -> Unit,
    onPreview: (() -> Unit)?,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(PepinilloShapeTokens.button)
            .clickable(onClick = onSelect)
            .padding(horizontal = 8.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Emoji
        Text(
            text = emoji,
            style = MaterialTheme.typography.titleLarge,
            modifier = Modifier.size(32.dp),
        )

        Spacer(modifier = Modifier.width(16.dp))

        // Name
        Text(
            text = displayName,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )

        // Preview button
        if (onPreview != null) {
            IconButton(
                onClick = onPreview,
                modifier = Modifier.size(36.dp),
            ) {
                Icon(
                    imageVector = if (isPreviewing) Icons.Rounded.Stop else Icons.Rounded.PlayArrow,
                    contentDescription = if (isPreviewing) {
                        stringResource(R.string.soundscape_stop_preview)
                    } else {
                        stringResource(R.string.soundscape_preview)
                    },
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp),
                )
            }
        }

        // Lock icon or checkmark
        if (isLocked) {
            Icon(
                imageVector = Icons.Rounded.Lock,
                contentDescription = stringResource(R.string.soundscape_requires_pro),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(20.dp),
            )
        } else if (isSelected) {
            Icon(
                imageVector = Icons.Rounded.Check,
                contentDescription = stringResource(R.string.cd_completed),
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}
