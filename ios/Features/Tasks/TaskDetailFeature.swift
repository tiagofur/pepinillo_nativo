// TaskDetailFeature.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Reducer for the task detail/edit sheet.
// Handles inline subtask management, field editing, and focus session linking.

import Foundation
import ComposableArchitecture
import WidgetKit

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
        var loadError: String? = nil
        /// Persistence failure for optimistic field/subtask edits (#189).
        var mutationError: String? = nil
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
        case loadFailed(String)
        case retryLoadTapped
        case saveFailed(TaskItemDTO, String)
        case subtaskMutationFailed(State.SubtaskState, String)
        case mutationErrorDismissed

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
        case subtaskAddFailed(String, String)
        case subtaskToggled(UUID)
        case subtaskDeleted(UUID)

        case allSubtasksCompletedPromptDismissed
        case allSubtasksCompletedConfirmed

        case paywallTapped

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
            case taskCompletionChanged(UUID, Bool)
            case taskUpdated(TaskItemDTO)
            case showPaywall
        }
    }

    @Dependency(\.persistenceClient) var persistence
    @Dependency(\.dismiss) var dismiss

    private enum CancelID { case load, widgetReload }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.loadError = nil
                let id = state.taskID
                return .run { send in
                    do {
                        async let subtaskDTOs = persistence.fetchSubtasks(id)
                        async let focusSeconds = persistence.fetchTaskTotalFocusSeconds(id)
                        let (subtasks, seconds) = try await (subtaskDTOs, focusSeconds)
                        await send(.dataLoaded(subtasks, seconds))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.load)

            case .dataLoaded(let subtaskDTOs, let focusSeconds):
                state.subtasks = IdentifiedArrayOf(uniqueElements: subtaskDTOs.map {
                    State.SubtaskState(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, sortOrder: $0.sortOrder)
                })
                state.totalFocusSeconds = focusSeconds
                state.isLoading = false
                state.loadError = nil
                return .none

            case .loadFailed(let message):
                state.isLoading = false
                state.loadError = message
                return .none

            case .retryLoadTapped:
                state.loadError = nil
                return .send(.onAppear)

            case .saveFailed(let rollback, let message):
                applyRollback(&state, from: rollback)
                state.mutationError = message
                return .send(.delegate(.taskUpdated(rollback)))

            case .subtaskMutationFailed(let subtask, let message):
                state.subtasks[id: subtask.id] = subtask
                if !state.subtasks.allSatisfy(\.isCompleted) {
                    state.showAllSubtasksCompletedPrompt = false
                }
                state.mutationError = message
                return .none

            case .mutationErrorDismissed:
                state.mutationError = nil
                return .none

            case .titleChanged(let title):
                let rollback = state.toDTO()
                state.title = title
                return save(state, rollback: rollback)

            case .notesChanged(let notes):
                let rollback = state.toDTO()
                state.notes = notes
                return save(state, rollback: rollback)

            case .priorityChanged(let priority):
                let rollback = state.toDTO()
                state.priority = priority
                return save(state, rollback: rollback)

            case .energyLevelChanged(let level):
                let rollback = state.toDTO()
                state.energyLevel = level
                return save(state, rollback: rollback)

            case .estimatedPomodorosChanged(let count):
                let rollback = state.toDTO()
                state.estimatedPomodoros = max(1, min(8, count))
                return save(state, rollback: rollback)

            case .dueDateChanged(let date):
                let rollback = state.toDTO()
                state.dueDate = date
                return save(state, rollback: rollback)

            case .scheduledForTodayChanged(let scheduled):
                let rollback = state.toDTO()
                state.scheduledForToday = scheduled
                return save(state, rollback: rollback)

            case .recurrenceChanged(let rule):
                // Recurrence is a Pro feature
                if rule != nil && !state.isProUser {
                    return .send(.delegate(.showPaywall))
                }
                let rollback = state.toDTO()
                state.recurrenceRule = rule
                return save(state, rollback: rollback)

            case .completionToggled:
                let rollback = state.toDTO()
                state.isCompleted.toggle()
                let id = state.taskID
                let isCompleted = state.isCompleted
                return .merge(
                    save(state, rollback: rollback),
                    .send(.delegate(.taskCompletionChanged(id, isCompleted)))
                )

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
                    do {
                        let dto = try await persistence.addSubtask(id, title)
                        await send(.subtaskAdded(dto))
                    } catch {
                        await send(.subtaskAddFailed(title, error.localizedDescription))
                    }
                }

            case .subtaskAdded(let dto):
                let subtaskState = State.SubtaskState(
                    id: dto.id, title: dto.title,
                    isCompleted: dto.isCompleted, sortOrder: dto.sortOrder
                )
                state.subtasks.append(subtaskState)
                return .none

            case .subtaskAddFailed(let title, let message):
                // Restore the typed title so nothing the user wrote is lost,
                // and surface the error like other mutation failures (S1).
                state.newSubtaskTitle = title
                state.mutationError = message
                return .none

            case .subtaskToggled(let id):
                guard let subtask = state.subtasks[id: id] else { return .none }
                let snapshot = subtask
                state.subtasks[id: id]?.isCompleted.toggle()
                let allDone = !state.subtasks.isEmpty
                    && state.subtasks.allSatisfy(\.isCompleted)
                    && !state.isCompleted
                if allDone { state.showAllSubtasksCompletedPrompt = true }
                return .run { send in
                    do {
                        try await persistence.toggleSubtask(id)
                    } catch {
                        await send(.subtaskMutationFailed(snapshot, error.localizedDescription))
                    }
                }

            case .allSubtasksCompletedPromptDismissed:
                state.showAllSubtasksCompletedPrompt = false
                return .none

            case .allSubtasksCompletedConfirmed:
                let rollback = state.toDTO()
                state.showAllSubtasksCompletedPrompt = false
                state.isCompleted = true
                let allSubtasksID = state.taskID
                return .merge(
                    save(state, rollback: rollback),
                    .send(.delegate(.taskCompletionChanged(allSubtasksID, true)))
                )

            case .subtaskDeleted(let id):
                guard let subtask = state.subtasks[id: id] else { return .none }
                let snapshot = subtask
                state.subtasks.remove(id: id)
                return .run { send in
                    do {
                        try await persistence.deleteSubtask(id)
                    } catch {
                        await send(.subtaskMutationFailed(snapshot, error.localizedDescription))
                    }
                }

            case .paywallTapped:
                return .send(.delegate(.showPaywall))

            case .viewAnalyticsTapped:
                // Task analytics are a Pro feature
                guard state.isProUser else {
                    return .send(.delegate(.showPaywall))
                }
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
                state.showDeleteConfirmation = false
                let id = state.taskID
                // Persistence, undo, Spotlight, and widgets are handled by TaskListFeature.taskDeleted (#186).
                return .send(.delegate(.taskDeleted(id)))

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

    private func save(_ state: State, rollback: TaskItemDTO) -> Effect<Action> {
        let dto = state.toDTO()
        // Persist immediately (no data loss), but debounce the widget timeline
        // reload so rapid edits (e.g. typing in the title/notes field) don't
        // re-invoke the timeline provider in a separate process on every
        // keystroke (issue #77). cancelInFlight cancels any pending reload when
        // a new edit arrives, so only the last edit within ~1s triggers a reload.
        return .merge(
            .run { send in
                do {
                    try await persistence.saveTask(dto)
                } catch {
                    await send(.saveFailed(rollback, error.localizedDescription))
                }
            },
            .run { _ in
                try await Task.sleep(for: .seconds(1))
                WidgetCenter.shared.reloadTimelines(ofKind: "TasksHomeScreenWidget")
            }
            .cancellable(id: CancelID.widgetReload, cancelInFlight: true),
            .send(.delegate(.taskUpdated(dto)))
        )
    }

    private func applyRollback(_ state: inout State, from dto: TaskItemDTO) {
        state.title = dto.title
        state.notes = dto.notes ?? ""
        state.isCompleted = dto.isCompleted
        state.priority = dto.priority
        state.energyLevel = dto.energyLevel
        state.estimatedPomodoros = dto.estimatedPomodoros
        state.completedPomodoros = dto.completedPomodoros
        state.dueDate = dto.dueDate
        state.scheduledForToday = dto.scheduledForToday
        state.recurrenceRule = dto.recurrenceRule
    }
}
