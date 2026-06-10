// TaskListFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for TaskListFeature: CRUD operations, filtering.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@MainActor
struct TaskListFeatureTests {

    @Test func addTaskAppendsToList() async {
        let testID = UUID(0)
        let testDate = Date(timeIntervalSince1970: 1_000_000)

        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { _ in }
            $0.uuid = .constant(testID)
            $0.date = .constant(testDate)
        }

        await store.send(.newTaskTitleChanged("Buy groceries")) {
            $0.newTaskTitle = "Buy groceries"
        }

        store.exhaustivity = .off

        await store.send(.addTaskTapped) {
            $0.newTaskTitle = ""
            $0.tasks.append(TaskListFeature.TaskItemState(
                id: testID,
                title: "Buy groceries",
                isCompleted: false,
                priority: .none,
                energyLevel: .deep,
                estimatedPomodoros: 1,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false,
                scheduledForToday: false,
                sortOrder: 0,
                createdAt: testDate
            ))
        }
    }

    @Test func addTaskWithEmptyTitleDoesNothing() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.newTaskTitleChanged("   ")) {
            $0.newTaskTitle = "   "
        }

        // Whitespace-only title should be ignored
        await store.send(.addTaskTapped)
        // No state change expected
    }

    @Test func completeTaskTogglesCompletion() async {
        var initialState = TaskListFeature.State()
        let taskID = UUID()
        initialState.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Write tests",
                isCompleted: false,
                priority: .none,
                energyLevel: .deep,
                estimatedPomodoros: 2,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false, scheduledForToday: false, sortOrder: 0, createdAt: Date()
            )
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.taskCompleted(taskID)) {
            $0.tasks[id: taskID]?.isCompleted = true
        }
    }

    @Test func deleteTaskRemovesFromList() async {
        var initialState = TaskListFeature.State()
        let taskID = UUID()
        initialState.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Task to delete",
                isCompleted: false,
                priority: .none,
                energyLevel: .deep,
                estimatedPomodoros: 1,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false, scheduledForToday: false, sortOrder: 0, createdAt: Date()
            )
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { _ in }
            $0.spotlightClient.deindexTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.taskDeleted(taskID)) {
            $0.tasks = []
        }
    }

    @Test func filterChangeUpdatesState() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.filterChanged(.completed)) {
            $0.filter = .completed
        }
    }

    // MARK: - Energy Levels

    @Test func newTaskDefaultsToDeepEnergyLevel() async {
        let testID = UUID(0)
        let testDate = Date(timeIntervalSince1970: 1_000_000)

        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { _ in }
            $0.uuid = .constant(testID)
            $0.date = .constant(testDate)
        }

        await store.send(.newTaskTitleChanged("Deep Work Task")) {
            $0.newTaskTitle = "Deep Work Task"
        }

        store.exhaustivity = .off

        await store.send(.addTaskTapped) {
            $0.newTaskTitle = ""
            $0.tasks.append(TaskListFeature.TaskItemState(
                id: testID,
                title: "Deep Work Task",
                isCompleted: false,
                priority: .none,
                energyLevel: .deep,
                estimatedPomodoros: 1,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false,
                scheduledForToday: false,
                sortOrder: 0,
                createdAt: testDate
            ))
        }
    }

    @Test func energyLevelChangedUpdatesTask() async {
        var initialState = TaskListFeature.State()
        let taskID = UUID()
        initialState.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Flexible Task",
                isCompleted: false,
                priority: .none,
                energyLevel: .deep,
                estimatedPomodoros: 1,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false, scheduledForToday: false, sortOrder: 0, createdAt: Date()
            )
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.energyLevelChanged(taskID, .shallow)) {
            $0.tasks[id: taskID]?.energyLevel = .shallow
        }
    }

    @Test func energyFilterChangedUpdatesState() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.energyFilterChanged(.deep)) {
            $0.energyFilter = .deep
        }

        await store.send(.energyFilterChanged(.shallow)) {
            $0.energyFilter = .shallow
        }

        await store.send(.energyFilterChanged(.all)) {
            $0.energyFilter = .all
        }
    }

    @Test func defaultEnergyFilterIsAll() {
        let state = TaskListFeature.State()
        #expect(state.energyFilter == .all)
    }

    @Test func energyFilterCanBeChangedToAdmin() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.energyFilterChanged(.admin)) {
            $0.energyFilter = .admin
        }
    }

    // MARK: - Energy Grouping

    @Test func defaultGroupingIsFalse() {
        let state = TaskListFeature.State()
        #expect(state.isGroupedByEnergy == false)
    }

    @Test func defaultSuggestionDismissedIsFalse() {
        let state = TaskListFeature.State()
        #expect(state.energySuggestionDismissed == false)
    }

    @Test func groupByEnergyToggledEnablesGrouping() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.groupByEnergyToggled) {
            $0.isGroupedByEnergy = true
        }
    }

    @Test func groupByEnergyToggledTogglesBack() async {
        var initial = TaskListFeature.State()
        initial.isGroupedByEnergy = true

        let store = TestStore(initialState: initial) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.groupByEnergyToggled) {
            $0.isGroupedByEnergy = false
        }
    }

    @Test func energySuggestionDismissedSetsFlag() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
        }

        await store.send(.energySuggestionDismissed) {
            $0.energySuggestionDismissed = true
        }
    }

    @Test func energyLevelChangedThenChangedAgain() async {
        var initialState = TaskListFeature.State()
        let taskID = UUID()
        initialState.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Multi-Level Task",
                isCompleted: false,
                priority: .medium,
                energyLevel: .deep,
                estimatedPomodoros: 2,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false, scheduledForToday: false, sortOrder: 0, createdAt: Date()
            )
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.energyLevelChanged(taskID, .admin)) {
            $0.tasks[id: taskID]?.energyLevel = .admin
        }

        await store.send(.energyLevelChanged(taskID, .deep)) {
            $0.tasks[id: taskID]?.energyLevel = .deep
        }
    }
}
