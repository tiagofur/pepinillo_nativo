// PlanTaskList.swift
// Pepinillo — Deep Work Companion for Apple
//
// Content column of the Plan NavigationSplitView.
// Shows tasks filtered by the active PlanFilter.
// On iPhone (compact), this IS the full Plan screen (NavigationSplitView collapses).
// On iPad, this is the middle column; tapping a task sets selectedTaskID and
// opens TaskDetailView in the detail column instead of pushing a sheet.

import SwiftUI
import ComposableArchitecture

struct PlanTaskList: View {
    @Bindable var store: StoreOf<TaskListFeature>
    let filter: PlanFilter
    var showsTitle: Bool = true
    var heroNamespace: Namespace.ID? = nil
    @State private var collapsedSections: Set<PlanFilter> = []
    @State private var taskToDelete: UUID?
    @State private var quickAddExpanded: Bool = false
    @FocusState private var quickAddFocused: Bool

    // MARK: - Filtered tasks

    private var filteredTasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> {
        let filtered = TaskListFeature.planFilteredTasks(store.tasks, filter: filter)
        return TaskListFeature.sortedPlanTasks(filtered, sortOrder: store.sortOrder)
    }

    // MARK: - Body

    var body: some View {
        taskListContent
        .navigationTitle(showsTitle ? filter.title : "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section(String(localized: "Sort by")) {
                        ForEach(TaskListFeature.SortOrder.allCases, id: \.self) { order in
                            Button { store.send(.sortOrderChanged(order)) } label: {
                                if store.sortOrder == order {
                                    Label(order.displayName, systemImage: "checkmark")
                                } else {
                                    Text(order.displayName)
                                }
                            }
                        }
                    }
                    Section(String(localized: "View")) {
                        Button {
                            store.send(.groupByEnergyToggled)
                            HapticManager.selection()
                        } label: {
                            if store.isGroupedByEnergy {
                                Label(String(localized: "Ungroup by Energy"), systemImage: "checkmark.square")
                            } else {
                                Label(String(localized: "Group by Energy"), systemImage: "bolt.square")
                            }
                        }
                    }
                    Divider()
                    Button {
                        store.send(.importFromRemindersTapped)
                    } label: {
                        Label(String(localized: "Import from Reminders"), systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Label(String(localized: "More options"), systemImage: "ellipsis")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: SpacingTokens.sm) {
            VStack(spacing: SpacingTokens.sm) {
                if let deletedTask = store.recentlyDeletedTask {
                    undoBanner(taskTitle: deletedTask.title)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                addTaskBar
            }
            .animation(MotionTokens.snappy, value: store.recentlyDeletedTask != nil)
        }
        .onAppear { store.send(.onAppear) }
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
        // Separate alert for DB load failures — distinct from Reminders import
        // errors. Previously both surfaced under "Import Failed" (issue #88).
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
        .alert(
            String(localized: "Import Complete"),
            isPresented: Binding(
                get: { store.importSummary != nil },
                set: { if !$0 { store.send(.importSummaryDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.importSummaryDismissed) }
        } message: {
            Text(store.importSummary ?? "")
        }
    }

    // MARK: - Task List Content

    @ViewBuilder
    private var taskListContent: some View {
        // Compute the filtered list ONCE per body evaluation (issue #81).
        // Previously `filteredTasks` was a computed property read ~7 times,
        // each re-running the full filter over every task.
        let tasks = filteredTasks
        if store.isLoading {
            ProgressView()
                .frame(maxHeight: .infinity)
        } else if tasks.isEmpty {
            PepinilloEmptyState(
                title: emptyTitle,
                description: emptyDescription,
                systemImage: filter.systemImage,
                tint: filter.color
            )
            .padding(.horizontal, SpacingTokens.md)
            .frame(maxHeight: .infinity)
        } else if store.isGroupedByEnergy {
            // Energy-grouped mode: sections by level, reorder disabled across sections
            EnergyGroupedTaskList(
                store: store,
                filteredTasks: tasks,
                currentDate: Date.now
            )
        } else {
            // Flat list mode (existing behaviour, reordering intact)
            let taskIDs = tasks.map(\.id)
            List {
                ForEach(tasks) { task in
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
                        },
                        onPaywallTapped: { store.send(.paywallRequested) },
                        isProUser: store.isProUser
                    )
                    .equatable()  // Skip re-render when `task` is unchanged (issue #81)
                    .modifier(OptionalMatchedSource(id: task.id, namespace: heroNamespace))
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
                        .tint(task.scheduledForToday ? Color.pepinilloTertiaryLabel : .green)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        taskToDelete = tasks[index].id
                        store.send(.taskDeleted(tasks[index].id))
                    }
                }
                .onMove { source, destination in
                    store.send(.taskMoved(source, destination))
                }
            }
            #if os(macOS)
            .listStyle(.inset)
            #else
            .listStyle(.plain)
            #endif
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .primaryScrollEdgeEffect()
            .conditionalAnimation(.smooth(duration: 0.3), value: taskIDs)
            .refreshable { store.send(.refresh) }
        }
    }

    // MARK: - Empty State Helpers

    private var emptyTitle: String {
        switch filter {
        case .today:     return String(localized: "plan.empty.today.title", defaultValue: "Nothing for Today")
        case .inbox:     return String(localized: "plan.empty.inbox.title", defaultValue: "Inbox Clear")
        case .upcoming:  return String(localized: "plan.empty.upcoming.title", defaultValue: "Nothing Upcoming")
        case .completed: return String(localized: "plan.empty.completed.title", defaultValue: "No Completed Tasks")
        }
    }

    private var emptyDescription: String {
        switch filter {
        case .today:
            return String(localized: "plan.empty.today.description",
                          defaultValue: "Capture what matters — add a task below to plan your day.")
        case .inbox:
            return String(localized: "plan.empty.inbox.description",
                          defaultValue: "All captured tasks are organized. Enjoy the calm.")
        case .upcoming:
            return String(localized: "plan.empty.upcoming.description",
                          defaultValue: "No deadlines on the horizon. Focus on what matters today.")
        case .completed:
            return String(localized: "plan.empty.completed.description",
                          defaultValue: "Complete a task and your wins will show up here.")
        }
    }

    // MARK: - Quick-Add Row (minimal expanding)

    private var addTaskBar: some View {
        Group {
            if quickAddExpanded {
                // Expanded: inline text field + submit button pinned to keyboard
                HStack(spacing: 10) {
                    TextField(
                        String(localized: "New task"),
                        text: Binding(
                            get: { store.newTaskTitle },
                            set: { store.send(.newTaskTitleChanged($0)) }
                        )
                    )
                    .textFieldStyle(.plain)
                    .submitLabel(.done)
                    .focused($quickAddFocused)
                    .onSubmit {
                        store.send(.addTaskTapped)
                        collapseQuickAdd()
                    }

                    if !store.newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            HapticManager.impact(.light)
                            store.send(.addTaskTapped)
                            collapseQuickAdd()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Add new task"))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, SpacingTokens.md)
                .padding(.vertical, SpacingTokens.base)
                .pepinilloGlass(cornerRadius: GlassCornerRadius.card)
                .padding(.horizontal, SpacingTokens.md)
            } else {
                // Collapsed: minimal plus + label row
                Button {
                    withAnimation(MotionTokens.snappy) { quickAddExpanded = true }
                    quickAddFocused = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)
                        Text(String(localized: "New task"))
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, SpacingTokens.lg)
                    .padding(.vertical, SpacingTokens.base)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Add a new task"))
            }
        }
        .conditionalAnimation(MotionTokens.snappy, value: quickAddExpanded)
        .onChange(of: quickAddFocused) { _, focused in
            if !focused && store.newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                withAnimation(MotionTokens.snappy) { quickAddExpanded = false }
            }
        }
    }

    private func collapseQuickAdd() {
        withAnimation(MotionTokens.snappy) { quickAddExpanded = false }
        quickAddFocused = false
    }

    // MARK: - Undo Banner

    private func undoBanner(taskTitle: String) -> some View {
        HStack(spacing: SpacingTokens.base) {
            Image(systemName: "trash")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: String(localized: "\"%@\" deleted"), taskTitle))
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
        .padding(.horizontal, SpacingTokens.md)
        .padding(.vertical, SpacingTokens.base)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.tile)
        .pepinilloShadow(.raised)
        .padding(.horizontal, SpacingTokens.md)
    }

}

// MARK: - Hero transition helpers (iOS 18+)

/// Applies .matchedTransitionSource when a namespace is available and iOS 18+ is running.
/// Used on task rows in PlanTaskList so they can zoom-morph into the detail sheet.
private struct OptionalMatchedSource: ViewModifier {
    let id: AnyHashable
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *), let ns = namespace {
            content.matchedTransitionSource(id: id, in: ns)
        } else {
            content
        }
    }
}
