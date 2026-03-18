package dev.creapolis.pepinillo.feature.tasks.detail

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Clear
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.Today
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.feature.tasks.model.EnergyLevel
import dev.creapolis.pepinillo.feature.tasks.model.RecurrenceOption
import dev.creapolis.pepinillo.feature.tasks.model.TaskPriority
import dev.creapolis.pepinillo.ui.theme.EnergyColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TaskDetailScreen(
    onBack: () -> Unit,
    onStartFocus: (taskId: String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: TaskDetailViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.navigateBack.collect { onBack() }
    }

    if (uiState.isLoading || uiState.task == null) {
        Box(modifier = modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator()
        }
        return
    }

    val task = uiState.task!!
    var showDatePicker by rememberSaveable { mutableStateOf(false) }

    // Delete confirmation dialog
    if (uiState.showDeleteDialog) {
        AlertDialog(
            onDismissRequest = viewModel::dismissDeleteDialog,
            title = { Text("Delete Task?") },
            text = { Text("This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = viewModel::confirmDelete) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = viewModel::dismissDeleteDialog) { Text("Cancel") }
            },
        )
    }

    // Date picker dialog
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = task.dueDate ?: System.currentTimeMillis(),
        )
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.updateDueDate(datePickerState.selectedDateMillis)
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Task Details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // ── 1. Title Section ──
            item {
                TitleSection(
                    title = task.title,
                    isCompleted = task.isCompleted,
                    onTitleChange = viewModel::updateTitle,
                    onToggleCompletion = viewModel::toggleCompletion,
                )
            }

            // ── 2. Subtasks Section ──
            item {
                SubtasksSection(
                    subtasks = uiState.subtasks,
                    progress = uiState.subtaskProgress,
                    onAddSubtask = viewModel::addSubtask,
                    onToggleSubtask = viewModel::toggleSubtask,
                    onDeleteSubtask = viewModel::deleteSubtask,
                )
            }

            // ── 3. Scheduling Section ──
            item {
                SchedulingSection(
                    scheduledForToday = task.scheduledForToday,
                    dueDate = task.dueDate,
                    onToggleToday = viewModel::toggleScheduledForToday,
                    onDateClick = { showDatePicker = true },
                    onRemoveDate = { viewModel.updateDueDate(null) },
                )
            }

            // ── 4. Details Section (Priority, Energy, Pomodoros) ──
            item {
                DetailsSection(
                    priority = task.priority,
                    energyLevel = task.energyLevel,
                    estimatedPomodoros = task.estimatedPomodoros,
                    completedPomodoros = task.completedPomodoros,
                    onPriorityChange = viewModel::updatePriority,
                    onEnergyChange = viewModel::updateEnergyLevel,
                    onPomodorosChange = viewModel::updateEstimatedPomodoros,
                )
            }

            // ── 5. Recurrence Section ──
            item {
                RecurrenceSection(
                    currentRule = task.recurrenceRule,
                    onRecurrenceChange = viewModel::updateRecurrence,
                )
            }

            // ── 6. Notes Section ──
            item {
                NotesSection(
                    notes = task.notes,
                    onNotesChange = viewModel::updateNotes,
                )
            }

            // ── 7. Focus History Section ──
            if (uiState.focusSessions.isNotEmpty()) {
                item {
                    FocusHistorySection(
                        totalTime = uiState.totalFocusTimeFormatted,
                        pomodoroCount = uiState.focusPomodoroCount,
                    )
                }
            }

            // ── 8. Action Buttons ──
            item {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FilledTonalButton(
                        onClick = { onStartFocus(task.id) },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !task.isCompleted,
                        shape = RoundedCornerShape(16.dp),
                    ) {
                        Icon(Icons.Rounded.PlayArrow, contentDescription = null, modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Start Focus Session")
                    }

                    TextButton(
                        onClick = viewModel::showDeleteDialog,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(
                            Icons.Rounded.Delete,
                            contentDescription = null,
                            modifier = Modifier.size(20.dp),
                            tint = MaterialTheme.colorScheme.error,
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("Delete Task", color = MaterialTheme.colorScheme.error)
                    }
                }
            }

            item { Spacer(modifier = Modifier.height(24.dp)) }
        }
    }
}

// ── Section Composables ──

