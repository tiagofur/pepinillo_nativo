// TaskListView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Task list with full CRUD, filtering, sorting, and quick-start focus.
// Tap a task to open the full detail/edit sheet.

import SwiftUI
import ComposableArchitecture

struct TaskListView: View {
    @Bindable var store: StoreOf<TaskListFeature>
    var isInSplitView: Bool = false
    @State private var taskToDelete: UUID?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let content = VStack(spacing: 0) {
            filterBar
            taskList
            addTaskBar
        }
        .overlay(alignment: .bottom) {
            if let deletedTask = store.recentlyDeletedTask {
                undoBanner(taskTitle: deletedTask.title)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 60)
            }
        }
        .animation(.spring(), value: store.recentlyDeletedTask != nil)
        .navigationTitle(String(localized: "Tasks"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                importMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
        .modifier(TaskDetailSheetModifier(store: store, isCompact: !isInSplitView && sizeClass == .compact))
        .alert(
            String(localized: "Import Failed"),
            isPresented: Binding(
                get: { store.importError != nil },
                set: { if !$0 { store.send(.importErrorDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.importErrorDismissed) }
        } message: {
            Text(store.importError ?? "")
        }

        if isInSplitView {
            content
        } else {
            NavigationStack {
                content
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        VStack(spacing: 6) {
            Picker(String(localized: "Filter"), selection: Binding(
                get: { store.filter },
                set: { store.send(.filterChanged($0)) }
            )) {
                ForEach(TaskListFeature.TaskFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            Picker(String(localized: "Energy"), selection: Binding(
                get: { store.energyFilter },
                set: { store.send(.energyFilterChanged($0)) }
            )) {
                ForEach(TaskListFeature.EnergyFilter.allCases, id: \.self) { filter in
                    Text(filter.displayName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Task List

    @ViewBuilder
    private var taskList: some View {
        if filteredTasks.isEmpty {
            ContentUnavailableView(
                store.tasks.isEmpty
                    ? String(localized: "No Tasks Yet")
                    : String(localized: "No Matching Tasks"),
                systemImage: store.tasks.isEmpty
                    ? "checklist"
                    : "line.3.horizontal.decrease.circle",
                description: Text(store.tasks.isEmpty
                    ? String(localized: "Add your first task below to get started.")
                    : String(localized: "Try changing the filter to see more tasks."))
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(filteredTasks) { task in
                    TaskRow(
                        task: task,
                        onTap: { store.send(.taskTapped(task.id)) },
                        onComplete: { store.send(.taskCompleted(task.id)) },
                        onStartFocus: { store.send(.startFocusOnTask(task.id)) },
                        onScheduledForTodayToggled: {
                            store.send(.taskScheduledForToday(task.id, !task.scheduledForToday))
                        },
                        onEnergyChanged: { level in
                            store.send(.energyLevelChanged(task.id, level))
                        },
                        onRecurrenceChanged: { rule in
                            store.send(.recurrenceChanged(task.id, rule))
                        }
                    )
                    .listRowBackground(
                        isInSplitView && store.selectedTaskID == task.id
                            ? Color.accentColor.opacity(0.1)
                            : nil
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            store.send(.taskScheduledForToday(task.id, !task.scheduledForToday))
                            HapticManager.impact(.light)
                        } label: {
                            Label(
                                task.scheduledForToday
                                    ? String(localized: "Remove from Today")
                                    : String(localized: "Add to Today"),
                                systemImage: task.scheduledForToday ? "minus.circle" : "bolt.circle.fill"
                            )
                        }
                        .tint(task.scheduledForToday ? .gray : .orange)
                    }
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        taskToDelete = filteredTasks[index].id
                    }
                }
                .onMove { source, destination in
                    store.send(.taskMoved(source, destination))
                }
            }
            .listStyle(.plain)
            .refreshable { store.send(.onAppear) }
            .confirmationDialog(
                String(localized: "Delete Task?"),
                isPresented: Binding(
                    get: { taskToDelete != nil },
                    set: { if !$0 { taskToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete"), role: .destructive) {
                    if let id = taskToDelete {
                        store.send(.taskDeleted(id))
                        taskToDelete = nil
                    }
                }
            }
        }
    }

    // MARK: - Add Task Bar

    private var addTaskBar: some View {
        HStack(spacing: 12) {
            TextField(
                store.filter == .today
                    ? String(localized: "Add task for today…")
                    : String(localized: "Add a task…"),
                text: Binding(
                    get: { store.newTaskTitle },
                    set: { store.send(.newTaskTitleChanged($0)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { store.send(.addTaskTapped) }

            Button {
                HapticManager.impact(.light)
                store.send(.addTaskTapped)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
            .disabled(store.newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Undo Banner

    private func undoBanner(taskTitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\"\(taskTitle)\" deleted")
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            Button {
                HapticManager.impact(.light)
                store.send(.undoDeleteTask)
            } label: {
                Text(String(localized: "Undo"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Toolbar Items

    private var importMenu: some View {
        Menu {
            Button {
                store.send(.importFromRemindersTapped)
            } label: {
                Label(String(localized: "Import from Reminders"), systemImage: "list.bullet.rectangle")
            }
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
    }

    private var sortMenu: some View {
        Menu {
            ForEach(TaskListFeature.SortOrder.allCases, id: \.self) { order in
                Button {
                    store.send(.sortOrderChanged(order))
                } label: {
                    HStack {
                        Label(order.displayName, systemImage: order.icon)
                        if store.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: store.sortOrder == .custom ? "arrow.up.arrow.down" : "arrow.up.arrow.down.circle.fill")
        }
    }

    // MARK: - Filtered & Sorted Tasks

    private var filteredTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        // Step 1: Filter by status
        var result: IdentifiedArrayOf<TaskListFeature.TaskItemState>
        switch store.filter {
        case .today:
            result = store.tasks.filter { !$0.isCompleted && $0.scheduledForToday }
        case .active:
            result = store.tasks.filter { !$0.isCompleted }
        case .completed:
            result = store.tasks.filter { $0.isCompleted }
        case .all:
            result = store.tasks
        }

        // Step 2: Filter by energy level
        if let energy = store.energyFilter.energyLevel {
            result = result.filter { $0.energyLevel == energy }
        }

        // Step 3: Sort
        switch store.sortOrder {
        case .custom:
            break // Already in manual order
        case .priority:
            result = IdentifiedArrayOf(uniqueElements: result.sorted { $0.priority > $1.priority })
        case .dueDate:
            result = IdentifiedArrayOf(uniqueElements: result.sorted {
                switch ($0.dueDate, $1.dueDate) {
                case (.some(let lhs), .some(let rhs)): return lhs < rhs
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return false
                }
            })
        case .energy:
            let energyRank: (EnergyLevel) -> Int = { level in
                switch level { case .deep: return 0; case .shallow: return 1; case .admin: return 2 }
            }
            result = IdentifiedArrayOf(uniqueElements: result.sorted {
                energyRank($0.energyLevel) < energyRank($1.energyLevel)
            })
        case .created:
            result = IdentifiedArrayOf(uniqueElements: result.sorted { $0.createdAt > $1.createdAt })
        }

        return result
    }
}

// MARK: - Task Detail Sheet (iPhone only)

/// Only presents the task detail as a sheet on compact size class (iPhone).
/// On regular size class (iPad), detail is shown inline in the split view detail column.
private struct TaskDetailSheetModifier: ViewModifier {
    @Bindable var store: StoreOf<TaskListFeature>
    let isCompact: Bool

    func body(content: Content) -> some View {
        if isCompact {
            content.sheet(
                item: $store.scope(state: \.detail, action: \.detail)
            ) { detailStore in
                TaskDetailView(store: detailStore)
            }
        } else {
            content
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: TaskListFeature.TaskItemState
    let onTap: () -> Void
    let onComplete: () -> Void
    let onStartFocus: () -> Void
    var onScheduledForTodayToggled: (() -> Void)?
    var onEnergyChanged: ((EnergyLevel) -> Void)?
    var onRecurrenceChanged: ((String?) -> Void)?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                completionButton
                taskInfo
                Spacer()
                if !task.isCompleted {
                    focusButton
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            // Energy level
            Menu {
                ForEach(EnergyLevel.allCases, id: \.self) { level in
                    Button {
                        onEnergyChanged?(level)
                    } label: {
                        Label(level.displayName, systemImage: level.icon)
                    }
                }
            } label: {
                Label(String(localized: "Energy Level"), systemImage: "bolt")
            }

            // Today scheduling
            Button {
                onScheduledForTodayToggled?()
            } label: {
                Label(
                    task.scheduledForToday
                        ? String(localized: "Remove from Today")
                        : String(localized: "Add to Today"),
                    systemImage: task.scheduledForToday ? "minus.circle" : "bolt.circle.fill"
                )
            }

            // Recurrence
            Menu {
                ForEach(RecurrencePreset.allCases, id: \.self) { preset in
                    Button {
                        onRecurrenceChanged?(preset.rawValue)
                    } label: {
                        Label(preset.displayName, systemImage: preset.icon)
                    }
                }
                if task.recurrenceRule != nil {
                    Divider()
                    Button(role: .destructive) {
                        onRecurrenceChanged?(nil)
                    } label: {
                        Label(String(localized: "Remove Recurrence"), systemImage: "xmark")
                    }
                }
            } label: {
                Label(String(localized: "Repeat"), systemImage: "arrow.clockwise")
            }

            Divider()

            Button {
                onStartFocus()
            } label: {
                Label(String(localized: "Start Focus"), systemImage: "play.circle")
            }
            .disabled(task.isCompleted)
        }
    }

    // MARK: - Row Subviews

    private var completionButton: some View {
        Button(action: {
            onComplete()
            HapticManager.notification(.success)
        }) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.isCompleted ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted
            ? String(localized: "Mark as incomplete")
            : String(localized: "Mark as complete"))
    }

    private var taskInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Title
            HStack(spacing: 4) {
                if task.priority == .high {
                    Image(systemName: "exclamationmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                } else if task.priority == .medium {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
            }

            // Notes snippet
            if let notes = task.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Metadata badges
            metadataBadges
        }
    }

    @ViewBuilder
    private var metadataBadges: some View {
        let hasBadges = task.dueDate != nil || task.scheduledForToday
            || task.estimatedPomodoros > 0 || task.subtaskProgress.total > 0
            || task.recurrenceRule != nil

        if hasBadges {
            HStack(spacing: 6) {
                // Due date
                if let due = task.dueDate {
                    let isOverdue = due < Calendar.current.startOfDay(for: .now) && !task.isCompleted
                    Label(formatDueDate(due), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                }

                // Today indicator
                if task.scheduledForToday && task.dueDate == nil {
                    Label(String(localized: "Today"), systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                // Energy level
                Label(task.energyLevel.displayName, systemImage: task.energyLevel.icon)
                    .font(.caption2)
                    .foregroundStyle(task.energyLevel.color)

                // Pomodoros
                if task.estimatedPomodoros > 0 {
                    Text("🍅 \(task.completedPomodoros)/\(task.estimatedPomodoros)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Subtasks
                if task.subtaskProgress.total > 0 {
                    Text("☑ \(task.subtaskProgress.completed)/\(task.subtaskProgress.total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Recurrence
                if let rule = task.recurrenceRule,
                   let preset = RecurrencePreset.from(rule: rule) {
                    Label(preset.displayName, systemImage: preset.icon)
                        .font(.caption2)
                        .foregroundStyle(.teal)
                }
            }
        }
    }

    private var focusButton: some View {
        Button(action: onStartFocus) {
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Start focus session with this task"))
    }

    // MARK: - Helpers

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(date) { return String(localized: "Tomorrow") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
