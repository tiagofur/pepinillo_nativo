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
        /// Success summary after Reminders import (#187).
        var importSummary: String?
        /// Separate error for DB load failures (issue #88) — previously conflated
        /// with `importError`, which surfaced as a misleading "Import Failed" alert
        /// for generic fetch errors.
        var loadError: String?
        /// Optimistic mutation persistence failures (#189). Separate from load/import
        /// errors so a failed toggle doesn't masquerade as a load failure.
        var mutationError: String?
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

        func toDTO() -> TaskItemDTO {
            TaskItemDTO(
                id: id,
                title: title,
                notes: notes,
                isCompleted: isCompleted,
                priority: priority,
                energyLevel: energyLevel,
                estimatedPomodoros: estimatedPomodoros,
                completedPomodoros: completedPomodoros,
                sortOrder: sortOrder,
                recurrenceRule: recurrenceRule,
                isRecurringTemplate: isRecurringTemplate,
                dueDate: dueDate,
                scheduledForToday: scheduledForToday,
                createdAt: createdAt
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
        /// Idempotent completion setter (watch bridge #243).
        case setTaskCompleted(UUID, Bool)
        case taskDeleted(UUID)
        case undoDeleteTask
        case undoTimerExpired(UUID)
        case taskMoved(IndexSet, Int)
        case energyLevelChanged(UUID, EnergyLevel)
        case recurrenceChanged(UUID, String?)
        case taskScheduledForToday(UUID, Bool)
        case startFocusOnTask(UUID)
        case groupByEnergyToggled
        case energySuggestionDismissed
        case paywallRequested

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
        case remindersImported(imported: [TaskItemState], skipped: Int)
        case importSummaryDismissed
        case remindersImportFailed(String)
        case importErrorDismissed
        case loadErrorDismissed
        case mutationFailed(MutationFailure)
        case mutationErrorDismissed
    }

    /// Rollback payload for optimistic mutations that failed to persist (#189).
    enum MutationFailure: Equatable {
        case addTask(id: UUID, title: String, message: String)
        case complete(id: UUID, wasCompleted: Bool, message: String)
        case delete(task: TaskItemState, message: String)
        case undoDelete(task: TaskItemState, message: String)
        case reorder(tasks: IdentifiedArrayOf<TaskItemState>, message: String)
        case update(task: TaskItemState, message: String)
    }

    private enum _UndoTimerID: Hashable { case undoTimer(UUID) }
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
                    do {
                        try await persistence.saveTask(dto)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    } catch {
                        await send(.mutationFailed(.addTask(
                            id: newID,
                            title: title,
                            message: error.localizedDescription
                        )))
                    }
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
                let isNowCompleted = !(state.tasks[id: id]?.isCompleted ?? false)
                return .send(.setTaskCompleted(id, isNowCompleted))

            case .setTaskCompleted(let id, let isCompleted):
                guard state.tasks[id: id]?.isCompleted != isCompleted else { return .none }
                let wasCompleted = state.tasks[id: id]?.isCompleted ?? false
                state.tasks[id: id]?.isCompleted = isCompleted
                // Sync the detail column if it's currently showing this task
                if state.detail?.taskID == id {
                    state.detail?.isCompleted = isCompleted
                }
                return .run { send in
                    do {
                        // Single-row fetch instead of a full-table scan (issue #74).
                        if let item = try await persistence.fetchTask(id) {
                            let updated = item.updating(isCompleted: isCompleted)
                            try await persistence.saveTask(updated)
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        }
                    } catch {
                        await send(.mutationFailed(.complete(
                            id: id,
                            wasCompleted: wasCompleted,
                            message: error.localizedDescription
                        )))
                    }
                }

            case .taskDeleted(let id):
                guard let task = state.tasks[id: id] else { return .none }
                state.recentlyDeletedTask = task
                state.tasks.remove(id: id)
                if state.detail?.taskID == id {
                    state.detail = nil
                    state.selectedTaskID = nil
                }
                // Soft-delete immediately (issue #183). The undo timer only dismisses the
                // banner; it must not be the sole persistence path — cancelInFlight on a
                // single timer dropped earlier deletes when another task was removed.
                return .merge(
                    .run { [spotlight] send in
                        do {
                            try await persistence.deleteTask(id)
                            try? await spotlight.deindexTask(id)
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        } catch {
                            await send(.mutationFailed(.delete(
                                task: task,
                                message: error.localizedDescription
                            )))
                        }
                    },
                    .run { send in
                        try await Task.sleep(for: .seconds(5))
                        await send(.undoTimerExpired(id))
                    }
                    .cancellable(id: _UndoTimerID.undoTimer(id), cancelInFlight: false)
                )

            case .undoDeleteTask:
                guard let task = state.recentlyDeletedTask else { return .none }
                let taskID = task.id
                state.tasks.append(task)
                state.recentlyDeletedTask = nil
                return .merge(
                    .cancel(id: _UndoTimerID.undoTimer(taskID)),
                    .run { send in
                        do {
                            try await persistence.restoreTask(task.toDTO())
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        } catch {
                            await send(.mutationFailed(.undoDelete(
                                task: task,
                                message: error.localizedDescription
                            )))
                        }
                    }
                )

            case .undoTimerExpired(let id):
                if state.recentlyDeletedTask?.id == id {
                    state.recentlyDeletedTask = nil
                }
                return .none

            case .taskMoved(let source, let destination):
                // PlanTaskList drag indices refer to the active Plan filter subset,
                // not the full task array (issue #179).
                let tasksSnapshot = state.tasks
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
                return .run { send in
                    do {
                        // Batch the reorder in a single transaction instead of N
                        // sequential saveTask round-trips (issue #74).
                        try await persistence.saveTaskOrder(order)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    } catch {
                        await send(.mutationFailed(.reorder(
                            tasks: tasksSnapshot,
                            message: error.localizedDescription
                        )))
                    }
                }

            case .energyLevelChanged(let id, let level):
                guard let snapshot = state.tasks[id: id] else { return .none }
                state.tasks[id: id]?.energyLevel = level
                return .run { send in
                    do {
                        if let item = try await persistence.fetchTask(id) {
                            let updated = item.updating(energyLevel: level)
                            try await persistence.saveTask(updated)
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        }
                    } catch {
                        await send(.mutationFailed(.update(
                            task: snapshot,
                            message: error.localizedDescription
                        )))
                    }
                }

            case .recurrenceChanged(let id, let rule):
                // Recurrence is a Pro feature (issue #181) — match TaskDetailFeature guard.
                if rule != nil && !state.isProUser {
                    return .send(.delegate(.showPaywall))
                }
                guard let snapshot = state.tasks[id: id] else { return .none }
                state.tasks[id: id]?.recurrenceRule = rule
                state.tasks[id: id]?.isRecurringTemplate = rule != nil
                return .run { send in
                    do {
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
                    } catch {
                        await send(.mutationFailed(.update(
                            task: snapshot,
                            message: error.localizedDescription
                        )))
                    }
                }

            case .taskScheduledForToday(let id, let scheduled):
                guard let snapshot = state.tasks[id: id] else { return .none }
                state.tasks[id: id]?.scheduledForToday = scheduled
                return .run { send in
                    do {
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
                    } catch {
                        await send(.mutationFailed(.update(
                            task: snapshot,
                            message: error.localizedDescription
                        )))
                    }
                }

            case .groupByEnergyToggled:
                state.isGroupedByEnergy.toggle()
                return .none

            case .energySuggestionDismissed:
                state.energySuggestionDismissed = true
                return .none

            case .paywallRequested:
                return .send(.delegate(.showPaywall))

            case .startFocusOnTask:
                // Handled by AppFeature to switch tabs + link task
                return .none

            // MARK: - Task Detail

            case .detail(.presented(.delegate(.startFocus(let id, _)))):
                state.detail = nil
                return .send(.startFocusOnTask(id))

            case .detail(.presented(.delegate(.taskDeleted(let id)))):
                return .send(.taskDeleted(id))

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
                return .run { [spotlight] send in
                    let service = RemindersImportService()
                    do {
                        let granted = try await service.requestAccess()
                        guard granted else {
                            await send(.remindersImportFailed("Reminders access denied"))
                            return
                        }
                        let reminders = try await service.fetchIncompleteReminders()
                        let existing = try await persistence.fetchTasks()
                        let maxSort = existing.map(\.sortOrder).max() ?? -1
                        var imported: [TaskItemState] = []
                        var skipped = 0
                        var nextSort = maxSort + 1
                        for reminder in reminders {
                            let syncId = reminder.reminderSyncID
                            if try await persistence.fetchTaskBySyncId(syncId) != nil {
                                skipped += 1
                                continue
                            }
                            let dto = reminder.toTaskItemDTO(
                                sortOrder: nextSort,
                                syncId: syncId
                            )
                            nextSort += 1
                            try await persistence.saveTask(dto)
                            imported.append(TaskItemState.from(dto))
                        }
                        if !imported.isEmpty {
                            try? await spotlight.indexTasks(imported.map { $0.toDTO() })
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        }
                        await send(.remindersImported(imported: imported, skipped: skipped))
                    } catch {
                        await send(.remindersImportFailed(error.localizedDescription))
                    }
                }

            case .remindersImported(let newTasks, let skipped):
                for task in newTasks {
                    if state.tasks[id: task.id] == nil {
                        state.tasks.append(task)
                    }
                }
                if newTasks.isEmpty && skipped == 0 {
                    state.importSummary = String(localized: "No new reminders to import.")
                } else if skipped == 0 {
                    state.importSummary = String(localized: "Imported \(newTasks.count) reminders.")
                } else {
                    state.importSummary = String(
                        localized: "Imported \(newTasks.count) reminders. Skipped \(skipped) duplicates."
                    )
                }
                return .none

            case .importSummaryDismissed:
                state.importSummary = nil
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

            case .mutationFailed(let failure):
                switch failure {
                case .addTask(let id, let title, let message):
                    state.tasks.remove(id: id)
                    state.newTaskTitle = title
                    state.mutationError = message

                case .complete(let id, let wasCompleted, let message):
                    state.tasks[id: id]?.isCompleted = wasCompleted
                    if state.detail?.taskID == id {
                        state.detail?.isCompleted = wasCompleted
                    }
                    state.mutationError = message

                case .delete(let task, let message):
                    if state.tasks[id: task.id] == nil {
                        state.tasks.append(task)
                    }
                    state.recentlyDeletedTask = task
                    state.mutationError = message

                case .undoDelete(let task, let message):
                    state.tasks.remove(id: task.id)
                    state.recentlyDeletedTask = task
                    state.mutationError = message

                case .reorder(let tasks, let message):
                    state.tasks = tasks
                    state.mutationError = message

                case .update(let task, let message):
                    state.tasks[id: task.id] = task
                    if state.detail?.taskID == task.id {
                        state.detail?.energyLevel = task.energyLevel
                        state.detail?.recurrenceRule = task.recurrenceRule
                        state.detail?.scheduledForToday = task.scheduledForToday
                    }
                    state.mutationError = message
                }
                return .none

            case .mutationErrorDismissed:
                state.mutationError = nil
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
    /// Applies the Plan sort menu to a filtered task list (#185).
    static func sortedPlanTasks(
        _ tasks: IdentifiedArrayOf<TaskItemState>,
        sortOrder: SortOrder
    ) -> IdentifiedArrayOf<TaskItemState> {
        let sorted = tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            switch sortOrder {
            case .custom:
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            case .priority:
                if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            case .dueDate:
                switch (lhs.dueDate, rhs.dueDate) {
                case (nil, nil): break
                case (nil, _): return false
                case (_, nil): return true
                case let (l?, r?) where l != r: return l < r
                default: break
                }
            case .energy:
                let lIdx = energySortIndex(lhs.energyLevel)
                let rIdx = energySortIndex(rhs.energyLevel)
                if lIdx != rIdx { return lIdx < rIdx }
            case .created:
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            return lhs.sortOrder < rhs.sortOrder
        }
        return IdentifiedArrayOf(uniqueElements: sorted)
    }

    private static func energySortIndex(_ level: EnergyLevel) -> Int {
        switch level {
        case .deep: return 0
        case .shallow: return 1
        case .admin: return 2
        }
    }

    static func planFilteredTasks(
        _ tasks: IdentifiedArrayOf<TaskItemState>,
        filter: PlanFilter,
        now: Date = .now
    ) -> IdentifiedArrayOf<TaskItemState> {
        // Recurring templates are series anchors — instances appear in Plan lists (#188).
        let visible = tasks.filter { !$0.isRecurringTemplate }
        let cal = Calendar.current
        switch filter {
        case .today:
            let startOfToday = cal.startOfDay(for: now)
            return visible.filter { task in
                guard !task.isCompleted else { return false }
                if task.scheduledForToday { return true }
                guard let due = task.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: now) || due < startOfToday
            }
        case .inbox:
            return visible.filter { !$0.isCompleted && !$0.scheduledForToday && $0.dueDate == nil }
        case .upcoming:
            let startOfToday = cal.startOfDay(for: now)
            return visible.filter { task in
                guard !task.isCompleted, !task.scheduledForToday, let due = task.dueDate else { return false }
                // All future dues (strictly after today). Issue #182: tasks due beyond 7 days
                // were invisible because Upcoming capped at one week.
                return due > startOfToday && !cal.isDate(due, inSameDayAs: now)
            }
        case .completed:
            return visible.filter { $0.isCompleted }
        }
    }
}
