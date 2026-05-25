package dev.creapolis.pepinillo.feature.tasks.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.AccessTime
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.ui.theme.EnergyColors
import dev.creapolis.pepinillo.ui.theme.priorityColor
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

    // Use null to mean "no priority set" — Color.Transparent would render invisible
    val priorityColor = task.priority.priorityColor().takeIf { it != Color.Transparent }

    val isDueToday = task.dueDate != null && isDueTodayMs(task.dueDate)

    val isOverdue = task.dueDate != null && isBeforeTodayMs(task.dueDate)

    val checkboxBorderColor = when {
        task.isCompleted -> MaterialTheme.colorScheme.primary
        priorityColor != null -> priorityColor
        else -> MaterialTheme.colorScheme.outline
    }

    val rowBackground by animateColorAsState(
        targetValue = when {
            task.isCompleted -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)
            isOverdue -> MaterialTheme.colorScheme.error.copy(alpha = 0.06f)
            isDueToday -> Color(0xFFFF8A00).copy(alpha = 0.06f)
            else -> Color.Transparent
        },
        animationSpec = tween(500),
        label = "taskRowBg",
    )

    val rowBorderColor by animateColorAsState(
        targetValue = when {
            task.isCompleted -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f)
            isOverdue -> MaterialTheme.colorScheme.error.copy(alpha = 0.35f)
            isDueToday -> Color(0xFFFF8A00).copy(alpha = 0.35f)
            else -> MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f)
        },
        animationSpec = tween(500),
        label = "taskRowBorder",
    )

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Max)
            .shadow(elevation = 2.dp, shape = RoundedCornerShape(16.dp))
            .border(
                width = 1.dp,
                color = rowBorderColor,
                shape = RoundedCornerShape(16.dp)
            )
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
            .background(rowBackground)
            .clickable(onClick = onClick),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Priority bar (left side indicator, glued to the left edge)
        if (priorityColor != null && !task.isCompleted) {
            Box(
                modifier = Modifier
                    .fillMaxHeight()
                    .width(5.dp)
                    .background(priorityColor)
            )
        }

        Row(
            modifier = Modifier
                .weight(1f)
                .fillMaxHeight()
                .padding(
                    start = if (priorityColor != null && !task.isCompleted) 12.dp else 16.dp,
                    end = 16.dp,
                    top = 12.dp,
                    bottom = 12.dp
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
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
                                    color = checkboxBorderColor,
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
}

@Composable
private fun MetadataRow(
    task: Task,
    subtaskProgress: Pair<Int, Int>?,
) {
    val dateFormatter = remember {
        SimpleDateFormat("MMM d", Locale.getDefault()).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }
    }
    val metadataItems = mutableListOf<@Composable () -> Unit>()

    // Due date
    task.dueDate?.let { dueDate ->
        val isToday = isDueTodayMs(dueDate)
        val isOverdue = isBeforeTodayMs(dueDate)
        val color = when {
            isOverdue -> MaterialTheme.colorScheme.error
            isToday -> Color(0xFFFF8A00)
            else -> MaterialTheme.colorScheme.onSurfaceVariant
        }
        metadataItems.add {
            MetadataBadge(color = color) {
                Icon(Icons.Rounded.CalendarMonth, contentDescription = "Due date", modifier = Modifier.size(14.dp), tint = color)
                Text(dateFormatter.format(Date(dueDate)), style = MaterialTheme.typography.bodySmall, color = color)
            }
        }
    }

    // Today indicator (only if no due date to avoid clutter)
    if (task.scheduledForToday && task.dueDate == null) {
        metadataItems.add {
            val color = Color(0xFFFF8A00)
            MetadataBadge(color = color) {
                Icon(Icons.Rounded.Today, contentDescription = "Scheduled for today", modifier = Modifier.size(14.dp), tint = color)
                Text(stringResource(R.string.filter_today), style = MaterialTheme.typography.bodySmall, color = color)
            }
        }
    }

    // Energy level (icon + label for accessibility — distinguishable without color)
    metadataItems.add {
        val color = energyColor(task.energyLevel)
        MetadataBadge(color = color) {
            EnergyIcon(energyLevel = task.energyLevel)
            Text(task.energyLevel.label, style = MaterialTheme.typography.bodySmall, color = color)
        }
    }

    // Pomodoro count
    if (task.estimatedPomodoros > 0) {
        metadataItems.add {
            val color = MaterialTheme.colorScheme.secondary
            MetadataBadge(color = color) {
                Icon(Icons.Rounded.AccessTime, contentDescription = "Pomodoros", modifier = Modifier.size(14.dp), tint = color)
                Text(
                    "${task.completedPomodoros}/${task.estimatedPomodoros}",
                    style = MaterialTheme.typography.bodySmall,
                    color = color,
                )
            }
        }
    }

    // Subtask progress
    subtaskProgress?.let { (completed, total) ->
        if (total > 0) {
            metadataItems.add {
                val color = MaterialTheme.colorScheme.tertiary
                MetadataBadge(color = color) {
                    Icon(Icons.Rounded.Checklist, contentDescription = "Subtasks", modifier = Modifier.size(14.dp), tint = color)
                    Text("$completed/$total", style = MaterialTheme.typography.bodySmall, color = color)
                }
            }
        }
    }

    // Recurrence
    task.recurrenceRule?.let {
        val option = RecurrenceOption.fromRrule(it)
        if (option != RecurrenceOption.None) {
            metadataItems.add {
                val color = MaterialTheme.colorScheme.primary
                MetadataBadge(color = color) {
                    Icon(Icons.Rounded.Repeat, contentDescription = "Recurring", modifier = Modifier.size(14.dp), tint = color)
                    Text(option.label, style = MaterialTheme.typography.bodySmall, color = color)
                }
            }
        }
    }

    if (metadataItems.isNotEmpty()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            metadataItems.forEach { item -> item() }
        }
    }
}

