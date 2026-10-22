// TaskDetailFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@MainActor
struct TaskDetailFeatureTests {

    private func detailState(taskID: UUID = UUID(0)) -> TaskDetailFeature.State {
        let task = TaskListFeature.TaskItemState(
            id: taskID,
            title: "Write docs",
            isCompleted: false,
            priority: .medium,
            energyLevel: .deep,
            estimatedPomodoros: 2,
            completedPomodoros: 0,
            subtaskProgress: .init(completed: 0, total: 0),
            recurrenceRule: nil,
            isRecurringTemplate: false,
            scheduledForToday: false,
            sortOrder: 0,
            createdAt: Date()
        )
        return TaskDetailFeature.State(from: task)
    }

    @Test("load failure clears spinner and surfaces error (#184)")
    func loadFailureShowsError() async {
        struct TestError: Error {}
        let taskID = UUID(0)

        let store = TestStore(initialState: detailState(taskID: taskID)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSubtasks = { _ in throw TestError() }
            $0.persistenceClient.fetchTaskTotalFocusSeconds = { _ in 0 }
            $0.persistenceClient.fetchSessionsForTask = { _ in [] }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.loadError = nil
        }

        await store.receive(\.loadFailed) {
            $0.isLoading = false
            $0.loadError = TestError().localizedDescription
        }
    }

    @Test("deleteConfirmed delegates to parent without persisting (#186)")
    func deleteConfirmedDelegatesToParent() async {
        let taskID = UUID(0)
        var state = detailState(taskID: taskID)
        state.showDeleteConfirmation = true

        let store = TestStore(initialState: state) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { _ in
                Issue.record("deleteTask should be handled by TaskListFeature")
            }
        }

        await store.send(.deleteConfirmed) {
            $0.showDeleteConfirmation = false
        }
        await store.receive(.delegate(.taskDeleted(taskID)))
    }

    @Test("title save failure rolls back and syncs parent (#189)")
    func titleSaveFailureRollsBack() async {
        struct TestError: Error {}
        let taskID = UUID(0)
        let state = detailState(taskID: taskID)

        let store = TestStore(initialState: state) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.saveTask = { _ in throw TestError() }
        }

        store.exhaustivity = .off
        await store.send(.titleChanged("Updated title")) {
            $0.title = "Updated title"
        }

        await store.receive(\.saveFailed) {
            $0.title = "Write docs"
            $0.mutationError = TestError().localizedDescription
        }
    }

    @Test("subtask toggle failure restores subtask state (#189)")
    func subtaskToggleFailureRollsBack() async {
        struct TestError: Error {}
        let taskID = UUID(0)
        let subtaskID = UUID(1)
        var state = detailState(taskID: taskID)
        state.subtasks = [
            .init(id: subtaskID, title: "Step 1", isCompleted: false, sortOrder: 0)
        ]

        let store = TestStore(initialState: state) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.toggleSubtask = { _ in throw TestError() }
        }

        await store.send(.subtaskToggled(subtaskID)) {
            $0.subtasks[id: subtaskID]?.isCompleted = true
            $0.showAllSubtasksCompletedPrompt = true
        }

        await store.receive(\.subtaskMutationFailed) {
            $0.subtasks[id: subtaskID]?.isCompleted = false
            $0.showAllSubtasksCompletedPrompt = false
            $0.mutationError = TestError().localizedDescription
        }
    }

    @Test("retryLoadTapped clears error and triggers reload (#184)")
    func retryLoadTappedClearsError() async {
        var state = detailState()
        state.loadError = "Network error"
        state.isLoading = false

        let store = TestStore(initialState: state) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSubtasks = { _ in [] }
            $0.persistenceClient.fetchTaskTotalFocusSeconds = { _ in 0 }
            $0.persistenceClient.fetchSessionsForTask = { _ in [] }
        }

        store.exhaustivity = .off
        await store.send(.retryLoadTapped) {
            $0.loadError = nil
        }
        await store.receive(\.dataLoaded)
    }

    @Test("onAppear loads linked focus sessions")
    func onAppearLoadsLinkedSessions() async {
        let taskID = UUID(0)
        let startedAt = Date(timeIntervalSince1970: 1_000_000)
        let session = SessionRecordDTO(
            id: UUID(1),
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(1_500),
            mode: "pomodoro",
            phase: "work",
            targetDuration: 1_500,
            actualDuration: 1_500,
            wasCompleted: true,
            interruptions: 0,
            taskID: taskID
        )

        let store = TestStore(initialState: detailState(taskID: taskID)) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSubtasks = { _ in [] }
            $0.persistenceClient.fetchTaskTotalFocusSeconds = { _ in 1_500 }
            $0.persistenceClient.fetchSessionsForTask = { _ in [session] }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
            $0.loadError = nil
        }

        await store.receive(\.dataLoaded) {
            $0.isLoading = false
            $0.totalFocusSeconds = 1_500
            $0.sessions = [session]
        }
    }

    @Test("add subtask failure restores title and surfaces error")
    func addSubtaskFailureRestoresTitle() async {
        struct AddError: Error {}
        let taskID = UUID()
        var state = detailState(taskID: taskID)
        state.isProUser = true
        state.newSubtaskTitle = "Buy milk"

        let store = TestStore(initialState: state) {
            TaskDetailFeature()
        } withDependencies: {
            $0.persistenceClient.addSubtask = { _, _ in throw AddError() }
        }
        store.exhaustivity = .off

        await store.send(.addSubtaskTapped) {
            $0.newSubtaskTitle = ""
        }
        // S1 RED pre-fix: the effect dies unhandled, nothing is ever received.
        await store.receive(\.subtaskAddFailed) {
            $0.newSubtaskTitle = "Buy milk"
            #expect($0.mutationError != nil)
        }
    }
}
