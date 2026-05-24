package dev.creapolis.pepinillo.feature.tasks

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.imeNestedScroll
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Sort
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.CheckCircleOutline
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Inbox
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.hilt.navigation.compose.hiltViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.feature.tasks.components.TaskItem
import dev.creapolis.pepinillo.ui.components.SuccessToast
import dev.creapolis.pepinillo.ui.components.TasksListSkeleton
import kotlinx.coroutines.delay
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TasksScreen(
    onTaskClick: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: TasksViewModel = hiltViewModel(),
    onNavigateToPaywall: () -> Unit = {},
) {
    val uiState by viewModel.uiState.collectAsState()
    val filteredTasks = uiState.filteredTasks
    val quickAddFocusRequester = remember { FocusRequester() }

    // Error snackbar
    var errorResId by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(Unit) {
        viewModel.errorEvent.collect { resId ->
            errorResId = resId
            delay(3000)
            errorResId = null
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        if (uiState.isLoading) {
            TasksListSkeleton(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = 24.dp, vertical = 80.dp),
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp)
                .imePadding(),
        ) {
            Spacer(modifier = Modifier.height(16.dp))

            // ── 1. HEADER ──
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Bottom,
            ) {
                Column {
                    Text(
                        text = stringResource(R.string.tasks_title),
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = if (!uiState.isPro) {
                            stringResource(R.string.tasks_active_limit, uiState.activeCount, FeatureGate.FREE_TASK_LIMIT)
                        } else {
                            stringResource(R.string.tasks_active_count, uiState.activeCount)
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (!uiState.isPro && uiState.activeCount >= FeatureGate.FREE_TASK_LIMIT) {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }

                // Sort menu
                SortButton(
                    selectedSort = uiState.selectedSort,
                    onSortSelected = viewModel::selectSort,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            // ── 2. PLAN CATEGORY CHIPS ──
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TaskFilter.entries.forEach { filter ->
                    FilterPill(
                        label = stringResource(filter.labelRes()),
                        icon = filter.icon(),
                        accentColor = filter.accentColor(),
                        isSelected = uiState.selectedFilter == filter,
                        onClick = { viewModel.selectFilter(filter) },
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // ── 3. TASK LIST ──
            val isCustomSort = uiState.selectedSort == TaskSortOption.Custom

            if (filteredTasks.isEmpty() && !uiState.isLoading) {
                // Empty state
                EmptyTasksState(
                    title = stringResource(uiState.selectedFilter.emptyTitleRes()),
                    description = stringResource(uiState.selectedFilter.emptyDescriptionRes()),
                    icon = uiState.selectedFilter.icon(),
                    tint = uiState.selectedFilter.accentColor(),
                    onCreateTaskClick = { quickAddFocusRequester.requestFocus() },
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                )
            } else {
                val listState = rememberLazyListState()
                val haptics = LocalHapticFeedback.current

                // Drag state
                var draggedItemIndex by remember { mutableIntStateOf(-1) }
                var dragOffsetY by remember { mutableFloatStateOf(0f) }
                var currentOverIndex by remember { mutableIntStateOf(-1) }

                LazyColumn(
                    state = listState,
                    modifier = Modifier
                        .weight(1f)
                        .imeNestedScroll(),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    itemsIndexed(
                        items = filteredTasks,
                        key = { _, task -> task.id },
                    ) { index, task ->
                        val isDragging = draggedItemIndex == index

                        // Swipe-to-delete
                        val dismissState = rememberSwipeToDismissBoxState(
                            confirmValueChange = { value ->
                                if (value == SwipeToDismissBoxValue.EndToStart) {
                                    viewModel.deleteTask(task.id)
                                    true
                                } else {
                                    false
                                }
                            },
                        )

                        SwipeToDismissBox(
                            state = dismissState,
                            backgroundContent = {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .clip(RoundedCornerShape(16.dp))
                                        .background(MaterialTheme.colorScheme.error)
                                        .padding(horizontal = 20.dp),
                                    contentAlignment = Alignment.CenterEnd,
                                ) {
                                    Icon(
                                        imageVector = Icons.Rounded.Delete,
                                        contentDescription = stringResource(R.string.cd_delete),
                                        tint = MaterialTheme.colorScheme.onError,
                                    )
                                }
                            },
                            enableDismissFromStartToEnd = false,
                        ) {
                        TaskItem(
                            task = task,
                            onToggleCompletion = {
                                haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                viewModel.toggleTaskCompletion(task.id)
                            },
                            onClick = { onTaskClick(task.id) },
                            showDragHandle = isCustomSort,
                            dragHandleModifier = if (isCustomSort) {
                                Modifier.pointerInput(Unit) {
                                    detectDragGesturesAfterLongPress(
                                        onDragStart = {
                                            draggedItemIndex = index
                                            currentOverIndex = index
                                            dragOffsetY = 0f
                                            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                        },
                                        onDrag = { change, dragAmount ->
                                            change.consume()
                                            dragOffsetY += dragAmount.y

                                            // Calculate which item we're hovering over
                                            val itemInfo = listState.layoutInfo.visibleItemsInfo
                                            val draggedInfo = itemInfo.firstOrNull { it.index == draggedItemIndex }
                                            if (draggedInfo != null) {
                                                val draggedCenter = draggedInfo.offset + draggedInfo.size / 2 + dragOffsetY.roundToInt()
                                                val targetItem = itemInfo.firstOrNull { info ->
                                                    info.index != draggedItemIndex &&
                                                        draggedCenter in info.offset..(info.offset + info.size)
                                                }
                                                if (targetItem != null && targetItem.index != currentOverIndex) {
                                                    val newTarget = targetItem.index
                                                    viewModel.reorderTasks(currentOverIndex, newTarget)
                                                    currentOverIndex = newTarget
                                                    draggedItemIndex = newTarget
                                                    dragOffsetY = 0f
                                                }
                                            }
                                        },
                                        onDragEnd = {
                                            draggedItemIndex = -1
                                            dragOffsetY = 0f
                                            currentOverIndex = -1
                                        },
                                        onDragCancel = {
                                            draggedItemIndex = -1
                                            dragOffsetY = 0f
                                            currentOverIndex = -1
                                        },
                                    )
                                }
                            } else {
                                Modifier
                            },
                            modifier = Modifier
                                .animateItem()
                                .then(
                                    if (isDragging) {
                                        Modifier
                                            .zIndex(1f)
                                            .shadow(8.dp, RoundedCornerShape(16.dp))
                                            .offset { IntOffset(0, dragOffsetY.roundToInt()) }
                                    } else {
                                        Modifier
                                    },
                                ),
                        )
                        } // SwipeToDismissBox
                    }
                }
            }

            // ── 4. QUICK ADD BAR ──
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f))
            QuickAddBar(
                placeholder = stringResource(uiState.selectedFilter.quickAddPlaceholderRes()),
                onAdd = viewModel::addQuickTask,
                focusRequester = quickAddFocusRequester,
            )
        }

        // ── Undo Snackbar ──
        val undoState by viewModel.undoEvent.collectAsState()
        undoState?.let { undo ->
            Snackbar(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(16.dp),
                action = {
                    TextButton(
                        onClick = { viewModel.undoDelete() },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.inversePrimary,
                        ),
                    ) {
                        Text(stringResource(R.string.btn_undo))
                    }
                },
                dismissAction = {
                    TextButton(
                        onClick = { viewModel.dismissUndo() },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.inverseOnSurface.copy(alpha = 0.7f),
                        ),
                    ) {
                        Text("\u2715")
                    }
                },
            ) {
                Text(text = stringResource(R.string.tasks_deleted_msg, undo.task.title))
            }
        }

        // ── Error Snackbar ──
        errorResId?.let { resId ->
            if (undoState == null) {
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp),
                ) {
                    Text(text = stringResource(resId))
                }
            }
        }

        // ── Success Toast ──
        val successMsg by viewModel.successMessage.collectAsState()
        SuccessToast(
            message = successMsg,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 88.dp),
            onDismiss = { viewModel.dismissSuccessMessage() },
        )
    }

    // Paywall navigation
    val showPaywall by viewModel.showPaywall.collectAsState()
    if (showPaywall) {
        viewModel.dismissPaywall()
        onNavigateToPaywall()
    }
}

