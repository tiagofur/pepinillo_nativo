package dev.creapolis.pepinillo.feature.tasks.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.ui.theme.EnergyColors

@Composable
fun AddTaskDialog(
    onDismiss: () -> Unit,
    onConfirm: (title: String, energyLevel: EnergyLevel, estimatedPomodoros: Int) -> Unit,
) {
    var title by remember { mutableStateOf("") }
    var selectedEnergy by remember { mutableStateOf(EnergyLevel.Regular) }
    var pomodoros by remember { mutableIntStateOf(1) }

    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 6.dp,
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
            ) {
                Text(
                    text = "New Task",
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                )

                Spacer(modifier = Modifier.height(20.dp))

                // Title field
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Task name") },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(16.dp),
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                    ),
                    singleLine = true,
                )

                Spacer(modifier = Modifier.height(20.dp))

                // Energy level selector
                Text(
                    text = "Energy Level",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    EnergyLevel.entries.forEach { energy ->
                        EnergyChip(
                            energyLevel = energy,
                            isSelected = selectedEnergy == energy,
                            onClick = { selectedEnergy = energy },
                        )
                    }
                }

                Spacer(modifier = Modifier.height(20.dp))

                // Pomodoro count
                Text(
                    text = "Estimated Pomodoros",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    IconButton(
                        onClick = { if (pomodoros > 1) pomodoros-- },
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Icon(
                            Icons.Rounded.Remove,
                            contentDescription = "Decrease",
                            modifier = Modifier.size(18.dp),
                        )
                    }
                    Text(
                        text = "$pomodoros",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    IconButton(
                        onClick = { if (pomodoros < 12) pomodoros++ },
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Icon(
                            Icons.Rounded.Add,
                            contentDescription = "Increase",
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Actions
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel")
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = { onConfirm(title, selectedEnergy, pomodoros) },
                        enabled = title.isNotBlank(),
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Text("Add Task")
                    }
                }
            }
        }
    }
}

@Composable
private fun EnergyChip(
    energyLevel: EnergyLevel,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val dotColor = when (energyLevel) {
        EnergyLevel.Deep -> EnergyColors.deep
        EnergyLevel.Regular -> EnergyColors.regular
        EnergyLevel.Light -> EnergyColors.light
    }

    val bgColor by animateColorAsState(
        targetValue = if (isSelected) {
            dotColor.copy(alpha = 0.15f)
        } else {
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        },
        animationSpec = spring(),
        label = "energyChipBg",
    )
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) dotColor else androidx.compose.ui.graphics.Color.Transparent,
        animationSpec = spring(),
        label = "energyChipBorder",
    )

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bgColor)
            .then(
                if (isSelected) {
                    Modifier.background(bgColor)
                } else {
                    Modifier
                },
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(dotColor),
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = energyLevel.label,
            style = MaterialTheme.typography.labelMedium,
            color = if (isSelected) {
                MaterialTheme.colorScheme.onSurface
            } else {
                MaterialTheme.colorScheme.onSurfaceVariant
            },
        )
    }
}
