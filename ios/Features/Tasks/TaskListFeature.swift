// TaskListFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the task list screen.
// CRUD operations, filtering, sorting, subtask progress, and focus session linking.
// Persists all changes to SwiftData via PersistenceClient.

import Foundation
import ComposableArchitecture
import WidgetKit

@Reducer
struct TaskListFeature {

    @ObservableState
    struct State: Equatable {
        var tasks: IdentifiedArrayOf<TaskItemState> = []
        var isLoading: Bool = false
        /// True after the first successful task load. Guards the passive
        /// `.onAppear` so tab switches don't refetch + regenerate recurring tasks.
        var hasLoadedData: Bool = false
        var filter: TaskFilter = .today
        var energyFilter: EnergyFilter = .all
        var sortOrder: SortOrder = .custom
        var newTaskTitle: String = ""
        var importError: String?
        /// Separate error for DB load failures (issue #88) — previously conflated
        /// with `importError`, which surfaced as a misleading "Import Failed" alert
        /// for generic fetch errors.
        var loadError: String?
        var selectedTaskID: UUID?
        var selectedPlanFilter: PlanFilter = .today
        var recentlyDeletedTask: TaskItemState?
        var isProUser: Bool = false
        /// When true the task list renders sections by energy level.
        var isGroupedByEnergy: Bool = false
        /// Whether the time-of-day energy suggestion banner has been dismissed
        /// for this session. Resets on next cold launch.
        var energySuggestionDismissed: Bool = false
        @Presents var detail: TaskDetailFeature.State?
    }

    struct TaskItemState: Equatable, Identifiable {
        let id: UUID
        var title: String
        var notes: String?
        var isCompleted: Bool
        var priority: TaskPriority
        var energyLevel: EnergyLevel
        var estimatedPomodoros: Int
        var completedPomodoros: Int
        var subtaskProgress: SubtaskProgress
        var recurrenceRule: String?
        var isRecurringTemplate: Bool
        var dueDate: Date?
        var scheduledForToday: Bool
        var sortOrder: Int
        var createdAt: Date

        struct SubtaskProgress: Equatable {
            let completed: Int
            let total: Int
        }

        static func from(_ dto: TaskItemDTO) -> TaskItemState {
            TaskItemState(
                id: dto.id,
                title: dto.title,
                notes: dto.notes,
                isCompleted: dto.isCompleted,
                priority: dto.priority,
                energyLevel: dto.energyLevel,
                estimatedPomodoros: dto.estimatedPomodoros,
                completedPomodoros: dto.completedPomodoros,
                subtaskProgress: SubtaskProgress(completed: dto.subtasksCompleted, total: dto.subtasksTotal),
                recurrenceRule: dto.recurrenceRule,
                isRecurringTemplate: dto.isRecurringTemplate,
                dueDate: dto.dueDate,
                scheduledForToday: dto.scheduledForToday,
                sortOrder: dto.sortOrder,
                createdAt: dto.createdAt
            )
        }
    }

    enum TaskFilter: String, CaseIterable, Equatable {
        case today, active, completed, all

        var displayName: String {
            switch self {
            case .today:     return String(localized: "Today")
            case .active:    return String(localized: "Active")
            case .completed: return String(localized: "Done")
            case .all:       return String(localized: "All")
            }
        }
    }

    enum EnergyFilter: String, CaseIterable, Equatable {
        case all, deep, shallow, admin

        var displayName: String {
            switch self {
            case .all:     return String(localized: "All")
            case .deep:    return String(localized: "Deep")
            case .shallow: return String(localized: "Shallow")
            case .admin:   return String(localized: "Admin")
            }
        }

        var energyLevel: EnergyLevel? {
            switch self {
            case .all:     return nil
            case .deep:    return .deep
            case .shallow: return .shallow
            case .admin:   return .admin
            }
        }
    }

