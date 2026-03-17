package dev.creapolis.pepinillo.feature.focus.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.feature.focus.FocusMode
import dev.creapolis.pepinillo.ui.theme.colorScheme

@Composable
fun ModeChip(
    mode: FocusMode,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val modeColors = mode.colorScheme()

    val containerColor by animateColorAsState(
        targetValue = if (isSelected) modeColors.accentColor else MaterialTheme.colorScheme.surfaceVariant,
        animationSpec = spring(),
        label = "modeChipContainer",
    )
    val iconColor by animateColorAsState(
        targetValue = if (isSelected) modeColors.onAccentColor else MaterialTheme.colorScheme.onSurfaceVariant,
        animationSpec = spring(),
        label = "modeChipIcon",
    )
    val labelColor by animateColorAsState(
        targetValue = if (isSelected) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
        animationSpec = spring(),
        label = "modeChipLabel",
    )

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(containerColor)
                .clickable(role = Role.Button, onClick = onClick),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = mode.icon,
                contentDescription = mode.label,
                modifier = Modifier.size(24.dp),
                tint = iconColor,
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = mode.label,
            style = MaterialTheme.typography.labelMedium,
            color = labelColor,
        )
    }
}