@Composable
private fun TitleSection(
    title: String,
    isCompleted: Boolean,
    onTitleChange: (String) -> Unit,
    onToggleCompletion: () -> Unit,
) {
    var editingTitle by rememberSaveable(title) { mutableStateOf(title) }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.Top,
        ) {
            CompletionCheckbox(
                isCompleted = isCompleted,
                onClick = onToggleCompletion,
            )
            Spacer(modifier = Modifier.width(12.dp))
            OutlinedTextField(
                value = editingTitle,
                onValueChange = { editingTitle = it },
                modifier = Modifier.weight(1f),
                textStyle = MaterialTheme.typography.titleLarge.copy(
                    fontWeight = FontWeight.SemiBold,
                    textDecoration = if (isCompleted) TextDecoration.LineThrough else null,
                ),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color.Transparent,
                    unfocusedBorderColor = Color.Transparent,
                ),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                keyboardActions = KeyboardActions(onDone = {
                    if (editingTitle.isNotBlank() && editingTitle != title) {
                        onTitleChange(editingTitle)
                    }
                }),
            )
        }
    }
}

@Composable
private fun CompletionCheckbox(
    isCompleted: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val bgColor by animateColorAsState(
        targetValue = if (isCompleted) MaterialTheme.colorScheme.primary else Color.Transparent,
        animationSpec = spring(),
        label = "checkboxBg",
    )
    Box(
        modifier = modifier
            .size(28.dp)
            .clip(CircleShape)
            .background(bgColor)
            .then(
                if (!isCompleted) Modifier.border(2.dp, MaterialTheme.colorScheme.outline, CircleShape)
                else Modifier,
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (isCompleted) {
            Icon(Icons.Rounded.Check, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onPrimary)
        }
    }
}

@Composable
private fun SubtasksSection(
    subtasks: List<dev.creapolis.pepinillo.feature.tasks.model.Subtask>,
    progress: Pair<Int, Int>,
    onAddSubtask: (String) -> Unit,
    onToggleSubtask: (String) -> Unit,
    onDeleteSubtask: (String) -> Unit,
) {
    var newSubtaskTitle by rememberSaveable { mutableStateOf("") }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Subtasks",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                if (subtasks.isNotEmpty()) {
                    Text(
                        "${progress.first}/${progress.second}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            subtasks.forEach { subtask ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Checkbox(
                        checked = subtask.isCompleted,
                        onCheckedChange = { onToggleSubtask(subtask.id) },
                    )
                    Text(
                        text = subtask.title,
                        modifier = Modifier.weight(1f),
                        style = MaterialTheme.typography.bodyMedium,
                        textDecoration = if (subtask.isCompleted) TextDecoration.LineThrough else null,
                        color = if (subtask.isCompleted) {
                            MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        } else {
                            MaterialTheme.colorScheme.onSurface
                        },
                    )
                    IconButton(
                        onClick = { onDeleteSubtask(subtask.id) },
                        modifier = Modifier.size(32.dp),
                    ) {
                        Icon(
                            Icons.Rounded.Clear,
                            contentDescription = "Delete subtask",
                            modifier = Modifier.size(16.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = newSubtaskTitle,
                    onValueChange = { newSubtaskTitle = it },
                    modifier = Modifier.weight(1f),
                    placeholder = { Text("Add subtask...") },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = Color.Transparent,
                        unfocusedBorderColor = Color.Transparent,
                    ),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = {
                        if (newSubtaskTitle.isNotBlank()) {
                            onAddSubtask(newSubtaskTitle)
                            newSubtaskTitle = ""
                        }
                    }),
                )
                IconButton(
                    onClick = {
                        if (newSubtaskTitle.isNotBlank()) {
                            onAddSubtask(newSubtaskTitle)
                            newSubtaskTitle = ""
                        }
                    },
                    enabled = newSubtaskTitle.isNotBlank(),
                ) {
                    Icon(Icons.Rounded.Add, contentDescription = "Add subtask")
                }
            }
        }
    }
}

