// MacPlanView.swift
// Pepinillo — native macOS Plan table
//
// The shared TaskListFeature owns tasks and persistence. This view owns only
// native macOS presentation: the table, smart-list filter, search, selection,
// context menu, drag reorder, and the inline new-task composer.

import SwiftUI
import ComposableArchitecture
import Combine

// MARK: - Filter

/// The macOS design contract uses All / Today / Upcoming / Completed. The
/// shared iPhone/iPad Plan keeps its Inbox smart list, so this stays local and
/// maps to the shared reducer filter for new-task defaults.
enum MacPlanFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case upcoming
    case completed

    var id: Self { self }

    var title: String {
        switch self {
        case .all:       return String(localized: "All")
        case .today:     return String(localized: "Today")
        case .upcoming:  return String(localized: "Upcoming")
        case .completed: return String(localized: "Completed")
        }
    }

    var systemImage: String {
        switch self {
        case .all:       return "tray.full"
        case .today:     return "flame.fill"
        case .upcoming:  return "calendar"
        case .completed: return "checkmark.circle"
        }
    }

    var sharedFilter: PlanFilter {
        switch self {
        case .all:       return .inbox
        case .today:     return .today
        case .upcoming:  return .upcoming
        case .completed: return .completed
        }
    }
}

// MARK: - View

struct MacPlanView: View {
    @Bindable var store: StoreOf<TaskListFeature>

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var filter: MacPlanFilter = .all
    @State private var searchText = ""
    @State private var selection = Set<UUID>()
    @State private var isInspectorPresented = false
    @State private var editingTaskID: UUID?
    @State private var editingTitle = ""
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        let tasks = filteredTasks

