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
        /// Native macOS inline composer. The menu command and the Plan toolbar
        /// open it without presenting a sheet (S6).
        var isNewTaskComposerPresented: Bool = false
        /// Title captured by the iOS Share Extension (#669), parked until the
        /// list is loaded — a cold-start `tasksLoaded` would otherwise
        /// overwrite a task appended before it. `capturedTaskReady` adopts it
        /// when data is already on screen; `tasksLoaded` adopts it otherwise.
        var pendingCapturedTaskTitle: String?
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
        /// Most recent task completed from this window. Powers the macOS undo banner.
        var recentlyCompletedTask: TaskItemState?
        /// Most recent quick-add that recognized a natural-language date
        /// (#994 S4). Powers the «Quitar fecha» undo banner: clearing the
        /// date also puts the recognized text back into the title.
        var parsedDateUndo: ParsedDateUndo?
        var isProUser: Bool = false
        /// When true the task list renders sections by energy level.
        var isGroupedByEnergy: Bool = false
        /// Whether the time-of-day energy suggestion banner has been dismissed
        /// for this session. Resets on next cold launch.
        var energySuggestionDismissed: Bool = false
        @Presents var detail: TaskDetailFeature.State?
    }

    /// Rollback payload for the natural-date undo banner (#994 S4): the
    /// task whose plan must clear and the exact text the parser removed.
    struct ParsedDateUndo: Equatable {
        let taskID: UUID
        let originalTitle: String
    }

    struct TaskItemState: Equatable, Identifiable {
        let id: UUID
        var title: String
        var notes: String?
        var isCompleted: Bool
        var completedAt: Date? = nil
        var priority: TaskPriority
        var energyLevel: EnergyLevel
        var estimatedPomodoros: Int
        var completedPomodoros: Int
        var subtaskProgress: SubtaskProgress
        var recurrenceRule: String?
        var isRecurringTemplate: Bool
        var dueDate: Date?
        var scheduledForToday: Bool
        var plannedDate: Date?
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
                completedAt: dto.completedAt,
                priority: dto.priority,
                energyLevel: dto.energyLevel,
                estimatedPomodoros: dto.estimatedPomodoros,
                completedPomodoros: dto.completedPomodoros,
                subtaskProgress: SubtaskProgress(completed: dto.subtasksCompleted, total: dto.subtasksTotal),
                recurrenceRule: dto.recurrenceRule,
                isRecurringTemplate: dto.isRecurringTemplate,
                dueDate: dto.dueDate,
                scheduledForToday: dto.scheduledForToday,
                plannedDate: dto.plannedDate,
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
                plannedDate: plannedDate,
                completedAt: completedAt,
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
        /// Issue #990 (S4): tapping the suggestion filters the list to the level.
        case suggestedEnergyTapped(EnergyLevel)
        /// Issue #990 (S4): "Show all" clears the energy filter.
        case energyFilterCleared
        case sortOrderChanged(SortOrder)
        case newTaskTitleChanged(String)
        case newTaskRequested
        case newTaskComposerDismissed
        case addTaskTapped
        /// A Share-Extension capture landed in the app group (#669); adopt the
        /// parked title into the quick-add pipeline when the list can take it.
        case capturedTaskReady
        case taskTapped(UUID)
        case taskDetailDismissed
        case taskRenamed(UUID, String)
        case taskCompleted(UUID)
        /// Idempotent completion setter (watch bridge #243).
        case setTaskCompleted(UUID, Bool)
        case undoCompleteTask
        case completionUndoTimerExpired(UUID)
        case taskDeleted(UUID)
        case undoDeleteTask
        case undoTimerExpired(UUID)
        /// Undo the natural-date recognition on the last quick-add (#994 S4):
        /// clears the planned date and restores the original text.
        case undoParsedDateTask
        case parsedDateUndoTimerExpired(UUID)
        case taskMoved(IndexSet, Int)
        /// Reorder the visible native Plan table by the given task IDs. Unlike
        /// `taskMoved`, this does not depend on the shared sidebar filter.
        case planTasksReordered([UUID])
        case energyLevelChanged(UUID, EnergyLevel)
        case priorityChanged(UUID, TaskPriority)
        case recurrenceChanged(UUID, String?)
        case taskScheduledForToday(UUID, Bool)
        case taskPlannedDateChanged(UUID, Date?)
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

    private enum _UndoTimerID: Hashable {
        case undoTimer(UUID)
        case completionUndoTimer(UUID)
        case parsedDateUndo(UUID)
    }
    private enum _SpotlightIndexID: Hashable { case indexTasks }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.spotlightClient) var spotlight
    @Dependency(\.remindersClient) var remindersClient
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
                // #669: a Share-Extension capture parked before the first load
                // is created on top of the freshly loaded list.
                var capturedTaskEffect: Effect<Action> = .none
                if let captured = state.pendingCapturedTaskTitle,
                   !captured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.pendingCapturedTaskTitle = nil
                    state.newTaskTitle = Self.truncateCapturedTitle(captured)
                    capturedTaskEffect = .send(.addTaskTapped)
                }
                let dtos = tasks.map { task in
                    TaskItemDTO(
                        id: task.id, title: task.title, notes: task.notes,
                        isCompleted: task.isCompleted, priority: task.priority,
                        energyLevel: task.energyLevel, estimatedPomodoros: task.estimatedPomodoros,
                        completedPomodoros: task.completedPomodoros, sortOrder: task.sortOrder,
                        dueDate: task.dueDate, scheduledForToday: task.scheduledForToday,
                        plannedDate: task.plannedDate
                    )
                }
                return .merge(
                    capturedTaskEffect,
                    .run { [spotlight] _ in
                        try? await Task.sleep(for: .seconds(4))
                        try? await spotlight.indexTasks(dtos)
                    }
                    .cancellable(id: _SpotlightIndexID.indexTasks, cancelInFlight: true)
                )

            case .tasksLoadFailed(let message):
                state.isLoading = false
                state.loadError = message
                return .none

            case .filterChanged(let filter):
                state.filter = filter
                return .none

            case .planFilterSelected(let filter):
                state.selectedPlanFilter = filter
                // Issue #990: the energy suggestion/filter is a Today-scoped
                // interaction — switching pills clears it.
                state.energyFilter = .all
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

            case .suggestedEnergyTapped(let level):
                // Issue #990 (S4): the suggestion filters Hoy to its level.
                state.energyFilter = EnergyFilter(rawValue: level.rawValue) ?? .all
                return .none

            case .energyFilterCleared:
                state.energyFilter = .all
                return .none

            case .sortOrderChanged(let order):
                state.sortOrder = order
                return .none

            case .newTaskTitleChanged(let title):
                state.newTaskTitle = title
                return .none

            case .newTaskRequested:
                state.isNewTaskComposerPresented = true
                return .none

            case .newTaskComposerDismissed:
                state.isNewTaskComposerPresented = false
                state.newTaskTitle = ""
                return .none

            case .addTaskTapped:
                let title = state.newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return .none }

                // Free tier: max 3 active (non-completed, non-template) tasks (#216).
                // Premium (Pepinillo+ / Everywhere) is unlimited via isProUser.
                if !state.isProUser {
                    let activeCount = state.tasks.filter {
                        !$0.isCompleted && !$0.isRecurringTemplate
                    }.count
                    if activeCount >= Self.freeActiveTaskLimit {
                        return .send(.delegate(.showPaywall))
                    }
                }

                let newID = uuid()
                let sortOrder = state.tasks.count
                let now = date.now
                let quickAddDefaults = Self.planQuickAddDefaults(
                    for: state.selectedPlanFilter,
                    now: now
                )
                // #994: a natural-language date typed at the END of the text
                // replaces/refreshes the pill default; the recognized span
                // leaves the title and the undo banner can put it back (S4/S5).
                let parsed = NaturalDateParser.parse(title, now: now)
                let effectiveTitle = parsed.title.isEmpty ? title : parsed.title
                let plannedDate = parsed.plannedDate ?? quickAddDefaults.plannedDate
                let newTask = TaskItemState(
                    id: newID,
                    title: effectiveTitle,
                    isCompleted: false,
                    priority: .none,
                    energyLevel: .deep,
                    estimatedPomodoros: 1,
                    completedPomodoros: 0,
                    subtaskProgress: .init(completed: 0, total: 0),
                    recurrenceRule: nil,
                    isRecurringTemplate: false,
                    dueDate: quickAddDefaults.dueDate,
                    scheduledForToday: TaskPlanning.legacyFlag(
                        plannedDate: plannedDate, now: now
                    ),
                    plannedDate: plannedDate,
                    sortOrder: sortOrder,
                    createdAt: now
                )
                state.tasks.append(newTask)
                state.newTaskTitle = ""
                // The composer completes its action and collapses back to the
                // resting "+ New task" affordance (owner preference: one add
                // per interaction; the persistent collapsed row stays one
                // click away — Apple's Reminders instead keeps an always-
                // armed inline row, a different affordance model).
                state.isNewTaskComposerPresented = false
                if parsed.plannedDate != nil {
                    state.parsedDateUndo = ParsedDateUndo(taskID: newID, originalTitle: title)
                }

                var effects: [Effect<Action>] = [
                    .run { send in
                        let dto = TaskItemDTO(
                            id: newID,
                            title: effectiveTitle,
                            sortOrder: sortOrder,
                            dueDate: quickAddDefaults.dueDate,
                            scheduledForToday: TaskPlanning.legacyFlag(
                                plannedDate: plannedDate, now: now
                            ),
                            plannedDate: plannedDate,
                            createdAt: now
                        )
                        do {
                            try await persistence.saveTask(dto)
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        } catch {
                            await send(.mutationFailed(.addTask(
                                id: newID,
                                title: effectiveTitle,
                                message: error.localizedDescription
                            )))
                        }
                    }
                ]
                if parsed.plannedDate != nil {
                    effects.append(
                        .run { send in
                            try await Task.sleep(for: .seconds(5))
                            await send(.parsedDateUndoTimerExpired(newID))
                        }
                        .cancellable(id: _UndoTimerID.parsedDateUndo(newID), cancelInFlight: false)
                    )
                }
                return .merge(effects)

            // #669: Share-Extension capture. Loaded → adopt the parked title
            // through the same quick-add pipeline (cap → paywall keeps the
            // title, quick-add defaults, composer closes). Cold start → keep
            // it parked; `tasksLoaded` adopts it after the list lands.
            case .capturedTaskReady:
                guard let captured = state.pendingCapturedTaskTitle,
                      !captured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    state.pendingCapturedTaskTitle = nil
                    return .none
                }
                guard state.hasLoadedData else { return .none }
                state.pendingCapturedTaskTitle = nil
                state.newTaskTitle = Self.truncateCapturedTitle(captured)
                return .send(.addTaskTapped)

            case .taskTapped(let id):
                state.selectedTaskID = id
                // Double-clicking the row that is already open must not recreate
                // the detail state and discard its loaded subtasks/sessions.
                guard state.detail?.taskID != id else { return .none }

                // Sync current detail back to the list before swapping.
                if let currentDetail = state.detail {
                    state.tasks[id: currentDetail.taskID] = TaskItemState.from(currentDetail.toDTO())
                }

                guard let task = state.tasks[id: id] else { return .none }
                var detailState = TaskDetailFeature.State(from: task)
                detailState.isProUser = state.isProUser
                state.detail = detailState
                return .none

            case .taskDetailDismissed:
                state.detail = nil
                return .none

            case .taskRenamed(let id, let title):
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let snapshot = state.tasks[id: id],
                      !trimmed.isEmpty,
                      snapshot.title != trimmed else { return .none }

                state.tasks[id: id]?.title = trimmed
                if state.detail?.taskID == id {
                    state.detail?.title = trimmed
                }
                return .run { send in
                    do {
                        if let item = try await persistence.fetchTask(id) {
                            try await persistence.saveTask(item.updating(title: trimmed))
                            WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                        }
                    } catch {
                        await send(.mutationFailed(.update(
                            task: snapshot,
                            message: error.localizedDescription
                        )))
                    }
                }

            case .taskCompleted(let id):
                let isNowCompleted = !(state.tasks[id: id]?.isCompleted ?? false)
                return .send(.setTaskCompleted(id, isNowCompleted))

            case .setTaskCompleted(let id, let isCompleted):
                // `nil` means the task is not loaded in this window (widget/Siri
                // completion); the persistence effect below still applies it.
                guard state.tasks[id: id]?.isCompleted != isCompleted else { return .none }
                let wasCompleted = state.tasks[id: id]?.isCompleted ?? false
                let completedAt = isCompleted ? date.now : nil
                state.tasks[id: id]?.isCompleted = isCompleted
                state.tasks[id: id]?.completedAt = completedAt
                // Sync the detail column if it's currently showing this task
                if state.detail?.taskID == id {
                    state.detail?.isCompleted = isCompleted
                    state.detail?.completedAt = completedAt
                }

                let persist = Effect<Action>.run { send in
                    do {
                        // Single-row fetch instead of a full-table scan (issue #74).
                        if let item = try await persistence.fetchTask(id) {
                            let updated = item.updatingCompletion(isCompleted, at: completedAt)
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

                guard isCompleted else {
                    if state.recentlyCompletedTask?.id == id {
                        state.recentlyCompletedTask = nil
                    }
                    return persist
                }

                guard let completedTask = state.tasks[id: id] else {
                    // External completion for a task not loaded here: persist only.
                    return persist
                }
                state.recentlyCompletedTask = completedTask
                let dismissUndo = Effect<Action>.run { send in
                    try await Task.sleep(for: .seconds(5))
                    await send(.completionUndoTimerExpired(id))
                }
                .cancellable(id: _UndoTimerID.completionUndoTimer(id), cancelInFlight: false)

                return .merge(persist, dismissUndo)

            case .undoCompleteTask:
                guard let task = state.recentlyCompletedTask else { return .none }
                state.recentlyCompletedTask = nil
                state.tasks[id: task.id]?.isCompleted = false
                state.tasks[id: task.id]?.completedAt = nil
                if state.detail?.taskID == task.id {
                    state.detail?.isCompleted = false
                    state.detail?.completedAt = nil
                }

                return .merge(
                    .cancel(id: _UndoTimerID.completionUndoTimer(task.id)),
                    .run { send in
                        do {
                            if let item = try await persistence.fetchTask(task.id) {
                                try await persistence.saveTask(item.updatingCompletion(false, at: nil))
                                WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                            }
                        } catch {
                            await send(.mutationFailed(.complete(
                                id: task.id,
                                wasCompleted: true,
                                message: error.localizedDescription
                            )))
                        }
                    }
                )

            case .completionUndoTimerExpired(let id):
                if state.recentlyCompletedTask?.id == id {
                    state.recentlyCompletedTask = nil
                }
                return .none

            case .taskDeleted(let id):
                guard let task = state.tasks[id: id] else { return .none }
                state.recentlyDeletedTask = task
                state.tasks.remove(id: id)
                if state.recentlyCompletedTask?.id == id {
                    state.recentlyCompletedTask = nil
                }
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

            case .undoParsedDateTask:
                guard let undo = state.parsedDateUndo,
                      let snapshot = state.tasks[id: undo.taskID] else { return .none }
                let taskID = undo.taskID
                let originalTitle = undo.originalTitle
                let now = date.now
                state.tasks[id: taskID]?.title = originalTitle
                state.parsedDateUndo = nil
                return .merge(
                    .cancel(id: _UndoTimerID.parsedDateUndo(taskID)),
                    // Clears the planned date + re-derives the legacy flag
                    // and persists them (same seam as the row menu).
                    Self.persistPlannedDate(
                        id: taskID,
                        planned: nil,
                        now: now,
                        state: &state,
                        persistence: persistence
                    ),
                    .run { send in
                        do {
                            if let item = try await persistence.fetchTask(taskID) {
                                try await persistence.saveTask(item.updating(title: originalTitle))
                                WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                            }
                        } catch {
                            await send(.mutationFailed(.update(
                                task: snapshot,
                                message: error.localizedDescription
                            )))
                        }
                    }
                )

            case .parsedDateUndoTimerExpired(let id):
                if state.parsedDateUndo?.taskID == id {
                    state.parsedDateUndo = nil
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

            case .planTasksReordered(let orderedIDs):
                guard !orderedIDs.isEmpty else { return .none }
                let orderedSet = Set(orderedIDs)
                let currentTasks = state.tasks.filter { orderedSet.contains($0.id) }
                guard currentTasks.count == orderedIDs.count else { return .none }

                let previousTasks = state.tasks
                let sortOrders = currentTasks.map(\.sortOrder).sorted()
                for (index, id) in orderedIDs.enumerated() {
                    state.tasks[id: id]?.sortOrder = sortOrders[index]
                }
                state.tasks.sort { $0.sortOrder < $1.sortOrder }

                let order = state.tasks.map { (id: $0.id, sortOrder: $0.sortOrder) }
                return .run { send in
                    do {
                        try await persistence.saveTaskOrder(order)
                        WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
                    } catch {
                        await send(.mutationFailed(.reorder(
                            tasks: previousTasks,
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

            case .priorityChanged(let id, let priority):
                guard let snapshot = state.tasks[id: id], snapshot.priority != priority else { return .none }
                state.tasks[id: id]?.priority = priority
                return .run { send in
                    do {
                        if let item = try await persistence.fetchTask(id) {
                            let updated = item.updating(priority: priority)
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
                                dueDate: item.dueDate, scheduledForToday: item.scheduledForToday,
                                plannedDate: item.plannedDate
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
                // The list gesture stays the one-tap «Hoy» shortcut (S4): today's
                // plan or none — full-fidelity write via `updating` (issue #178).
                let today = TaskPlanning.plannedDay(date.now)
                return Self.persistPlannedDate(
                    id: id,
                    planned: scheduled ? today : nil,
                    now: date.now,
                    state: &state,
                    persistence: persistence
                )

            case .taskPlannedDateChanged(let id, let newDate):
                let planned = newDate.map { TaskPlanning.plannedDay($0) }
                return Self.persistPlannedDate(
                    id: id,
                    planned: planned,
                    now: date.now,
                    state: &state,
                    persistence: persistence
                )

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
                state.tasks[id: id]?.completedAt = isCompleted ? date.now : nil
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
                    do {
                        let items = try await persistence.fetchTasks()
                        let states = items.map { TaskItemState.from($0) }
                        await send(.tasksLoaded(states))
                    } catch {
                        await send(.tasksLoadFailed(error.localizedDescription))
                    }
                }

            case .detail:
                return .none

            // MARK: - Reminders Import

            case .importFromRemindersTapped:
                let baseActiveCount = state.tasks.filter {
                    !$0.isCompleted && !$0.isRecurringTemplate
                }.count
                // Free tier: same 3-active cap as manual adds (#216, S7).
                // Without this, imports bypassed the limit entirely.
                if !state.isProUser, baseActiveCount >= Self.freeActiveTaskLimit {
                    return .send(.delegate(.showPaywall))
                }
                let isProUser = state.isProUser
                return .run { [spotlight, remindersClient] send in
                    // Declared outside do so the catch below can surface partial
                    // progress (S7): rows saved before the failure are already
                    // persisted — dropping them from state hid them until reload.
                    var imported: [TaskItemState] = []
                    var skipped = 0
                    do {
                        let granted = try await remindersClient.requestAccess()
                        guard granted else {
                            await send(.remindersImportFailed("Reminders access denied"))
                            return
                        }
                        let reminders = try await remindersClient.fetchIncompleteReminders()
                        let existing = try await persistence.fetchTasks()
                        let maxSort = existing.map(\.sortOrder).max() ?? -1
                        var capped = false
                        var nextSort = maxSort + 1
                        for reminder in reminders {
                            let syncId = reminder.reminderSyncID
                            if try await persistence.fetchTaskBySyncId(syncId) != nil {
                                skipped += 1
                                continue
                            }
                            // Enforce the free-tier cap mid-run (S7).
                            if !isProUser, baseActiveCount + imported.count >= Self.freeActiveTaskLimit {
                                capped = true
                                break
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
                        if capped {
                            await send(.delegate(.showPaywall))
                        }
                        return
                    } catch {
                        if !imported.isEmpty {
                            await send(.remindersImported(imported: imported, skipped: skipped))
                        }
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
                    state.isNewTaskComposerPresented = true
                    state.mutationError = message

                case .complete(let id, let wasCompleted, let message):
                    state.tasks[id: id]?.isCompleted = wasCompleted
                    state.tasks[id: id]?.completedAt = wasCompleted ? date.now : nil
                    if state.recentlyCompletedTask?.id == id {
                        state.recentlyCompletedTask = nil
                    }
                    if state.detail?.taskID == id {
                        state.detail?.isCompleted = wasCompleted
                        state.detail?.completedAt = wasCompleted ? date.now : nil
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
                        state.detail?.title = task.title
                        state.detail?.energyLevel = task.energyLevel
                        state.detail?.priority = task.priority
                        state.detail?.recurrenceRule = task.recurrenceRule
                        state.detail?.scheduledForToday = task.scheduledForToday
                        state.detail?.plannedDate = task.plannedDate
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

    /// Free-tier cap for concurrent active tasks (issue #216). Premium is unlimited.
    /// Active = not completed and not a recurring template anchor.
    static let freeActiveTaskLimit = 3

    /// Share-Extension captures cap at the same length the Mac Quick Capture
    /// enforces (`MacQuickCaptureController.submit`), so a multi-KB selection
    /// cannot create an unbounded title (#669).
    static func truncateCapturedTitle(_ title: String) -> String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
    }

}

