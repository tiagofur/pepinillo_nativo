// TaskListFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the task list screen.
// CRUD operations, filtering, sorting, subtask progress, and focus session linking.
// Persists all changes to SwiftData via PersistenceClient.

import Foundation
import ComposableArchitecture

@Reducer
struct TaskListFeature {

    @ObservableState
    struct State: Equatable {
        var tasks: IdentifiedArrayOf<TaskItemState> = []
        var isLoading: Bool = false
        var filter: TaskFilter = .today
        var energyFilter: EnergyFilter = .all
        var sortOrder: SortOrder = .custom
        var newTaskTitle: String = ""
        var importError: String?
        var selectedTaskID: UUID?
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
        case tasksLoaded([TaskItemState])
        case filterChanged(TaskFilter)
        case energyFilterChanged(EnergyFilter)
        case sortOrderChanged(SortOrder)
        case newTaskTitleChanged(String)
        case addTaskTapped
        case taskTapped(UUID)
        case taskCompleted(UUID)
        case taskDeleted(UUID)
        case taskMoved(IndexSet, Int)
        case energyLevelChanged(UUID, EnergyLevel)
        case recurrenceChanged(UUID, String?)
        case taskScheduledForToday(UUID, Bool)
        case startFocusOnTask(UUID)

        // Task detail sheet
        case detail(PresentationAction<TaskDetailFeature.Action>)

        // Reminders import
        case importFromRemindersTapped
        case remindersImported([TaskItemState])
        case remindersImportFailed(String)
        case importErrorDismissed
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.spotlightClient) var spotlight
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                return .run { send in
                    try await persistence.generateRecurringTasks()
                    let items = try await persistence.fetchTasks()
                    let states = items.map { TaskItemState.from($0) }
                    await send(.tasksLoaded(states))
                }

            case .tasksLoaded(let tasks):
                state.tasks = IdentifiedArrayOf(uniqueElements: tasks)
                state.isLoading = false
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
                    try? await spotlight.indexTasks(dtos)
                }

            case .filterChanged(let filter):
                state.filter = filter
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
                    dueDate: nil,
                    scheduledForToday: state.filter == .today,
                    sortOrder: sortOrder,
                    createdAt: now
                )
                state.tasks.append(newTask)
                state.newTaskTitle = ""

                return .run { _ in
                    let dto = TaskItemDTO(
                        id: newID,
                        title: title,
                        sortOrder: sortOrder,
                        scheduledForToday: newTask.scheduledForToday
                    )
                    try await persistence.saveTask(dto)
                }

            case .taskTapped(let id):
                guard let task = state.tasks[id: id] else { return .none }
                state.selectedTaskID = id
                state.detail = TaskDetailFeature.State(from: task)
                return .none

            case .taskCompleted(let id):
                state.tasks[id: id]?.isCompleted.toggle()
                let isNowCompleted = state.tasks[id: id]?.isCompleted ?? false
                return .run { _ in
                    let items = try await persistence.fetchTasks()
                    if let item = items.first(where: { $0.id == id }) {
                        let updated = TaskItemDTO(
                            id: item.id,
                            title: item.title,
                            notes: item.notes,
                            isCompleted: isNowCompleted,
                            priority: item.priority,
                            energyLevel: item.energyLevel,
                            estimatedPomodoros: item.estimatedPomodoros,
                            completedPomodoros: item.completedPomodoros,
                            sortOrder: item.sortOrder,
                            dueDate: item.dueDate,
                            scheduledForToday: item.scheduledForToday
                        )
                        try await persistence.saveTask(updated)
                    }
                }

            case .taskDeleted(let id):
                state.tasks.remove(id: id)
                return .run { [spotlight] _ in
                    try await persistence.deleteTask(id)
                    try? await spotlight.deindexTask(id)
                }

            case .taskMoved(let source, let destination):
                state.tasks.move(fromOffsets: source, toOffset: destination)
                let orderedIDs = state.tasks.ids
                return .run { _ in
                    let items = try await persistence.fetchTasks()
                    for (index, id) in orderedIDs.enumerated() {
                        if let item = items.first(where: { $0.id == id }) {
                            let updated = TaskItemDTO(
                                id: item.id, title: item.title, notes: item.notes,
                                isCompleted: item.isCompleted, priority: item.priority,
                                energyLevel: item.energyLevel,
                                estimatedPomodoros: item.estimatedPomodoros,
                                completedPomodoros: item.completedPomodoros,
                                sortOrder: index,
                                dueDate: item.dueDate,
                                scheduledForToday: item.scheduledForToday
                            )
                            try await persistence.saveTask(updated)
                        }
                    }
                }

            case .energyLevelChanged(let id, let level):
                state.tasks[id: id]?.energyLevel = level
                return .run { _ in
                    let items = try await persistence.fetchTasks()
                    if let item = items.first(where: { $0.id == id }) {
                        let updated = TaskItemDTO(
                            id: item.id, title: item.title, notes: item.notes,
                            isCompleted: item.isCompleted, priority: item.priority,
                            energyLevel: level, estimatedPomodoros: item.estimatedPomodoros,
                            completedPomodoros: item.completedPomodoros, sortOrder: item.sortOrder,
                            dueDate: item.dueDate, scheduledForToday: item.scheduledForToday
                        )
                        try await persistence.saveTask(updated)
                    }
                }

            case .recurrenceChanged(let id, let rule):
                state.tasks[id: id]?.recurrenceRule = rule
                state.tasks[id: id]?.isRecurringTemplate = rule != nil
                return .run { _ in
                    let items = try await persistence.fetchTasks()
                    if let item = items.first(where: { $0.id == id }) {
                        let updated = TaskItemDTO(
                            id: item.id, title: item.title, notes: item.notes,
                            isCompleted: item.isCompleted, priority: item.priority,
                            energyLevel: item.energyLevel, estimatedPomodoros: item.estimatedPomodoros,
                            completedPomodoros: item.completedPomodoros, sortOrder: item.sortOrder,
                            recurrenceRule: rule, isRecurringTemplate: rule != nil,
                            dueDate: item.dueDate, scheduledForToday: item.scheduledForToday
                        )
                        try await persistence.saveTask(updated)
                    }
                }

            case .taskScheduledForToday(let id, let scheduled):
                state.tasks[id: id]?.scheduledForToday = scheduled
                return .run { _ in
                    let items = try await persistence.fetchTasks()
                    if let item = items.first(where: { $0.id == id }) {
                        let updated = TaskItemDTO(
                            id: item.id, title: item.title, notes: item.notes,
                            isCompleted: item.isCompleted, priority: item.priority,
                            energyLevel: item.energyLevel, estimatedPomodoros: item.estimatedPomodoros,
                            completedPomodoros: item.completedPomodoros, sortOrder: item.sortOrder,
                            recurrenceRule: item.recurrenceRule, isRecurringTemplate: item.isRecurringTemplate,
                            dueDate: item.dueDate, scheduledForToday: scheduled
                        )
                        try await persistence.saveTask(updated)
                    }
                }

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
            }
        }
        .ifLet(\.$detail, action: \.detail) {
            TaskDetailFeature()
        }
    }
}