        VStack(spacing: 0) {
            if store.isNewTaskComposerPresented {
                newTaskComposer
                Divider()
            }

            content(tasks: tasks)
        }
        .background(Color.pepinilloSystemBackground)
        .dropDestination(for: String.self) { items, _ in
            createTaskFromDroppedText(items)
        }
        .navigationTitle(String(localized: "Plan"))
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: Text("Search tasks")
        )
        .searchFocused($isSearchFocused)
        .toolbar { toolbarContent }
        .inspector(isPresented: $isInspectorPresented) {
            inspectorContent
                .inspectorColumnWidth(min: 300, ideal: 340, max: 460)
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPlanSearchRequested)) { _ in
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPlanRenameRequested)) { _ in
            guard let id = selection.first, let task = store.tasks[id: id] else { return }
            if isInspectorPresented {
                NotificationCenter.default.post(name: .macInspectorFocusTitleRequested, object: nil)
            } else {
                beginTitleEdit(task)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .macPlanInspectorToggleRequested)) { _ in
            toggleInspector()
        }
        .onAppear {
            store.send(.onAppear)
            store.send(.planFilterSelected(filter.sharedFilter))
        }
        .onChange(of: filter) { _, newValue in
            store.send(.planFilterSelected(newValue.sharedFilter))
        }
        .onChange(of: selection) { _, newValue in
            if let editingTaskID, !newValue.contains(editingTaskID) {
                commitTitleEdit(for: editingTaskID)
            }

            guard isInspectorPresented,
                  let id = newValue.first,
                  store.detail?.taskID != id else { return }
            store.send(.taskTapped(id))
        }
        .onChange(of: store.detail?.taskID) { _, newValue in
            if newValue == nil {
                isInspectorPresented = false
            }
        }
        .onChange(of: tasks.map(\.id)) { _, ids in
            selection.formIntersection(Set(ids))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            undoBannerContent
        }
        .alert(
            String(localized: "Couldn't Load Tasks"),
            isPresented: Binding(
                get: { store.loadError != nil },
                set: { if !$0 { store.send(.loadErrorDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.loadErrorDismissed) }
        } message: {
            Text(store.loadError ?? "")
        }
        .alert(
            String(localized: "Couldn't Save Changes"),
            isPresented: Binding(
                get: { store.mutationError != nil },
                set: { if !$0 { store.send(.mutationErrorDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.mutationErrorDismissed) }
        } message: {
            Text(store.mutationError ?? "")
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>) -> some View {
        if store.isLoading && !store.hasLoadedData {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tasks.isEmpty {
            emptyState
        } else {
            taskTable(tasks: tasks)
        }
    }

    private func taskTable(tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>) -> some View {
        Table(of: TaskListFeature.TaskItemState.self, selection: $selection) {
            TableColumn(String(localized: "Done")) { task in
                MacTaskRowObserver(store: store, taskID: task.id) { current in
                    doneCell(current)
                        .frame(width: 28, height: 30)
                }
            }
            .width(44)

            TableColumn(String(localized: "Title")) { task in
                MacTaskTitleCell(
                    store: store,
                    taskID: task.id,
                    editingTaskID: $editingTaskID,
                    editingTitle: $editingTitle,
                    onCommit: { commitTitleEdit(for: $0) },
                    onCancel: { cancelTitleEdit() }
                )
            }
            .width(min: 180, ideal: 340, max: .infinity)

            TableColumn(String(localized: "Priority")) { task in
                MacTaskRowObserver(store: store, taskID: task.id) { current in
                    priorityCell(current)
                        .frame(height: 30, alignment: .leading)
                }
            }
            .width(min: 80, ideal: 100)

            TableColumn(String(localized: "Energy")) { task in
                MacTaskRowObserver(store: store, taskID: task.id) { current in
                    energyCell(current)
                        .frame(height: 30, alignment: .leading)
                }
            }
            .width(min: 120, ideal: 140)

            TableColumn(String(localized: "Pomodoros")) { task in
                MacTaskRowObserver(store: store, taskID: task.id) { current in
                    pomodorosCell(current)
                        .frame(height: 30, alignment: .leading)
                }
            }
            .width(min: 80, ideal: 96)

            TableColumn(String(localized: "Due")) { task in
                MacTaskRowObserver(store: store, taskID: task.id) { current in
                    dueCell(current)
                        .frame(height: 30, alignment: .leading)
                }
            }
            .width(min: 80, ideal: 110)
        } rows: {
            ForEach(tasks) { task in
                TableRow(task)
                    .draggable(task.id.uuidString)
                    .dropDestination(for: String.self) { items in
                        guard let targetIndex = tasks.firstIndex(where: { $0.id == task.id }) else { return }
                        reorder(items, at: targetIndex, tasks: tasks)
                    }
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .contextMenu(forSelectionType: UUID.self) { ids in
            taskContextMenu(ids: ids)
        } primaryAction: { ids in
            guard let id = ids.first else { return }
            selection = [id]
            store.send(.taskTapped(id))
            isInspectorPresented = true
        }
    }

    // MARK: - Cells

    private func doneCell(_ task: TaskListFeature.TaskItemState) -> some View {
        Button {
            store.send(.taskCompleted(task.id))
        } label: {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(task.isCompleted ? Color.green : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                task.isCompleted
                    ? String(localized: "Mark as incomplete")
                    : String(localized: "Mark as complete")
            )
        )
    }

    private func priorityCell(_ task: TaskListFeature.TaskItemState) -> some View {
        HStack(spacing: 4) {
            if task.priority != .none {
                Image(systemName: task.priority.icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(task.priority == .none ? "—" : task.priority.displayName)
                .foregroundStyle(task.priority == .none ? Color.secondary : Color.primary)
                .lineLimit(1)
        }
        .font(.callout)
    }

    private func energyCell(_ task: TaskListFeature.TaskItemState) -> some View {
        Label(task.energyLevel.displayName, systemImage: task.energyLevel.icon)
            .font(.callout)
            .foregroundStyle(task.energyLevel.color)
            .lineLimit(1)
    }

    private func pomodorosCell(_ task: TaskListFeature.TaskItemState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(task.completedPomodoros)/\(task.estimatedPomodoros)")
                .font(.callout)
                .monospacedDigit()
        }
    }

    private func dueCell(_ task: TaskListFeature.TaskItemState) -> some View {
        Text(dueText(for: task))
            .font(.callout)
            .foregroundStyle(isOverdue(task) ? Color.red : Color.secondary)
            .lineLimit(1)
    }

    private func dueText(for task: TaskListFeature.TaskItemState) -> String {
        guard let dueDate = task.dueDate else {
            return task.scheduledForToday ? String(localized: "Today") : "—"
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return String(localized: "Today")
        }
        if calendar.isDateInTomorrow(dueDate) {
            return String(localized: "Tomorrow")
        }
        if dueDate < calendar.startOfDay(for: .now) && !task.isCompleted {
            return String(localized: "Overdue")
        }
        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func isOverdue(_ task: TaskListFeature.TaskItemState) -> Bool {
        guard let dueDate = task.dueDate, !task.isCompleted else { return false }
        return dueDate < Calendar.current.startOfDay(for: .now)
    }

    // MARK: - Context menu

    @ViewBuilder
    private func taskContextMenu(ids: Set<UUID>) -> some View {
        let tasks = ids.compactMap { store.tasks[id: $0] }

        if !tasks.isEmpty {
            if tasks.count == 1, let task = tasks.first {
                Button(String(localized: "Rename Task")) {
                    beginTitleEdit(task)
                }
                Divider()
            }

            let startable = tasks.first { !$0.isCompleted }
            Button(String(localized: "Start Focus")) {
                if let startable {
                    store.send(.startFocusOnTask(startable.id))
                }
            }
            .disabled(startable == nil)

            let allCompleted = tasks.allSatisfy(\.isCompleted)
            Button(
                allCompleted
                    ? String(localized: "Mark Incomplete")
                    : String(localized: "Complete")
            ) {
                for id in ids {
                    store.send(.setTaskCompleted(id, !allCompleted))
                }
            }

            Divider()

            Menu(String(localized: "Priority")) {
                ForEach(TaskPriority.allCases.sorted(by: >), id: \.self) { priority in
                    Button {
                        for id in ids {
                            store.send(.priorityChanged(id, priority))
                        }
                    } label: {
                        if tasks.allSatisfy({ $0.priority == priority }) {
                            Label(priority.displayName, systemImage: "checkmark")
                        } else {
                            Text(priority.displayName)
                        }
                    }
                }
            }

            Menu(String(localized: "Energy")) {
                ForEach(EnergyLevel.allCases, id: \.self) { level in
                    Button {
                        for id in ids {
                            store.send(.energyLevelChanged(id, level))
                        }
                    } label: {
                        if tasks.allSatisfy({ $0.energyLevel == level }) {
                            Label(level.displayName, systemImage: "checkmark")
                        } else {
                            Text(level.displayName)
                        }
                    }
                }
            }

            Button(String(localized: "Move to Today")) {
                for id in ids {
                    store.send(.taskScheduledForToday(id, true))
                }
            }
            .disabled(tasks.allSatisfy(\.scheduledForToday))

            Divider()

            Button(role: .destructive) {
                for id in ids {
                    store.send(.taskDeleted(id))
                }
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                toggleInspector()
            } label: {
                Label(String(localized: "Show Inspector"), systemImage: "sidebar.trailing")
                    .labelStyle(.iconOnly)
            }
            .help(String(localized: "Show Inspector (⌘⌥I)"))
            .accessibilityLabel(String(localized: "Show Inspector"))
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(MacPlanFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        if filter == item {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Label(item.title, systemImage: item.systemImage)
                        }
                    }
                }
            } label: {
                Label(filter.title, systemImage: filter.systemImage)
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(String(localized: "Filter tasks"))
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                store.send(.newTaskRequested)
            } label: {
                Label(
                    String(localized: "menu.plan.newtask", defaultValue: "New Task"),
                    systemImage: "plus"
                )
            }
            .help(String(localized: "New Task (⌘N)"))
        }
    }

    // MARK: - New task composer

    private var newTaskComposer: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            TextField(
                String(localized: "New task"),
                text: Binding(
                    get: { store.newTaskTitle },
                    set: { store.send(.newTaskTitleChanged($0)) }
                )
            )
            .textFieldStyle(.roundedBorder)
            .focused($isComposerFocused)
            .onSubmit(submitNewTask)

            Button(String(localized: "Add")) {
                submitNewTask()
            }
            .disabled(trimmedNewTaskTitle.isEmpty)
            .keyboardShortcut(.defaultAction)

            Button(String(localized: "Cancel")) {
                store.send(.newTaskComposerDismissed)
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .onAppear {
            isComposerFocused = true
        }
    }

    private var trimmedNewTaskTitle: String {
        store.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitNewTask() {
        guard !trimmedNewTaskTitle.isEmpty else { return }
        store.send(.addTaskTapped)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            PepinilloEmptyState(
                title: emptyTitle,
                description: emptyDescription,
                systemImage: filter.systemImage,
                tint: .accentColor,
                cornerRadius: GlassCornerRadius.card
            )

            Button {
                store.send(.newTaskRequested)
            } label: {
                Label(String(localized: "New task"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyTitle: String {
        if isSearching { return String(localized: "No Results") }
        switch filter {
        case .all:       return String(localized: "No Tasks")
        case .today:     return String(localized: "Nothing for Today")
        case .upcoming:  return String(localized: "Nothing Upcoming")
        case .completed: return String(localized: "No Completed Tasks")
        }
    }

    private var emptyDescription: String {
        if isSearching {
            return String(localized: "No tasks match your search.")
        }
        switch filter {
        case .all:
            return String(localized: "Capture what matters and it will show up here.")
        case .today:
            return String(localized: "Add a task for today and start focusing.")
        case .upcoming:
            return String(localized: "No deadlines on the horizon.")
        case .completed:
            return String(localized: "Complete a task and your wins will show up here.")
        }
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorContent: some View {
        if let presentedStore = store.scope(state: \.detail, action: \.detail) {
            let childStore = presentedStore.scope(state: \.self, action: \.presented)
            MacTaskInspectorView(
                store: childStore,
                onClose: {
                    isInspectorPresented = false
                    store.send(.taskDetailDismissed)
                },
                onStartFocus: { id, _ in
                    isInspectorPresented = false
                    store.send(.taskDetailDismissed)
                    store.send(.startFocusOnTask(id))
                },
                onToggleCompletion: { id in
                    store.send(.taskCompleted(id))
                }
            )
            .id(presentedStore.taskID)
        } else {
            ContentUnavailableView {
                Label(String(localized: "No Task Selected"), systemImage: "sidebar.trailing")
            } description: {
                Text(String(localized: "Select a task to inspect it."))
            }
        }
    }

    private func toggleInspector() {
        if isInspectorPresented {
            isInspectorPresented = false
            store.send(.taskDetailDismissed)
            return
        }

        if let id = selection.first, store.detail?.taskID != id {
            store.send(.taskTapped(id))
        }
        isInspectorPresented = true
    }

    // MARK: - Inline title edit

    private func beginTitleEdit(_ task: TaskListFeature.TaskItemState) {
        if let editingTaskID, editingTaskID != task.id {
            commitTitleEdit(for: editingTaskID)
        }
        selection = [task.id]
        editingTaskID = task.id
        editingTitle = task.title
    }

    private func commitTitleEdit(for id: UUID) {
        guard editingTaskID == id else { return }
        let trimmed = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        editingTaskID = nil
        guard !trimmed.isEmpty else { return }
        store.send(.taskRenamed(id, trimmed))
    }

    private func cancelTitleEdit() {
        editingTaskID = nil
    }

    // MARK: - Undo

    @ViewBuilder
    private var undoBannerContent: some View {
        if let completed = store.recentlyCompletedTask {
            undoBanner(
                systemImage: "checkmark.circle",
                message: String(localized: "Task completed"),
                action: { store.send(.undoCompleteTask) }
            )
        } else if let deleted = store.recentlyDeletedTask {
            undoBanner(
                systemImage: "trash",
                message: String(format: String(localized: "\"%@\" deleted"), deleted.title),
                action: { store.send(.undoDeleteTask) }
            )
        }
    }

    private func undoBanner(
        systemImage: String,
        message: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Button(String(localized: "Undo"), action: action)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            if reduceTransparency {
                RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous)
                    .fill(Color.pepinilloSecondarySystemGroupedBackground)
            } else {
                RoundedRectangle(cornerRadius: GlassCornerRadius.tile, style: .continuous)
                    .fill(.regularMaterial)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .padding(12)
    }

    // MARK: - Derived data

    private var filteredTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        let base: IdentifiedArrayOf<TaskListFeature.TaskItemState>
        switch filter {
        case .all:
            base = IdentifiedArrayOf(uniqueElements: store.tasks.filter {
                !$0.isRecurringTemplate && !$0.isCompleted
            })
        case .today:
            base = TaskListFeature.planFilteredTasks(store.tasks, filter: .today)
        case .upcoming:
            base = TaskListFeature.planFilteredTasks(store.tasks, filter: .upcoming)
        case .completed:
            base = TaskListFeature.planFilteredTasks(store.tasks, filter: .completed)
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching: IdentifiedArrayOf<TaskListFeature.TaskItemState>
        if query.isEmpty {
            matching = base
        } else {
            matching = IdentifiedArrayOf(uniqueElements: base.filter { task in
                task.title.localizedCaseInsensitiveContains(query)
                    || (task.notes?.localizedCaseInsensitiveContains(query) ?? false)
            })
        }

        return TaskListFeature.sortedPlanTasks(matching, sortOrder: store.sortOrder)
    }

    // MARK: - Drag reorder

    /// Dropping plain text from any app (Notes, Safari, Mail…) creates a task —
    /// a Mac gesture with no iOS equivalent. Row-level drops stay reorder-only:
    /// their payloads are UUID strings, which are filtered out here.
    private func createTaskFromDroppedText(_ items: [String]) -> Bool {
        let title = items.first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty, UUID(uuidString: title) == nil else { return false }
        store.send(.newTaskTitleChanged(String(title.prefix(200))))
        store.send(.addTaskTapped)
        return true
    }

    private func reorder(
        _ items: [String],
        at insertionIndex: Int,
        tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState>
    ) {
        let movingIDs = items.compactMap(UUID.init(uuidString:))
        guard !movingIDs.isEmpty else { return }

        let movingSet = Set(movingIDs)
        let source = tasks.map(\.id)
        let moving = source.filter { movingSet.contains($0) }
        guard !moving.isEmpty else { return }

        let boundedIndex = min(max(insertionIndex, 0), tasks.count)
        let insertionOffset = tasks[..<boundedIndex]
            .filter { !movingSet.contains($0.id) }
            .count

        var reordered = source.filter { !movingSet.contains($0) }
        reordered.insert(contentsOf: moving, at: min(insertionOffset, reordered.count))
        store.send(.planTasksReordered(reordered))
    }
}

// MARK: - Inline Title Cell

private struct MacTaskTitleCell: View {
    let store: StoreOf<TaskListFeature>
    let taskID: UUID
    @Binding var editingTaskID: UUID?
    @Binding var editingTitle: String
    let onCommit: (UUID) -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        if let task = store.tasks[id: taskID] {
            Group {
                if editingTaskID == taskID {
                    TextField(String(localized: "Title"), text: $editingTitle)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .focused($isFocused)
                        .onAppear { isFocused = true }
                        .onSubmit { onCommit(taskID) }
                        .onExitCommand { onCancel() }
                        .onChange(of: isFocused) { _, focused in
                            if !focused, editingTaskID == taskID {
                                onCommit(taskID)
                            }
                        }
                        .accessibilityLabel(String(localized: "Title"))
                } else {
                    Text(task.title)
                        .font(.body)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        }
    }
}

private struct MacTaskRowObserver<Content: View>: View {
    let store: StoreOf<TaskListFeature>
    let taskID: UUID
    let content: (TaskListFeature.TaskItemState) -> Content

    var body: some View {
        if let task = store.tasks[id: taskID] {
            content(task)
        }
    }
}
