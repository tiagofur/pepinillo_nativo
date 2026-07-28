package dev.creapolis.pepinillo.feature.tasks

import dev.creapolis.pepinillo.ui.theme.DomainColors

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.imeNestedScroll
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Sort
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.CalendarMonth
import androidx.compose.material.icons.rounded.Check
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailScreen
import dev.creapolis.pepinillo.feature.tasks.detail.TaskDetailViewModel
import dev.creapolis.pepinillo.R
import dev.creapolis.pepinillo.core.billing.FeatureGate
import dev.creapolis.pepinillo.feature.tasks.components.TaskItem
import dev.creapolis.pepinillo.navigation.NavigationTransitions
import dev.creapolis.pepinillo.ui.components.LocalSnackbarController
import dev.creapolis.pepinillo.ui.components.TasksListSkeleton
import dev.creapolis.pepinillo.ui.components.rememberSharedBoundsModifier
import dev.creapolis.pepinillo.ui.theme.PepinilloShapeTokens
import dev.creapolis.pepinillo.ui.theme.isReduceMotionEnabled
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TasksScreen(
    onTaskClick: (String) -> Unit,
    onNavigateToAnalytics: (String) -> Unit,
    modifier: Modifier = Modifier,
    viewModel: TasksViewModel = hiltViewModel(),
    onNavigateToPaywall: () -> Unit = {},
    onStartFocusTask: () -> Unit = {},
    /**
     * Whether to show task details in an in-screen [ModalBottomSheet] (the original compact-width
     * behaviour). When `false` (expanded widths / Sprint 7 #493), task taps are forwarded to
     * [onTaskClick] so the two-pane [TasksAdaptiveLayout] can render the detail pane instead.
     */
    useBottomSheet: Boolean = true,
) {
    val uiState by viewModel.uiState.collectAsState()
    val filteredTasks = uiState.filteredTasks
    val quickAddFocusRequester = remember { FocusRequester() }
    var selectedTaskId by rememberSaveable { mutableStateOf<String?>(null) }
    var quickAddExpanded by rememberSaveable { mutableStateOf(false) }

    // Route transient messages (success, errors) through the app-wide SnackbarHost
    // instead of bespoke overlays. Undo is handled below via the controller's action.
    val snackbarController = LocalSnackbarController.current
    LaunchedEffect(Unit) {
        viewModel.errorEvent.collect { resId ->
            snackbarController?.show(message = resId)
        }
    }
    LaunchedEffect(viewModel.successMessage) {
        viewModel.successMessage.collect { resId ->
            if (resId != null) {
                snackbarController?.show(message = resId)
                viewModel.dismissSuccessMessage()
            }
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
            if (filteredTasks.isEmpty() && !uiState.isLoading) {
                // Empty state
                EmptyTasksState(
                    title = stringResource(uiState.selectedFilter.emptyTitleRes()),
                    description = stringResource(uiState.selectedFilter.emptyDescriptionRes()),
                    icon = uiState.selectedFilter.icon(),
                    tint = uiState.selectedFilter.accentColor(),
                    onCreateTaskClick = { quickAddExpanded = true },
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f),
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .imeNestedScroll(),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    itemsIndexed(
                        items = filteredTasks,
                        key = { _, task -> task.id },
                    ) { _, task ->
                        // Swipe EndToStart = delete, StartToEnd = complete (standard task-app gestures).
                        val dismissState = rememberSwipeToDismissBoxState(
                            confirmValueChange = { value ->
                                when (value) {
                                    SwipeToDismissBoxValue.EndToStart -> {
                                        viewModel.deleteTask(task.id)
                                        true
                                    }
                                    SwipeToDismissBoxValue.StartToEnd -> {
                                        viewModel.toggleTaskCompletion(task.id)
                                        // Don't dismiss — keep the row visible (now toggled to completed).
                                        false
                                    }
                                    SwipeToDismissBoxValue.Settled -> false
                                }
                            },
                        )

                        SwipeToDismissBox(
                            state = dismissState,
                            backgroundContent = {
                                val isCompleteSwipe = dismissState.dismissDirection == SwipeToDismissBoxValue.StartToEnd
                                val bgColor = if (isCompleteSwipe) {
                                    MaterialTheme.colorScheme.primary
                                } else {
                                    MaterialTheme.colorScheme.error
                                }
                                val fgColor = if (isCompleteSwipe) {
                                    MaterialTheme.colorScheme.onPrimary
                                } else {
                                    MaterialTheme.colorScheme.onError
                                }
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .clip(MaterialTheme.shapes.medium)
                                        .background(bgColor)
                                        .padding(horizontal = 20.dp),
                                    contentAlignment = if (isCompleteSwipe) Alignment.CenterStart else Alignment.CenterEnd,
                                ) {
                                    Icon(
                                        imageVector = if (isCompleteSwipe) Icons.Rounded.Check else Icons.Rounded.Delete,
                                        contentDescription = if (isCompleteSwipe) null else stringResource(R.string.cd_delete),
                                        tint = fgColor,
                                    )
                                }
                            },
                        ) {
                        TaskItem(
                            task = task,
                            subtaskProgress = uiState.subtaskProgressMap[task.id],
                            onToggleCompletion = { viewModel.toggleTaskCompletion(task.id) },
                            onClick = {
                                // In two-pane mode the detail is rendered by the parent
                                // TasksAdaptiveLayout, so forward the selection up (#493).
                                if (useBottomSheet) {
                                    selectedTaskId = task.id
                                } else {
                                    onTaskClick(task.id)
                                }
                            },
                            onStartFocus = {
                                viewModel.startFocusOnTask(task.id)
                                onStartFocusTask()
                            },
                            modifier = Modifier.animateItem(),
                            // Shared-bounds anchor keyed by task id; the TaskAnalyticsScreen
                            // title uses the same key so the row title morphs into it (#489).
                            titleModifier = rememberSharedBoundsModifier("task-analytics-${task.id}"),
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
                expanded = quickAddExpanded,
                onExpandedChange = { quickAddExpanded = it },
            )
        }

        // ── Undo via the app-wide SnackbarHost ──
        // The VM already expires undoEvent after 5s; we surface it as a snackbar with an Undo action.
        val undoState by viewModel.undoEvent.collectAsState()
        LaunchedEffect(undoState) {
            val undo = undoState ?: return@LaunchedEffect
            snackbarController?.show(
                message = R.string.tasks_deleted_msg,
                undo.task.title,
                actionLabel = R.string.btn_undo,
                duration = androidx.compose.material3.SnackbarDuration.Long,
                onAction = { viewModel.undoDelete() },
            )
        }

        if (useBottomSheet && selectedTaskId != null) {
            val detailViewModel: TaskDetailViewModel = hiltViewModel(key = selectedTaskId!!)
            LaunchedEffect(selectedTaskId) {
                detailViewModel.initialize(selectedTaskId!!)
            }

            ModalBottomSheet(
                onDismissRequest = { selectedTaskId = null },
                sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
                containerColor = MaterialTheme.colorScheme.surface,
            ) {
                // Expressive sheet content entrance: scale up from 0.93 + fade, with a
                // medium-bouncy spring. Under "Reduce motion" it snaps in instantly (#489).
                val reduceMotion = isReduceMotionEnabled()
                var contentVisible by remember { mutableStateOf(false) }
                LaunchedEffect(Unit) { contentVisible = true }
                AnimatedVisibility(
                    visible = contentVisible,
                    enter = if (reduceMotion) {
                        fadeIn(androidx.compose.animation.core.tween(0))
                    } else {
                        fadeIn(androidx.compose.animation.core.tween(NavigationTransitions.DURATION_MODAL)) +
                            scaleIn(
                                initialScale = 0.93f,
                                animationSpec = spring(
                                    dampingRatio = Spring.DampingRatioMediumBouncy,
                                    stiffness = Spring.StiffnessMedium,
                                ),
                            )
                    },
                ) {
                    TaskDetailScreen(
                        onBack = { selectedTaskId = null },
                        onNavigateToPaywall = onNavigateToPaywall,
                        viewModel = detailViewModel,
                        onNavigateToAnalytics = { taskId ->
                            selectedTaskId = null
                            onNavigateToAnalytics(taskId)
                        },
                        onStartFocusTask = { taskId ->
                            selectedTaskId = null
                            viewModel.startFocusOnTask(taskId)
                            onStartFocusTask()
                        }
                    )
                }
            }
        }
    }

    // Paywall navigation
    val showPaywall by viewModel.showPaywall.collectAsState()
    LaunchedEffect(showPaywall) {
        if (showPaywall) {
            viewModel.dismissPaywall()
            onNavigateToPaywall()
        }
    }
}

@Composable
private fun QuickAddBar(
    placeholder: String,
    onAdd: (String) -> Unit,
    focusRequester: FocusRequester = FocusRequester(),
    expanded: Boolean = false,
    onExpandedChange: (Boolean) -> Unit = {},
) {
    var title by rememberSaveable { mutableStateOf("") }

    AnimatedContent(
        targetState = expanded,
        label = "quickAddTransition"
    ) { isExpanded ->
        if (isExpanded) {
            var hasFocused by remember { mutableStateOf(false) }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    modifier = Modifier
                        .weight(1f)
                        .focusRequester(focusRequester)
                        .onFocusChanged { focusState ->
                            if (focusState.isFocused) {
                                hasFocused = true
                            }
                            if (hasFocused && !focusState.isFocused && title.isBlank()) {
                                onExpandedChange(false)
                            }
                        },
                    placeholder = {
                        Text(placeholder, color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f))
                    },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyLarge,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = MaterialTheme.colorScheme.primary,
                        unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f),
                    ),
                    shape = MaterialTheme.shapes.medium,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                    keyboardActions = KeyboardActions(onDone = {
                        if (title.isNotBlank()) {
                            onAdd(title)
                            title = ""
                            onExpandedChange(false)
                        }
                    }),
                )
                Spacer(modifier = Modifier.width(8.dp))
                IconButton(
                    onClick = {
                        if (title.isNotBlank()) {
                            onAdd(title)
                            title = ""
                            onExpandedChange(false)
                        }
                    },
                    enabled = title.isNotBlank(),
                ) {
                    Icon(
                        imageVector = Icons.Rounded.ArrowUpward,
                        contentDescription = stringResource(R.string.cd_add_task),
                        tint = if (title.isNotBlank()) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                    )
                }
            }

            LaunchedEffect(Unit) {
                focusRequester.requestFocus()
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(MaterialTheme.shapes.medium)
                    .clickable { onExpandedChange(true) }
                    .padding(horizontal = 16.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = Icons.Rounded.Add,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(20.dp)
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = stringResource(R.string.btn_new_task),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
                )
                Spacer(modifier = Modifier.weight(1f))
            }
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
            TaskSortOption.entries.filterNot { it == TaskSortOption.Custom }.forEach { option ->
                val label = when (option) {
                    TaskSortOption.Custom -> stringResource(R.string.sort_custom)
                    TaskSortOption.Priority -> stringResource(R.string.sort_priority)
                    TaskSortOption.DueDate -> stringResource(R.string.sort_time)
                    TaskSortOption.Energy -> stringResource(R.string.sort_energy)
                    TaskSortOption.Newest -> stringResource(R.string.sort_newest)
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
            .heightIn(min = 48.dp)
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
            shape = PepinilloShapeTokens.card,
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
    TaskFilter.Today -> DomainColors.DueToday
    TaskFilter.Inbox -> DomainColors.FilterInbox
    TaskFilter.Upcoming -> DomainColors.FilterUpcoming
    TaskFilter.Completed -> DomainColors.Positive
}
