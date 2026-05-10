package dev.creapolis.pepinillo.feature.tasks.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.filled.BatteryFull
import androidx.compose.material.icons.filled.Battery3Bar
import androidx.compose.material.icons.filled.Battery1Bar
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Checklist
import androidx.compose.material.icons.rounded.DragHandle
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.Today
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.ui.theme.EnergyColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun TaskItem(
    task: Task,
    onToggleCompletion: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    subtaskProgress: Pair<Int, Int>? = null,
    showDragHandle: Boolean = false,
    dragHandleModifier: Modifier = Modifier,
) {
    val haptics = LocalHapticFeedback.current
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.8f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ),
        label = "checkboxScale"
    )

    val checkboxColor by animateColorAsState(
        targetValue = if (task.isCompleted) {
            MaterialTheme.colorScheme.primary
        } else {
            Color.Transparent
        },
        animationSpec = spring(),
        label = "checkboxBg",
    )

    val priorityColor = when (task.priority) {
        TaskPriority.High -> MaterialTheme.colorScheme.error
        TaskPriority.Medium -> MaterialTheme.colorScheme.tertiary
        TaskPriority.Low -> MaterialTheme.colorScheme.secondary
        TaskPriority.None -> null
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(start = 8.dp, end = 16.dp, top = 6.dp, bottom = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Priority bar (left side indicator)
        if (priorityColor != null && !task.isCompleted) {
            Box(
                modifier = Modifier
                    .size(width = 4.dp, height = 40.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(priorityColor),
            )
            Spacer(modifier = Modifier.width(12.dp))
        }

        // Circular checkbox — visual 24dp, touch target 48dp
        Box(
            modifier = Modifier
                .size(48.dp)
                .clickable(
                    interactionSource = interactionSource,
                    indication = null,
                    onClick = {
                        haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                        onToggleCompletion()
                    }
                )
                .semantics {
                    role = Role.Checkbox
                    contentDescription = if (task.isCompleted) "Mark ${task.title} incomplete" else "Mark ${task.title} complete"
                },
            contentAlignment = Alignment.Center,
        ) {
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .scale(scale)
                    .clip(CircleShape)
                    .background(checkboxColor)
                    .then(
                        if (!task.isCompleted) {
                            Modifier.border(
                                width = 2.dp,
                                color = MaterialTheme.colorScheme.outline,
                                shape = CircleShape,
                            )
                        } else {
                            Modifier
                        },
                    ),
                contentAlignment = Alignment.Center,
            ) {
                if (task.isCompleted) {
                    Icon(
                        imageVector = Icons.Rounded.Check,
                        contentDescription = "Completed",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onPrimary,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.width(4.dp))

        // Task content
        Column(modifier = Modifier.weight(1f)) {
            val textColor by animateColorAsState(
                targetValue = if (task.isCompleted) {
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                } else {
                    MaterialTheme.colorScheme.onSurface
                },
                animationSpec = tween(500),
                label = "textColor"
            )

            Text(
                text = task.title,
                style = MaterialTheme.typography.bodyLarge,
                color = textColor,
                textDecoration = if (task.isCompleted) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )

            // Notes snippet (first line)
            if (!task.isCompleted && !task.notes.isNullOrBlank()) {
                Text(
                    text = task.notes.lineSequence().first(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            if (!task.isCompleted) {
                Spacer(modifier = Modifier.size(4.dp))
                MetadataRow(task = task, subtaskProgress = subtaskProgress)
            }
        }

        // Drag handle (visible only when sort is Custom)
        if (showDragHandle) {
            Spacer(modifier = Modifier.width(4.dp))
            Icon(
                imageVector = Icons.Rounded.DragHandle,
                contentDescription = "Reorder task",
                modifier = dragHandleModifier
                    .size(40.dp)
                    .padding(8.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
            )
        }
    }
}

@Composable
private fun MetadataRow(
    task: Task,
    subtaskProgress: Pair<Int, Int>?,
) {
    val dateFormatter = remember { SimpleDateFormat("MMM d", Locale.getDefault()) }
    val metadataItems = mutableListOf<@Composable () -> Unit>()

    // Due date
    task.dueDate?.let { dueDate ->
        val isOverdue = dueDate < System.currentTimeMillis()
        val color = if (isOverdue) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant
        metadataItems.add {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                Icon(Icons.Rounded.CalendarMonth, contentDescription = "Due date", modifier = Modifier.size(14.dp), tint = color)
                Text(dateFormatter.format(Date(dueDate)), style = MaterialTheme.typography.bodySmall, color = color)
            }
        }
    }

    // Today indicator (only if no due date to avoid clutter)
    if (task.scheduledForToday && task.dueDate == null) {
        metadataItems.add {
            Icon(Icons.Rounded.Today, contentDescription = "Scheduled for today", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.primary)
        }
    }

    // Energy level (icon + label for accessibility — distinguishable without color)
    metadataItems.add {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            EnergyIcon(energyLevel = task.energyLevel)
            Text(task.energyLevel.label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    // Pomodoro count
    if (task.estimatedPomodoros > 0) {
        metadataItems.add {
            Text(
                "${task.completedPomodoros}/${task.estimatedPomodoros}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }

    // Subtask progress
    subtaskProgress?.let { (completed, total) ->
        if (total > 0) {
            metadataItems.add {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    Icon(Icons.Rounded.Checklist, contentDescription = "Subtasks", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("$completed/$total", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }

    // Recurrence
    task.recurrenceRule?.let {
        val option = RecurrenceOption.fromRrule(it)
        if (option != RecurrenceOption.None) {
            metadataItems.add {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
                    Icon(Icons.Rounded.Repeat, contentDescription = "Recurring", modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(option.label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }

    if (metadataItems.isNotEmpty()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            metadataItems.forEachIndexed { index, item ->
                if (index > 0) {
                    Text("\u00B7", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                item()
            }
        }
    }
}

@Composable
private fun EnergyIcon(
    energyLevel: EnergyLevel,
    modifier: Modifier = Modifier,
) {
    val color = when (energyLevel) {
        EnergyLevel.Deep -> EnergyColors.deep
        EnergyLevel.Regular -> EnergyColors.regular
        EnergyLevel.Light -> EnergyColors.light
    }
    val icon = when (energyLevel) {
        EnergyLevel.Deep -> Icons.Filled.BatteryFull
        EnergyLevel.Regular -> Icons.Filled.Battery3Bar
        EnergyLevel.Light -> Icons.Filled.Battery1Bar
    }
    Icon(
        imageVector = icon,
        contentDescription = energyLevel.label,
        modifier = modifier.size(14.dp),
        tint = color,
    )
}
