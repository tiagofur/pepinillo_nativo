// TaskListFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for TaskListFeature: CRUD operations, filtering.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

private func recurringTaskDTO(
    id: UUID,
    rule: String = RecurrencePreset.weekly.rawValue
) -> TaskItemDTO {
    TaskItemDTO(
        id: id,
        title: "Recurring Task",
        isCompleted: false,
        energyLevel: .deep,
        recurrenceRule: rule,
        isRecurringTemplate: true
    )
}

private func basicTaskDTO(
    id: UUID,
    title: String = "Task",
    isCompleted: Bool = false,
    energyLevel: EnergyLevel = .deep
) -> TaskItemDTO {
    TaskItemDTO(
        id: id,
        title: title,
        isCompleted: isCompleted,
        energyLevel: energyLevel
    )
}

private func recurringTaskState(id: UUID) -> TaskListFeature.TaskItemState {
    TaskListFeature.TaskItemState(
        id: id,
        title: "Recurring Task",
        isCompleted: false,
        priority: .none,
        energyLevel: .deep,
        estimatedPomodoros: 1,
        completedPomodoros: 0,
        subtaskProgress: .init(completed: 0, total: 0),
        recurrenceRule: RecurrencePreset.weekly.rawValue,
        isRecurringTemplate: true,
        scheduledForToday: false,
        sortOrder: 0,
        createdAt: Date()
    )
}

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
            $0.persistenceClient.fetchTask = { _ in basicTaskDTO(id: taskID, title: "Write tests") }
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
            $0.persistenceClient.fetchTask = { _ in basicTaskDTO(id: taskID, title: "Flexible Task") }
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
            $0.persistenceClient.fetchTask = { _ in basicTaskDTO(id: taskID, title: "Multi-Level Task") }
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

    // MARK: - Recurrence Preservation (issue #178)

    @Test func completeTaskPreservesRecurrenceOnSave() async throws {
        let taskID = UUID()
        let fetchedTask = recurringTaskDTO(id: taskID)
        let savedTask = LockIsolated<TaskItemDTO?>(nil)

        var initialState = TaskListFeature.State()
        initialState.tasks = [recurringTaskState(id: taskID)]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in fetchedTask }
            $0.persistenceClient.saveTask = { savedTask.setValue($0) }
        }

        store.exhaustivity = .off

        await store.send(.taskCompleted(taskID)) {
            $0.tasks[id: taskID]?.isCompleted = true
        }

        let saved = try #require(savedTask.value)
        #expect(saved.isCompleted == true)
        #expect(saved.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(saved.isRecurringTemplate == true)
    }

    @Test func completeTaskPreservesRecurrenceAfterReload() async {
        let taskID = UUID()
        let persistedTask = LockIsolated(recurringTaskDTO(id: taskID))

        var initialState = TaskListFeature.State()
        initialState.tasks = [recurringTaskState(id: taskID)]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in persistedTask.value }
            $0.persistenceClient.saveTask = { persistedTask.setValue($0) }
            $0.persistenceClient.fetchTasks = { [persistedTask] in [persistedTask.value] }
            $0.persistenceClient.generateRecurringTasks = { }
        }

        store.exhaustivity = .off

        await store.send(.taskCompleted(taskID)) {
            $0.tasks[id: taskID]?.isCompleted = true
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }

        let reloadedState = TaskListFeature.TaskItemState.from(persistedTask.value)
        await store.receive(.tasksLoaded([reloadedState])) {
            $0.tasks = IdentifiedArrayOf(uniqueElements: [reloadedState])
            $0.isLoading = false
            $0.hasLoadedData = true
        }

        #expect(persistedTask.value.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(persistedTask.value.isRecurringTemplate == true)
        #expect(store.state.tasks[id: taskID]?.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(store.state.tasks[id: taskID]?.isRecurringTemplate == true)
    }

    @Test func energyLevelChangedPreservesRecurrenceOnSave() async throws {
        let taskID = UUID()
        let fetchedTask = recurringTaskDTO(id: taskID)
        let savedTask = LockIsolated<TaskItemDTO?>(nil)

        var initialState = TaskListFeature.State()
        initialState.tasks = [recurringTaskState(id: taskID)]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in fetchedTask }
            $0.persistenceClient.saveTask = { savedTask.setValue($0) }
        }

        store.exhaustivity = .off

        await store.send(.energyLevelChanged(taskID, .shallow)) {
            $0.tasks[id: taskID]?.energyLevel = .shallow
        }

        let saved = try #require(savedTask.value)
        #expect(saved.energyLevel == .shallow)
        #expect(saved.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(saved.isRecurringTemplate == true)
    }

    @Test func energyLevelChangedPreservesRecurrenceAfterReload() async {
        let taskID = UUID()
        let persistedTask = LockIsolated(recurringTaskDTO(id: taskID))

        var initialState = TaskListFeature.State()
        initialState.tasks = [recurringTaskState(id: taskID)]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in persistedTask.value }
            $0.persistenceClient.saveTask = { persistedTask.setValue($0) }
            $0.persistenceClient.fetchTasks = { [persistedTask] in [persistedTask.value] }
            $0.persistenceClient.generateRecurringTasks = { }
        }

        store.exhaustivity = .off

        await store.send(.energyLevelChanged(taskID, .admin)) {
            $0.tasks[id: taskID]?.energyLevel = .admin
        }

        await store.send(.refresh) {
            $0.isLoading = true
        }

        let reloadedState = TaskListFeature.TaskItemState.from(persistedTask.value)
        await store.receive(.tasksLoaded([reloadedState])) {
            $0.tasks = IdentifiedArrayOf(uniqueElements: [reloadedState])
            $0.isLoading = false
            $0.hasLoadedData = true
        }

        #expect(persistedTask.value.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(persistedTask.value.isRecurringTemplate == true)
        #expect(store.state.tasks[id: taskID]?.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(store.state.tasks[id: taskID]?.isRecurringTemplate == true)
    }

}