@Composable
private fun QuickAddBar(
    placeholder: String,
    onAdd: (String) -> Unit,
    focusRequester: FocusRequester = FocusRequester(),
) {
    var title by rememberSaveable { mutableStateOf("") }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            modifier = Modifier.weight(1f).focusRequester(focusRequester),
            placeholder = {
                Text(placeholder, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f))
            },
            singleLine = true,
            textStyle = MaterialTheme.typography.bodyLarge,
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
            ),
            shape = RoundedCornerShape(16.dp),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = {
                if (title.isNotBlank()) {
                    onAdd(title)
                    title = ""
                }
            }),
        )
        Spacer(modifier = Modifier.width(8.dp))
        IconButton(
            onClick = {
                if (title.isNotBlank()) {
                    onAdd(title)
                    title = ""
                }
            },
            enabled = title.isNotBlank(),
        ) {
            Icon(
                Icons.Rounded.Add,
                contentDescription = stringResource(R.string.cd_add_task),
                tint = if (title.isNotBlank()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
            )
        }
    }
}

@Composable
private fun SortButton(
    selectedSort: TaskSortOption,
    onSortSelected: (TaskSortOption) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        IconButton(onClick = { expanded = true }) {
            Icon(
                Icons.AutoMirrored.Rounded.Sort,
                contentDescription = stringResource(R.string.cd_sort),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            TaskSortOption.entries.forEach { option ->
                val label = when (option) {
                    TaskSortOption.Custom -> stringResource(R.string.sort_custom)
                    TaskSortOption.Priority -> stringResource(R.string.sort_priority)
                    TaskSortOption.DueDate -> stringResource(R.string.sort_time)
                    TaskSortOption.Energy -> stringResource(R.string.sort_energy)
                    TaskSortOption.Newest -> "Newest" // To be localized if needed
                }
                DropdownMenuItem(
                    text = {
                        Text(
                            label,
                            fontWeight = if (selectedSort == option) FontWeight.Bold else FontWeight.Normal,
                        )
                    },
                    onClick = {
                        onSortSelected(option)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun FilterPill(
    label: String,
    icon: ImageVector,
    accentColor: Color,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val bgColor by animateColorAsState(
        targetValue = if (isSelected) {
            accentColor.copy(alpha = 0.18f)
        } else {
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        },
        animationSpec = spring(),
        label = "filterPillBg",
    )
    val contentColor by animateColorAsState(
        targetValue = if (isSelected) accentColor else MaterialTheme.colorScheme.onSurfaceVariant,
        animationSpec = spring(),
        label = "filterPillContent",
    )
    val borderColor by animateColorAsState(
        targetValue = if (isSelected) accentColor.copy(alpha = 0.45f) else Color.Transparent,
        animationSpec = spring(),
        label = "filterPillBorder",
    )

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(22.dp))
            .background(bgColor)
            .border(1.dp, borderColor, RoundedCornerShape(22.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(17.dp),
            tint = contentColor,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.SemiBold,
            color = contentColor,
        )
    }
}

@Composable
private fun EmptyTasksState(
    title: String,
    description: String,
    icon: ImageVector,
    tint: Color,
    modifier: Modifier = Modifier,
    onCreateTaskClick: () -> Unit = {},
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = tint.copy(alpha = 0.78f),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = description,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
        )
        Spacer(modifier = Modifier.height(20.dp))
        androidx.compose.material3.OutlinedButton(
            onClick = onCreateTaskClick,
            shape = RoundedCornerShape(20.dp),
        ) {
            Icon(
                imageVector = Icons.Rounded.Add,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(stringResource(R.string.tasks_btn_create_first))
        }
    }
}

private fun TaskFilter.labelRes(): Int = when (this) {
    TaskFilter.Today -> R.string.filter_today
    TaskFilter.Inbox -> R.string.filter_inbox
    TaskFilter.Upcoming -> R.string.filter_upcoming
    TaskFilter.Completed -> R.string.filter_completed
}

private fun TaskFilter.quickAddPlaceholderRes(): Int = when (this) {
    TaskFilter.Today -> R.string.tasks_quick_add_today
    TaskFilter.Inbox -> R.string.tasks_quick_add_inbox
    TaskFilter.Upcoming -> R.string.tasks_quick_add_upcoming
    TaskFilter.Completed -> R.string.tasks_quick_add_general
}

private fun TaskFilter.emptyTitleRes(): Int = when (this) {
    TaskFilter.Today -> R.string.tasks_empty_today_title
    TaskFilter.Inbox -> R.string.tasks_empty_inbox_title
    TaskFilter.Upcoming -> R.string.tasks_empty_upcoming_title
    TaskFilter.Completed -> R.string.tasks_empty_completed_title
}

private fun TaskFilter.emptyDescriptionRes(): Int = when (this) {
    TaskFilter.Today -> R.string.tasks_empty_today_desc
    TaskFilter.Inbox -> R.string.tasks_empty_inbox_desc
    TaskFilter.Upcoming -> R.string.tasks_empty_upcoming_desc
    TaskFilter.Completed -> R.string.tasks_empty_completed_desc
}

private fun TaskFilter.icon(): ImageVector = when (this) {
    TaskFilter.Today -> Icons.Rounded.LocalFireDepartment
    TaskFilter.Inbox -> Icons.Rounded.Inbox
    TaskFilter.Upcoming -> Icons.Rounded.CalendarMonth
    TaskFilter.Completed -> Icons.Rounded.CheckCircleOutline
}

@Composable
private fun TaskFilter.accentColor(): Color = when (this) {
    TaskFilter.Today -> Color(0xFFFF8A00)
    TaskFilter.Inbox -> Color(0xFF1A73E8)
    TaskFilter.Upcoming -> Color(0xFF8E24AA)
    TaskFilter.Completed -> Color(0xFF2E7D32)
}