@Composable
private fun SchedulingSection(
    scheduledForToday: Boolean,
    dueDate: Long?,
    onToggleToday: () -> Unit,
    onDateClick: () -> Unit,
    onRemoveDate: () -> Unit,
) {
    val dateFormatter = remember { SimpleDateFormat("MMM d, yyyy", Locale.getDefault()) }
    val isOverdue = dueDate != null && dueDate < System.currentTimeMillis()

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // Focus Today toggle
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Today, contentDescription = null, modifier = Modifier.size(20.dp), tint = MaterialTheme.colorScheme.primary)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text("Focus Today", style = MaterialTheme.typography.bodyLarge)
                }
                Switch(checked = scheduledForToday, onCheckedChange = { onToggleToday() })
            }

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            // Due date
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = onDateClick)
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        Icons.Rounded.CalendarMonth,
                        contentDescription = null,
                        modifier = Modifier.size(20.dp),
                        tint = if (isOverdue) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    if (dueDate != null) {
                        Text(
                            dateFormatter.format(Date(dueDate)),
                            style = MaterialTheme.typography.bodyLarge,
                            color = if (isOverdue) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                        )
                    } else {
                        Text(
                            "Add due date",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                if (dueDate != null) {
                    IconButton(onClick = onRemoveDate, modifier = Modifier.size(32.dp)) {
                        Icon(Icons.Rounded.Clear, contentDescription = "Remove date", modifier = Modifier.size(16.dp))
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DetailsSection(
    priority: TaskPriority,
    energyLevel: EnergyLevel,
    estimatedPomodoros: Int,
    completedPomodoros: Int,
    onPriorityChange: (TaskPriority) -> Unit,
    onEnergyChange: (EnergyLevel) -> Unit,
    onPomodorosChange: (Int) -> Unit,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Priority
            Column {
                Text("Priority", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(8.dp))
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    TaskPriority.entries.forEachIndexed { index, p ->
                        SegmentedButton(
                            selected = priority == p,
                            onClick = { onPriorityChange(p) },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = TaskPriority.entries.size),
                        ) {
                            Text(p.name, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }

            // Energy Level
            Column {
                Text("Energy Level", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(8.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EnergyLevel.entries.forEach { energy ->
                        val dotColor = when (energy) {
                            EnergyLevel.Deep -> EnergyColors.deep
                            EnergyLevel.Regular -> EnergyColors.regular
                            EnergyLevel.Light -> EnergyColors.light
                        }
                        FilterChip(
                            selected = energyLevel == energy,
                            onClick = { onEnergyChange(energy) },
                            label = { Text(energy.label) },
                            leadingIcon = {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(dotColor),
                                )
                            },
                            colors = FilterChipDefaults.filterChipColors(
                                selectedContainerColor = dotColor.copy(alpha = 0.15f),
                            ),
                        )
                    }
                }
            }

            // Estimated Pomodoros
            Column {
                Text("Estimated Pomodoros", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    IconButton(
                        onClick = { onPomodorosChange(estimatedPomodoros - 1) },
                        enabled = estimatedPomodoros > 1,
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Icon(Icons.Rounded.Remove, contentDescription = "Decrease", modifier = Modifier.size(18.dp))
                    }
                    Text(
                        "$estimatedPomodoros",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                    )
                    IconButton(
                        onClick = { onPomodorosChange(estimatedPomodoros + 1) },
                        enabled = estimatedPomodoros < 8,
                        modifier = Modifier
                            .size(36.dp)
                            .clip(CircleShape)
                            .background(MaterialTheme.colorScheme.surfaceVariant),
                    ) {
                        Icon(Icons.Rounded.Add, contentDescription = "Increase", modifier = Modifier.size(18.dp))
                    }
                }
                if (completedPomodoros > 0) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        "$completedPomodoros/$estimatedPomodoros completed",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun RecurrenceSection(
    currentRule: String?,
    onRecurrenceChange: (RecurrenceOption) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val currentOption = RecurrenceOption.fromRrule(currentRule)

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Box {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = true }
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Repeat, contentDescription = null, modifier = Modifier.size(20.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(modifier = Modifier.width(12.dp))
                    Text("Repeat", style = MaterialTheme.typography.bodyLarge)
                }
                Text(
                    currentOption.label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (currentOption != RecurrenceOption.None) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                RecurrenceOption.entries.forEach { option ->
                    DropdownMenuItem(
                        text = { Text(option.label) },
                        onClick = {
                            onRecurrenceChange(option)
                            expanded = false
                        },
                        trailingIcon = if (currentOption == option) {
                            { Icon(Icons.Rounded.Check, contentDescription = null, modifier = Modifier.size(18.dp)) }
                        } else null,
                    )
                }
            }
        }
    }
}

@Composable
private fun NotesSection(
    notes: String?,
    onNotesChange: (String) -> Unit,
) {
    var editingNotes by rememberSaveable(notes) { mutableStateOf(notes ?: "") }

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Notes", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = editingNotes,
                onValueChange = { editingNotes = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                placeholder = { Text("Add notes...") },
                textStyle = MaterialTheme.typography.bodyMedium,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = MaterialTheme.colorScheme.outlineVariant,
                    unfocusedBorderColor = Color.Transparent,
                ),
                shape = RoundedCornerShape(12.dp),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Default),
                keyboardActions = KeyboardActions(onDone = {
                    if (editingNotes != (notes ?: "")) onNotesChange(editingNotes)
                }),
            )
            // Save notes on focus loss via LaunchedEffect
            LaunchedEffect(editingNotes) {
                // Debounced auto-save when user stops typing
                kotlinx.coroutines.delay(1000)
                if (editingNotes != (notes ?: "")) {
                    onNotesChange(editingNotes)
                }
            }
        }
    }
}

@Composable
private fun FocusHistorySection(
    totalTime: String,
    pomodoroCount: Int,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text("Focus History", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(modifier = Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Total Focus Time", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(totalTime, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            }
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text("Completed Pomodoros", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("$pomodoroCount", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
            }
        }
    }
}
