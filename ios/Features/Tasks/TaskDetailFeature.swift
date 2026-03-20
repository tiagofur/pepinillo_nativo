// TaskDetailFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the task detail/edit sheet.
// Handles inline subtask management, field editing, and focus session linking.

import Foundation
import ComposableArchitecture

@Reducer
struct TaskDetailFeature {

    @ObservableState
    struct State: Equatable {
        let taskID: UUID
        let sortOrder: Int
        var title: String
        var notes: String
        var isCompleted: Bool
        var priority: TaskPriority
        var energyLevel: EnergyLevel
        var estimatedPomodoros: Int
        var completedPomodoros: Int
        var dueDate: Date?
        var scheduledForToday: Bool
        var recurrenceRule: String?
        var subtasks: IdentifiedArrayOf<SubtaskState> = []
        var newSubtaskTitle: String = ""
        var totalFocusSeconds: TimeInterval = 0
        var isLoading: Bool = false
        var isProUser: Bool = false
        var showDeleteConfirmation: Bool = false
        var showAllSubtasksCompletedPrompt: Bool = false
        @Presents var taskAnalytics: TaskAnalyticsFeature.State?

        struct SubtaskState: Equatable, Identifiable {
            let id: UUID
            var title: String
            var isCompleted: Bool
            var sortOrder: Int
        }

        init(from task: TaskListFeature.TaskItemState) {
            self.taskID = task.id
            self.sortOrder = task.sortOrder
            self.title = task.title
            self.notes = task.notes ?? ""
            self.isCompleted = task.isCompleted
            self.priority = task.priority
            self.energyLevel = task.energyLevel
            self.estimatedPomodoros = task.estimatedPomodoros
            self.completedPomodoros = task.completedPomodoros
            self.dueDate = task.dueDate
            self.scheduledForToday = task.scheduledForToday
            self.recurrenceRule = task.recurrenceRule
        }

        func toDTO() -> TaskItemDTO {
            TaskItemDTO(
                id: taskID,
                title: title,
                notes: notes.isEmpty ? nil : notes,
                isCompleted: isCompleted,
                priority: priority,
                energyLevel: energyLevel,
                estimatedPomodoros: estimatedPomodoros,
                completedPomodoros: completedPomodoros,
                sortOrder: sortOrder,
                subtasksCompleted: subtasks.filter(\.isCompleted).count,
                subtasksTotal: subtasks.count,
                recurrenceRule: recurrenceRule,
                isRecurringTemplate: recurrenceRule != nil,
                dueDate: dueDate,
                scheduledForToday: scheduledForToday
            )
        }
    }

    enum Action: Equatable {
        case onAppear
        case dataLoaded([SubTaskDTO], TimeInterval)

        // Field edits — each triggers an immediate save
        case titleChanged(String)
        case notesChanged(String)
        case priorityChanged(TaskPriority)
        case energyLevelChanged(EnergyLevel)
        case estimatedPomodorosChanged(Int)
        case dueDateChanged(Date?)
        case scheduledForTodayChanged(Bool)
        case recurrenceChanged(String?)
        case completionToggled

        // Subtasks
        case newSubtaskTitleChanged(String)
        case addSubtaskTapped
        case subtaskAdded(SubTaskDTO)
        case subtaskToggled(UUID)
        case subtaskDeleted(UUID)

        case allSubtasksCompletedPromptDismissed
        case allSubtasksCompletedConfirmed

        // Task Analytics
        case viewAnalyticsTapped
        case taskAnalytics(PresentationAction<TaskAnalyticsFeature.Action>)

        // Navigation / lifecycle
        case startFocusTapped
        case deleteTapped
        case deleteConfirmationDismissed
        case deleteConfirmed
        case dismissTapped

        // Delegate actions (handled by parent TaskListFeature)
        case delegate(Delegate)
        enum Delegate: Equatable {
            case startFocus(UUID, String)
            case taskDeleted(UUID)
        }
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case load }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                let id = state.taskID
                return .run { send in
                    async let subtaskDTOs = persistence.fetchSubtasks(id)
                    async let focusSeconds = persistence.fetchTaskTotalFocusSeconds(id)
                    let (subtasks, seconds) = try await (subtaskDTOs, focusSeconds)
                    await send(.dataLoaded(subtasks, seconds))
                }
                .cancellable(id: CancelID.load)

