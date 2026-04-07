package dev.creapolis.pepinillo.feature.tasks

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CheckCircleOutline
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.Sort
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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.hilt.navigation.compose.hiltViewModel
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
    var errorMessage by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(Unit) {
        viewModel.errorEvent.collect { msg ->
            errorMessage = msg
            delay(3000)
            errorMessage = null
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
                        text = "Tasks",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = if (!uiState.isPro) {
                            "${uiState.activeCount}/${FeatureGate.FREE_TASK_LIMIT} active"
                        } else {
                            "${uiState.activeCount} active"
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

            // ── 2. FILTER CHIPS ──
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TaskFilter.entries.forEach { filter ->
                    FilterPill(
                        label = filter.label,
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
                                        contentDescription = "Delete",
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
                                .background(MaterialTheme.colorScheme.surface)
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
                placeholder = if (uiState.selectedFilter == TaskFilter.Today) "Add task for today..." else "Add a task...",
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
                        Text("Undo")
                    }
                },
                dismissAction = {
                    TextButton(
                        onClick = { viewModel.dismissUndo() },
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.inverseOnSurface.copy(alpha = 0.7f),
                        ),
                    ) {
                        Text("✕")
                    }
                },
            ) {
                Text(text = "\"${undo.task.title}\" deleted")
            }
        }

        // ── Error Snackbar ──
        errorMessage?.let { msg ->
            if (undoState == null) {
                Snackbar(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(16.dp),
                ) {
                    Text(text = msg)
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
                contentDescription = "Add task",
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
                Icons.Rounded.Sort,
                contentDescription = "Sort",
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            TaskSortOption.entries.forEach { option ->
                DropdownMenuItem(
                    text = {
                        Text(
                            option.label,
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
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val bgColor by animateColorAsState(
        targetValue = if (isSelected) {
            MaterialTheme.colorScheme.primary
        } else {
            MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        },
        animationSpec = spring(),
        label = "filterPillBg",
    )
    val textColor by animateColorAsState(
        targetValue = if (isSelected) {
            MaterialTheme.colorScheme.onPrimary
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        animationSpec = spring(),
        label = "filterPillText",
    )

    Text(
        text = label,
        style = MaterialTheme.typography.labelLarge,
        color = textColor,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(bgColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 10.dp),
    )
}

@Composable
private fun EmptyTasksState(
    modifier: Modifier = Modifier,
    onCreateTaskClick: () -> Unit = {},
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Rounded.CheckCircleOutline,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "No tasks yet",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "Type below to add your first task",
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
            Text("Create your first task")
        }
    }
}
