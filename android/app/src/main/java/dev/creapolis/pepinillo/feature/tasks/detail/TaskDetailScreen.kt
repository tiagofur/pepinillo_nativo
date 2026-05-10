package dev.creapolis.pepinillo.feature.tasks.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.ui.theme.priorityColor

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskDetailScreen(
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    viewModel: TaskDetailViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()
    val task = uiState.task ?: return

    if (uiState.showDeleteDialog) {
        AlertDialog(
            onDismissRequest = viewModel::dismissDeleteDialog,
            title = { Text(stringResource(R.string.task_delete_confirm_title)) },
            text = { Text(stringResource(R.string.task_delete_confirm_desc)) },
            confirmButton = {
                TextButton(onClick = viewModel::confirmDelete) {
                    Text(stringResource(R.string.cd_delete), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::dismissDeleteDialog) {
                    Text(stringResource(R.string.btn_cancel))
                }
            },
        )
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.task_detail_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = stringResource(R.string.cd_go_back),
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
        ) {
            Spacer(Modifier.height(8.dp))

            // ── Title ──
            OutlinedTextField(
                value = task.title,
                onValueChange = viewModel::updateTitle,
                modifier = Modifier.fillMaxWidth(),
                textStyle = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                placeholder = { Text("Task title") },
                shape = RoundedCornerShape(16.dp),
            )

            Spacer(Modifier.height(24.dp))

            // ── Actions ──
            Button(
                onClick = { /* Start session logic */ },
                modifier = Modifier.fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(16.dp),
            ) {
                Icon(Icons.Rounded.PlayArrow, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.task_detail_btn_start))
            }

            Spacer(Modifier.height(12.dp))

            OutlinedButton(
                onClick = viewModel::showDeleteDialog,
                modifier = Modifier.fillMaxWidth().height(56.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
            ) {
                Icon(Icons.Rounded.Delete, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(stringResource(R.string.task_detail_btn_delete))
            }

            Spacer(Modifier.height(32.dp))

            // ── Details ──
            SectionTitle(stringResource(R.string.task_label_priority))
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                TaskPriority.entries.filter { it != TaskPriority.None }.forEach { priority ->
                    PriorityPill(
                        priority = priority,
                        isSelected = task.priority == priority,
                        onClick = { viewModel.updatePriority(priority) },
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            SectionTitle(stringResource(R.string.task_label_energy))
            Spacer(Modifier.height(12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                EnergyLevel.entries.forEach { level ->
                    EnergyPill(
                        level = level,
                        isSelected = task.energyLevel == level,
                        onClick = { viewModel.updateEnergyLevel(level) },
                    )
                }
            }

            Spacer(Modifier.height(24.dp))

            SectionTitle(stringResource(R.string.task_label_estimate))
            Spacer(Modifier.height(12.dp))
            PomodoroEstimateSelector(
                estimate = task.estimatedPomodoros,
                onValueChange = viewModel::updateEstimatedPomodoros,
            )

            Spacer(Modifier.height(24.dp))

            SectionTitle(stringResource(R.string.task_label_repeat))
            Spacer(Modifier.height(12.dp))
            RecurrencePicker(
                current = RecurrenceOption.fromRrule(task.recurrenceRule),
                onSelect = viewModel::updateRecurrence,
            )

            Spacer(Modifier.height(24.dp))

            SectionTitle(stringResource(R.string.task_label_notes))
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = task.notes ?: "",
                onValueChange = viewModel::updateNotes,
                placeholder = { Text(stringResource(R.string.task_label_notes_hint)) },
                modifier = Modifier.fillMaxWidth().height(120.dp),
                shape = RoundedCornerShape(16.dp),
            )

            Spacer(Modifier.height(32.dp))

            SectionTitle(stringResource(R.string.task_label_history))
            Spacer(Modifier.height(12.dp))
            
            DashboardCard {
                Column {
                    HistoryRow(
                        label = stringResource(R.string.task_stat_total_time),
                        value = uiState.totalFocusTimeFormatted,
                    )
                    HorizontalDivider(Modifier.padding(vertical = 12.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f))
                    HistoryRow(
                        label = stringResource(R.string.task_stat_completed_pomos),
                        value = "${uiState.focusPomodoroCount}",
                    )
                }
            }

            Spacer(Modifier.height(40.dp))
        }
    }
}

@Composable
private fun SectionTitle(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable
private fun PriorityPill(
    priority: TaskPriority,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val color = priority.priorityColor()
    val bgColor = if (isSelected) color else color.copy(alpha = 0.1f)
    val contentColor = if (isSelected) Color.White else color

    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = bgColor,
        modifier = Modifier.width(80.dp),
    ) {
        Text(
            text = priority.name,
            modifier = Modifier.padding(vertical = 8.dp),
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.labelMedium,
            color = contentColor,
        )
    }
}

@Composable
private fun EnergyPill(
    level: EnergyLevel,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val bgColor = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
    val contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant

    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(12.dp),
        color = bgColor,
        modifier = Modifier.width(100.dp),
    ) {
        Row(
            modifier = Modifier.padding(vertical = 8.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val emoji = when (level) {
                EnergyLevel.Deep -> "\uD83D\uDD25"
                EnergyLevel.Light -> "\uD83D\uDCA7"
                else -> "\u26A1"
            }
            Text(text = emoji, fontSize = 14.sp)
            Spacer(Modifier.width(6.dp))
            Text(
                text = level.name,
                style = MaterialTheme.typography.labelMedium,
                color = contentColor,
            )
        }
    }
}

@Composable
private fun PomodoroEstimateSelector(
    estimate: Int,
    onValueChange: (Int) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f))
            .padding(12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(onClick = { if (estimate > 1) onValueChange(estimate - 1) }) {
            Text("-", style = MaterialTheme.typography.headlineMedium)
        }
        Text(
            text = "$estimate \uD83C\uDF45",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        IconButton(onClick = { if (estimate < 10) onValueChange(estimate + 1) }) {
            Text("+", style = MaterialTheme.typography.headlineMedium)
        }
    }
}

@Composable
private fun RecurrencePicker(
    current: RecurrenceOption,
    onSelect: (RecurrenceOption) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        RecurrenceOption.entries.take(4).forEach { recurrence ->
            val isSelected = current == recurrence
            val bgColor = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
            val contentColor = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant

            Surface(
                onClick = { onSelect(recurrence) },
                shape = RoundedCornerShape(12.dp),
                color = bgColor,
                modifier = Modifier.weight(1f),
            ) {
                Text(
                    text = recurrence.label,
                    modifier = Modifier.padding(vertical = 8.dp),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.labelSmall,
                    color = contentColor,
                )
            }
        }
    }
}

@Composable
private fun HistoryRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text = value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun DashboardCard(content: @Composable () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.2f))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f), RoundedCornerShape(20.dp))
            .padding(16.dp),
    ) {
        content()
    }
}