            case .dataLoaded(let subtaskDTOs, let focusSeconds):
                state.subtasks = IdentifiedArrayOf(uniqueElements: subtaskDTOs.map {
                    State.SubtaskState(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, sortOrder: $0.sortOrder)
                })
                state.totalFocusSeconds = focusSeconds
                state.isLoading = false
                return .none

            case .titleChanged(let title):
                state.title = title
                return save(state)

            case .notesChanged(let notes):
                state.notes = notes
                return save(state)

            case .priorityChanged(let priority):
                state.priority = priority
                return save(state)

            case .energyLevelChanged(let level):
                state.energyLevel = level
                return save(state)

            case .estimatedPomodorosChanged(let count):
                state.estimatedPomodoros = max(1, min(8, count))
                return save(state)

            case .dueDateChanged(let date):
                state.dueDate = date
                return save(state)

            case .scheduledForTodayChanged(let scheduled):
                state.scheduledForToday = scheduled
                return save(state)

            case .recurrenceChanged(let rule):
                // Recurrence is a Pro feature
                guard state.isProUser || rule == nil else { return .none }
                state.recurrenceRule = rule
                return save(state)

            case .completionToggled:
                state.isCompleted.toggle()
                return save(state)

            case .newSubtaskTitleChanged(let title):
                state.newSubtaskTitle = title
                return .none

            case .addSubtaskTapped:
                // Subtasks are a Pro feature
                guard state.isProUser else { return .none }
                let title = state.newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return .none }
                state.newSubtaskTitle = ""
                let id = state.taskID
                return .run { send in
                    let dto = try await persistence.addSubtask(id, title)
                    await send(.subtaskAdded(dto))
                }

            case .subtaskAdded(let dto):
                let subtaskState = State.SubtaskState(
                    id: dto.id, title: dto.title,
                    isCompleted: dto.isCompleted, sortOrder: dto.sortOrder
                )
                state.subtasks.append(subtaskState)
                return .none

            case .subtaskToggled(let id):
                state.subtasks[id: id]?.isCompleted.toggle()
                let allDone = !state.subtasks.isEmpty
                    && state.subtasks.allSatisfy(\.isCompleted)
                    && !state.isCompleted
                if allDone { state.showAllSubtasksCompletedPrompt = true }
                return .run { _ in try await persistence.toggleSubtask(id) }

            case .allSubtasksCompletedPromptDismissed:
                state.showAllSubtasksCompletedPrompt = false
                return .none

            case .allSubtasksCompletedConfirmed:
                state.showAllSubtasksCompletedPrompt = false
                state.isCompleted = true
                return save(state)

            case .subtaskDeleted(let id):
                state.subtasks.remove(id: id)
                return .run { _ in try await persistence.deleteSubtask(id) }

            case .viewAnalyticsTapped:
                state.taskAnalytics = TaskAnalyticsFeature.State(
                    taskID: state.taskID,
                    taskTitle: state.title
                )
                return .none

            case .taskAnalytics:
                return .none

            case .startFocusTapped:
                let taskID = state.taskID
                let title = state.title
                return .run { [dismiss] send in
                    await send(.delegate(.startFocus(taskID, title)))
                    await dismiss()
                }

            case .deleteTapped:
                state.showDeleteConfirmation = true
                return .none

            case .deleteConfirmationDismissed:
                state.showDeleteConfirmation = false
                return .none

            case .deleteConfirmed:
                let id = state.taskID
                return .run { send in
                    try await persistence.deleteTask(id)
                    await send(.delegate(.taskDeleted(id)))
                }

            case .dismissTapped:
                return .merge(
                    .cancel(id: CancelID.load),
                    .run { _ in await dismiss() }
                )

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$taskAnalytics, action: \.taskAnalytics) {
            TaskAnalyticsFeature()
        }
    }

    private func save(_ state: State) -> Effect<Action> {
        let dto = state.toDTO()
        return .run { _ in try await persistence.saveTask(dto) }
    }
}