@Composable
private fun MetadataBadge(
    color: Color,
    content: @Composable () -> Unit,
) {
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(color.copy(alpha = 0.10f))
            .padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        content()
    }
}

@Composable
private fun EnergyIcon(
    energyLevel: EnergyLevel,
    modifier: Modifier = Modifier,
) {
    val color = energyColor(energyLevel)
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


@Composable
private fun energyColor(energyLevel: EnergyLevel): Color = when (energyLevel) {
    EnergyLevel.Deep -> EnergyColors.deep
    EnergyLevel.Regular -> EnergyColors.regular
    EnergyLevel.Light -> EnergyColors.light
}

private fun getNormalizedLocalDate(): java.util.Calendar {
    val local = java.util.Calendar.getInstance()
    return java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(java.util.Calendar.YEAR, local.get(java.util.Calendar.YEAR))
        set(java.util.Calendar.MONTH, local.get(java.util.Calendar.MONTH))
        set(java.util.Calendar.DAY_OF_MONTH, local.get(java.util.Calendar.DAY_OF_MONTH))
    }
}

private fun getNormalizedDueDate(millis: Long): java.util.Calendar {
    val due = java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply { timeInMillis = millis }
    return java.util.Calendar.getInstance(java.util.TimeZone.getTimeZone("UTC")).apply {
        clear()
        set(java.util.Calendar.YEAR, due.get(java.util.Calendar.YEAR))
        set(java.util.Calendar.MONTH, due.get(java.util.Calendar.MONTH))
        set(java.util.Calendar.DAY_OF_MONTH, due.get(java.util.Calendar.DAY_OF_MONTH))
    }
}

private fun isDueTodayMs(millis: Long): Boolean {
    val dueNorm = getNormalizedDueDate(millis)
    val todayNorm = getNormalizedLocalDate()
    return dueNorm == todayNorm
}

private fun isBeforeTodayMs(millis: Long): Boolean {
    val dueNorm = getNormalizedDueDate(millis)
    val todayNorm = getNormalizedLocalDate()
    return dueNorm.before(todayNorm)
}
