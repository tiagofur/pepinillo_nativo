package dev.creapolis.pepinillo.feature.tasks.detail

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Event
import androidx.compose.material.icons.rounded.ExpandMore
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ripple
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.domain.tasks.DueDateEncoding
import dev.creapolis.pepinillo.domain.tasks.TaskPlanning
import dev.creapolis.pepinillo.feature.tasks.model.Task
import dev.creapolis.pepinillo.ui.theme.DomainColors
import java.text.SimpleDateFormat
import java.util.Locale

/** Value text for the «Planificar para…» row: Hoy / Mañana / dd MMM (issue #991). */
@Composable
private fun taskPlanningValueText(plannedDate: Long?): String {
    if (plannedDate == null) return "—"
    val today = java.util.Calendar.getInstance().apply {
        set(java.util.Calendar.HOUR_OF_DAY, 0)
        set(java.util.Calendar.MINUTE, 0)
        set(java.util.Calendar.SECOND, 0)
        set(java.util.Calendar.MILLISECOND, 0)
    }.timeInMillis
    val tomorrow = java.util.Calendar.getInstance().apply {
        timeInMillis = today
        add(java.util.Calendar.DAY_OF_YEAR, 1)
    }.timeInMillis
    return when (plannedDate) {
        today -> stringResource(R.string.filter_today)
        tomorrow -> stringResource(R.string.task_plan_tomorrow)
        else -> SimpleDateFormat("dd MMM", Locale.getDefault()).format(java.util.Date(plannedDate))
    }
}

/**
 * «Planificar para…» (issue #991 S4): row + bottom-sheet chips + native picker,
 * extracted from TaskDetailScreen (cognitive budget).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun TaskPlanningSection(task: Task, viewModel: TaskDetailViewModel) {
                // «Planificar para…» row (issue #991 S4) replaces the binary toggle.
                var showPlanSheet by remember { mutableStateOf(false) }
                var showPlanDatePicker by remember { mutableStateOf(false) }
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = ripple(),
                            role = Role.Button,
                            onClickLabel = stringResource(R.string.task_plan_for)
                        ) { showPlanSheet = true },
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Rounded.Event,
                            contentDescription = null,
                            tint = DomainColors.DueToday,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.task_plan_for),
                            style = MaterialTheme.typography.bodyLarge,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = taskPlanningValueText(task.plannedDate),
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (task.plannedDate != null) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.Rounded.ExpandMore,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                if (showPlanSheet) {
                    ModalBottomSheet(onDismissRequest = { showPlanSheet = false }) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 8.dp)
                        ) {
                            Text(
                                text = stringResource(R.string.task_plan_for),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.padding(bottom = 12.dp)
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                AssistChip(
                                    onClick = {
                                        viewModel.setPlannedDate(DueDateEncoding.toPickerMillis(TaskPlanning.plannedDay()))
                                        showPlanSheet = false
                                    },
                                    label = { Text(stringResource(R.string.filter_today)) }
                                )
                                AssistChip(
                                    onClick = {
                                        viewModel.setPlannedDate(DueDateEncoding.toPickerMillis(TaskPlanning.tomorrow()))
                                        showPlanSheet = false
                                    },
                                    label = { Text(stringResource(R.string.task_plan_tomorrow)) }
                                )
                                AssistChip(
                                    onClick = {
                                        viewModel.setPlannedDate(DueDateEncoding.toPickerMillis(TaskPlanning.upcomingWeekend()))
                                        showPlanSheet = false
                                    },
                                    label = { Text(stringResource(R.string.task_plan_weekend)) }
                                )
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                AssistChip(
                                    onClick = {
                                        showPlanSheet = false
                                        showPlanDatePicker = true
                                    },
                                    label = { Text(stringResource(R.string.task_plan_pick)) }
                                )
                                if (task.plannedDate != null) {
                                    AssistChip(
                                        onClick = {
                                            viewModel.setPlannedDate(null)
                                            showPlanSheet = false
                                        },
                                        label = { Text(stringResource(R.string.task_plan_remove)) },
                                        colors = AssistChipDefaults.assistChipColors(
                                            labelColor = MaterialTheme.colorScheme.error
                                        )
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(24.dp))
                        }
                    }
                }

                if (showPlanDatePicker) {
                    // Picker exchanges UTC-midnight millis; the plan is stored as
                    // canonical local midnight (same boundary as due dates, C1).
                    val planPickerState = rememberDatePickerState(
                        initialSelectedDateMillis = DueDateEncoding.toPickerMillis(
                            task.plannedDate ?: System.currentTimeMillis()
                        )
                    )
                    DatePickerDialog(
                        onDismissRequest = { showPlanDatePicker = false },
                        confirmButton = {
                            TextButton(
                                onClick = {
                                    viewModel.setPlannedDate(planPickerState.selectedDateMillis)
                                    showPlanDatePicker = false
                                }
                            ) {
                                Text(stringResource(R.string.btn_save))
                            }
                        },
                        dismissButton = {
                            TextButton(onClick = { showPlanDatePicker = false }) {
                                Text(stringResource(R.string.btn_cancel))
                            }
                        }
                    ) {
                        DatePicker(state = planPickerState)
                    }
                }
}