    enum SortOrder: String, CaseIterable, Equatable {
        case custom    // Manual drag
        case priority  // High → None
        case dueDate   // Soonest first (nil = last)
        case energy    // Deep → Admin
        case created   // Newest first

        var displayName: String {
            switch self {
            case .custom:   return String(localized: "Custom")
            case .priority: return String(localized: "Priority")
            case .dueDate:  return String(localized: "Due Date")
            case .energy:   return String(localized: "Energy")
            case .created:  return String(localized: "Newest")
            }
        }

        var icon: String {
            switch self {
            case .custom:   return "list.bullet"
            case .priority: return "flag"
            case .dueDate:  return "calendar"
            case .energy:   return "bolt"
            case .created:  return "clock"
            }
        }
    }

    enum Action: Equatable {
        case onAppear
        case refresh
        case tasksLoaded([TaskItemState])
        case tasksLoadFailed(String)
        case filterChanged(TaskFilter)
        case planFilterSelected(PlanFilter)
        case energyFilterChanged(EnergyFilter)
        case sortOrderChanged(SortOrder)
        case newTaskTitleChanged(String)
        case addTaskTapped
        case taskTapped(UUID)
        case taskCompleted(UUID)
        case taskDeleted(UUID)
        case undoDeleteTask
        case undoTimerExpired
        case taskMoved(IndexSet, Int)
        case energyLevelChanged(UUID, EnergyLevel)
        case recurrenceChanged(UUID, String?)
        case taskScheduledForToday(UUID, Bool)
        case startFocusOnTask(UUID)
        case groupByEnergyToggled
        case energySuggestionDismissed

        // Delegation
        case delegate(Delegate)
        enum Delegate: Equatable {
            case startFocus(UUID, String)
            case taskDeleted(UUID)
            case taskCompletionChanged(UUID, Bool)
            case showPaywall
        }

        // Task detail sheet
        case detail(PresentationAction<TaskDetailFeature.Action>)

        // Reminders import
        case importFromRemindersTapped
        case remindersImported([TaskItemState])
        case remindersImportFailed(String)
        case importErrorDismissed
        case loadErrorDismissed
    }

