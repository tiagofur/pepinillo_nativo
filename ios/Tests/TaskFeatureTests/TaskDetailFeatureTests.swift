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
        }

        store.exhaustivity = .off
        await store.send(.retryLoadTapped) {
            $0.loadError = nil
        }
        await store.receive(\.dataLoaded)
    }
}