    private enum _UndoTimerID: Hashable { case undoTimer }
    private enum _SpotlightIndexID: Hashable { case indexTasks }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.spotlightClient) var spotlight
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                // Passive appearance (tab switch / re-entry): load only once.
                // Explicit reloads (pull-to-refresh, detail dismiss, session
                // completed) bypass this guard via their own actions.
                guard !state.isLoading, !state.hasLoadedData else { return .none }
                state.isLoading = true
                return .run { send in
                    do {
                        // First load: generate recurring instances once, then a
                        // single fetch (previously fetched twice back-to-back).
                        try await persistence.generateRecurringTasks()
                        let items = try await persistence.fetchTasks()
                        let states = items.map { TaskItemState.from($0) }
                        await send(.tasksLoaded(states))
                    } catch {
                        await send(.tasksLoadFailed(error.localizedDescription))
                    }
                }

            case .refresh:
                // Explicit user-initiated reload (pull-to-refresh). Always runs.
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .run { send in
                    do {
                        try await persistence.generateRecurringTasks()
                        let items = try await persistence.fetchTasks()
                        let states = items.map { TaskItemState.from($0) }
                        await send(.tasksLoaded(states))
                    } catch {
                        await send(.tasksLoadFailed(error.localizedDescription))
                    }
                }

            case .tasksLoaded(let tasks):
                state.tasks = IdentifiedArrayOf(uniqueElements: tasks)
                state.isLoading = false
                state.hasLoadedData = true
                let dtos = tasks.map { task in
                    TaskItemDTO(
                        id: task.id, title: task.title, notes: task.notes,
                        isCompleted: task.isCompleted, priority: task.priority,
                        energyLevel: task.energyLevel, estimatedPomodoros: task.estimatedPomodoros,
                        completedPomodoros: task.completedPomodoros, sortOrder: task.sortOrder,
                        dueDate: task.dueDate, scheduledForToday: task.scheduledForToday
                    )
                }
                return .run { [spotlight] _ in
                    try? await Task.sleep(for: .seconds(4))
                    try? await spotlight.indexTasks(dtos)
                }
                .cancellable(id: _SpotlightIndexID.indexTasks, cancelInFlight: true)

            case .tasksLoadFailed(let message):
                state.isLoading = false
                state.loadError = message
                return .none

            case .filterChanged(let filter):
                state.filter = filter
                return .none

            case .planFilterSelected(let filter):
                state.selectedPlanFilter = filter
                // Clear detail column selection when switching filters
                if let currentDetail = state.detail {
                    state.tasks[id: currentDetail.taskID] = TaskItemState.from(currentDetail.toDTO())
                    state.detail = nil
                    state.selectedTaskID = nil
                }
                return .none

            case .energyFilterChanged(let filter):
                state.energyFilter = filter
                return .none

            case .sortOrderChanged(let order):
                state.sortOrder = order
                return .none

            case .newTaskTitleChanged(let title):
                state.newTaskTitle = title
                return .none

            case .addTaskTapped:
                let title = state.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return .none }

                let newID = uuid()
                let sortOrder = state.tasks.count
                let now = date.now
                let quickAddDefaults = Self.planQuickAddDefaults(
                    for: state.selectedPlanFilter,
                    now: now
                )
                let newTask = TaskItemState(
                    id: newID,
                    title: title,
                    isCompleted: false,
                    priority: .none,
                    energyLevel: .deep,
                    estimatedPomodoros: 1,
                    completedPomodoros: 0,
                    subtaskProgress: .init(completed: 0, total: 0),
                    recurrenceRule: nil,
                    isRecurringTemplate: false,
                    dueDate: quickAddDefaults.dueDate,
                    scheduledForToday: quickAddDefaults.scheduledForToday,
                    sortOrder: sortOrder,
                    createdAt: now
                )
                state.tasks.append(newTask)
                state.newTaskTitle = ""

                return .run { send in
                    let dto = TaskItemDTO(
                        id: newID,
                        title: title,
                        sortOrder: sortOrder,
                        dueDate: quickAddDefaults.dueDate,
                        scheduledForToday: quickAddDefaults.scheduledForToday,
                        createdAt: now
                    )
                    try await persistence.saveTask(dto)
                    WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                }

            case .taskTapped(let id):
                // Sync current detail back to the list before swapping
                if let currentDetail = state.detail {
                    state.tasks[id: currentDetail.taskID] = TaskItemState.from(currentDetail.toDTO())
                }
                
                guard let task = state.tasks[id: id] else { return .none }
                state.selectedTaskID = id
                var detailState = TaskDetailFeature.State(from: task)
                detailState.isProUser = state.isProUser
                state.detail = detailState
                return .none

            case .taskCompleted(let id):
                state.tasks[id: id]?.isCompleted.toggle()
                let isNowCompleted = state.tasks[id: id]?.isCompleted ?? false
                // Sync the detail column if it's currently showing this task
                if state.detail?.taskID == id {
                    state.detail?.isCompleted = isNowCompleted
                }
                return .run { _ in
                    // Single-row fetch instead of a full-table scan (issue #74).
                    if let item = try await persistence.fetchTask(id) {
                        let updated = item.updating(isCompleted: isNowCompleted)
                        try await persistence.saveTask(updated)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    }
                }

            case .taskDeleted(let id):
                guard let task = state.tasks[id: id] else { return .none }
                state.recentlyDeletedTask = task
                state.tasks.remove(id: id)
                return .run { send in
                    try await Task.sleep(for: .seconds(5))
                    await send(.undoTimerExpired)
                }
                .cancellable(id: _UndoTimerID.undoTimer, cancelInFlight: true)

            case .undoDeleteTask:
                if let task = state.recentlyDeletedTask {
                    state.tasks.append(task)
                }
                state.recentlyDeletedTask = nil
                return .cancel(id: _UndoTimerID.undoTimer)

            case .undoTimerExpired:
                guard let task = state.recentlyDeletedTask else { return .none }
                let taskID = task.id
                state.recentlyDeletedTask = nil
                return .run { [spotlight] _ in
                    try await persistence.deleteTask(taskID)
                    try? await spotlight.deindexTask(taskID)
                    WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                }

            case .taskMoved(let source, let destination):
                // PlanTaskList drag indices refer to the active Plan filter subset,
                // not the full task array (issue #179).
                let now = date.now
                var filtered = Self.planFilteredTasks(
                    state.tasks,
                    filter: state.selectedPlanFilter,
                    now: now
                )
                guard !filtered.isEmpty else { return .none }

                let sortOrders = filtered.map(\.sortOrder)
                filtered.move(fromOffsets: source, toOffset: destination)

                for (index, id) in filtered.ids.enumerated() {
                    state.tasks[id: id]?.sortOrder = sortOrders[index]
                }
                state.tasks.sort { $0.sortOrder < $1.sortOrder }

                let order = state.tasks.map { (id: $0.id, sortOrder: $0.sortOrder) }
                return .run { _ in
                    // Batch the reorder in a single transaction instead of N
                    // sequential saveTask round-trips (issue #74).
                    try await persistence.saveTaskOrder(order)
                    WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                }

            case .energyLevelChanged(let id, let level):
                state.tasks[id: id]?.energyLevel = level
                return .run { _ in
                    if let item = try await persistence.fetchTask(id) {
                        let updated = item.updating(energyLevel: level)
                        try await persistence.saveTask(updated)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    }
                }

            case .recurrenceChanged(let id, let rule):
                state.tasks[id: id]?.recurrenceRule = rule
                state.tasks[id: id]?.isRecurringTemplate = rule != nil
                return .run { _ in
                    if let item = try await persistence.fetchTask(id) {
                        let updated = TaskItemDTO(
                            id: item.id, title: item.title, notes: item.notes,
                            isCompleted: item.isCompleted, priority: item.priority,
                            energyLevel: item.energyLevel, estimatedPomodoros: item.estimatedPomodoros,
                            completedPomodoros: item.completedPomodoros, sortOrder: item.sortOrder,
                            recurrenceRule: rule, isRecurringTemplate: rule != nil,
                            dueDate: item.dueDate, scheduledForToday: item.scheduledForToday
                        )
                        try await persistence.saveTask(updated)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    }
                }

            case .taskScheduledForToday(let id, let scheduled):
                state.tasks[id: id]?.scheduledForToday = scheduled
                return .run { _ in
                    if let item = try await persistence.fetchTask(id) {
                        let updated = TaskItemDTO(
                            id: item.id, title: item.title, notes: item.notes,
                            isCompleted: item.isCompleted, priority: item.priority,
                            energyLevel: item.energyLevel, estimatedPomodoros: item.estimatedPomodoros,
                            completedPomodoros: item.completedPomodoros, sortOrder: item.sortOrder,
                            recurrenceRule: item.recurrenceRule, isRecurringTemplate: item.isRecurringTemplate,
                            dueDate: item.dueDate, scheduledForToday: scheduled
                        )
                        try await persistence.saveTask(updated)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    }
                }

            case .groupByEnergyToggled:
                state.isGroupedByEnergy.toggle()
                return .none

            case .energySuggestionDismissed:
                state.energySuggestionDismissed = true
                return .none

            case .startFocusOnTask:
                // Handled by AppFeature to switch tabs + link task
                return .none

            // MARK: - Task Detail

            case .detail(.presented(.delegate(.startFocus(let id, _)))):
                state.detail = nil
                return .send(.startFocusOnTask(id))

            case .detail(.presented(.delegate(.taskDeleted(let id)))):
                state.tasks.remove(id: id)
                state.detail = nil
                return .none

            case .detail(.presented(.delegate(.taskCompletionChanged(let id, let isCompleted)))):
                // Detail is the source of truth — sync the list row
                state.tasks[id: id]?.isCompleted = isCompleted
                return .none

            case .detail(.presented(.delegate(.taskUpdated(let dto)))):
                // Sync any change from the detail back to the list row
                state.tasks[id: dto.id] = TaskItemState.from(dto)
                return .none

            case .detail(.presented(.delegate(.showPaywall))):
                return .send(.delegate(.showPaywall))

            case .detail(.dismiss):
                // Reload to reflect all changes made in the detail sheet
                return .run { send in
                    let items = try await persistence.fetchTasks()
                    let states = items.map { TaskItemState.from($0) }
                    await send(.tasksLoaded(states))
                }

            case .detail:
                return .none

            // MARK: - Reminders Import

            case .importFromRemindersTapped:
                return .run { send in
                    let service = RemindersImportService()
                    do {
                        let granted = try await service.requestAccess()
                        guard granted else {
                            await send(.remindersImportFailed("Reminders access denied"))
                            return
                        }
                        let reminders = try await service.fetchIncompleteReminders()
                        var imported: [TaskItemState] = []
                        for (index, reminder) in reminders.enumerated() {
                            let dto = reminder.toTaskItemDTO(sortOrder: index)
                            try await persistence.saveTask(dto)
                            imported.append(TaskItemState.from(dto))
                        }
                        await send(.remindersImported(imported))
                    } catch {
                        await send(.remindersImportFailed(error.localizedDescription))
                    }
                }

            case .remindersImported(let newTasks):
                for task in newTasks {
                    if state.tasks[id: task.id] == nil {
                        state.tasks.append(task)
                    }
                }
                return .none

            case .remindersImportFailed(let message):
                state.importError = message
                return .none

            case .importErrorDismissed:
                state.importError = nil
                return .none

            case .loadErrorDismissed:
                state.loadError = nil
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            TaskDetailFeature()
        }
    }

    /// Default scheduling fields for Plan quick-add based on the active filter (issue #180).
    static func planQuickAddDefaults(
        for filter: PlanFilter,
        now: Date = .now
    ) -> (scheduledForToday: Bool, dueDate: Date?) {
        let cal = Calendar.current
        switch filter {
        case .today:
            return (true, nil)
        case .inbox, .completed:
            return (false, nil)
        case .upcoming:
            let startOfToday = cal.startOfDay(for: now)
            let dueDate = cal.date(byAdding: .day, value: 1, to: startOfToday)
            return (false, dueDate)
        }
    }

    /// Tasks visible for a Plan sidebar filter. Shared by PlanTaskList and
    /// `taskMoved` so drag indices map to the same subset (issue #179).
    static func planFilteredTasks(
        _ tasks: IdentifiedArrayOf<TaskItemState>,
        filter: PlanFilter,
        now: Date = .now
    ) -> IdentifiedArrayOf<TaskItemState> {
        let cal = Calendar.current
        switch filter {
        case .today:
            let startOfToday = cal.startOfDay(for: now)
            return tasks.filter { task in
                guard !task.isCompleted else { return false }
                if task.scheduledForToday { return true }
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due) || due < startOfToday
            }
        case .inbox:
            return tasks.filter { !$0.isCompleted && !$0.scheduledForToday && $0.dueDate == nil }
        case .upcoming:
            let startOfToday = cal.startOfDay(for: now)
            let weekFromNow = cal.date(byAdding: .day, value: 7, to: now) ?? now
            return tasks.filter { task in
                guard !task.isCompleted, !task.scheduledForToday, let due = task.dueDate else { return false }
                return due > startOfToday && !cal.isDateInToday(due) && due <= weekFromNow
            }
        case .completed:
            return tasks.filter { $0.isCompleted }
        }
    }
}
