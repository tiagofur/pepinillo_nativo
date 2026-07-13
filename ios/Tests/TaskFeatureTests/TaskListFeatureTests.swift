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
                scheduledForToday: true,
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

    @Test func detailDeleteRoutesThroughSharedDeletePipeline() async {
        let taskID = UUID(0)
        var initialState = TaskListFeature.State()
        let task = makeTask(id: taskID, title: "Detail task", scheduledForToday: false, isCompleted: false, sortOrder: 0)
        initialState.tasks = [task]
        initialState.detail = TaskDetailFeature.State(from: task)
        initialState.selectedTaskID = taskID

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { _ in }
            $0.spotlightClient.deindexTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.detail(.presented(.delegate(.taskDeleted(taskID)))))
        await store.receive(.taskDeleted(taskID)) {
            $0.recentlyDeletedTask = task
            $0.tasks = []
            $0.detail = nil
            $0.selectedTaskID = nil
        }
    }

    @Test func importedReminderUsesStableSyncID() {
        let reminder = ImportedReminder(
            externalID: "abc-123",
            title: "Buy milk",
            notes: nil,
            priority: .medium,
            calendarName: "Personal",
            dueDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(reminder.reminderSyncID == "reminder:abc-123")
        let dto = reminder.toTaskItemDTO(sortOrder: 5, syncId: reminder.reminderSyncID)
        #expect(dto.syncId == "reminder:abc-123")
        #expect(dto.sortOrder == 5)
        #expect(dto.dueDate != nil)
    }

    @Test func rapidMultiDeleteSoftDeletesAllTasksImmediately() async {
        let taskA = UUID(0)
        let taskB = UUID(1)
        var initialState = TaskListFeature.State()
        initialState.tasks = [
            makeTask(id: taskA, title: "Task A", scheduledForToday: false, isCompleted: false, sortOrder: 0),
            makeTask(id: taskB, title: "Task B", scheduledForToday: false, isCompleted: false, sortOrder: 1),
        ]

        let deletedIDs = LockIsolated<[UUID]>([])
        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { id in
                deletedIDs.withValue { $0.append(id) }
            }
            $0.spotlightClient.deindexTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.taskDeleted(taskA)) {
            $0.tasks = [initialState.tasks[id: taskB]!]
            $0.recentlyDeletedTask = initialState.tasks[id: taskA]
        }
        await store.send(.taskDeleted(taskB)) {
            $0.tasks = []
            $0.recentlyDeletedTask = initialState.tasks[id: taskB]
        }

        #expect(deletedIDs.value == [taskA, taskB])
    }

    @Test func undoRestoresOnlyMostRecentlyDeletedTask() async {
        let taskA = UUID(0)
        let taskB = UUID(1)
        var initialState = TaskListFeature.State()
        let itemA = makeTask(id: taskA, title: "Task A", scheduledForToday: false, isCompleted: false, sortOrder: 0)
        let itemB = makeTask(id: taskB, title: "Task B", scheduledForToday: false, isCompleted: false, sortOrder: 1)
        initialState.tasks = [itemA, itemB]

        let restoredDTO = LockIsolated<TaskItemDTO?>(nil)
        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { _ in }
            $0.persistenceClient.restoreTask = { dto in restoredDTO.setValue(dto) }
            $0.spotlightClient.deindexTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.taskDeleted(taskA))
        await store.send(.taskDeleted(taskB))
        await store.send(.undoDeleteTask) {
            $0.tasks = [itemB]
            $0.recentlyDeletedTask = nil
        }

        #expect(restoredDTO.value?.id == taskB)
        #expect(restoredDTO.value?.title == "Task B")
    }

    @Test func undoTimerExpiredDismissesOnlyMatchingBanner() async {
        let taskA = UUID(0)
        let taskB = UUID(1)
        var initialState = TaskListFeature.State()
        let itemA = makeTask(id: taskA, title: "Task A", scheduledForToday: false, isCompleted: false, sortOrder: 0)
        let itemB = makeTask(id: taskB, title: "Task B", scheduledForToday: false, isCompleted: false, sortOrder: 1)
        initialState.tasks = [itemA, itemB]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { _ in }
            $0.spotlightClient.deindexTask = { _ in }
        }

        store.exhaustivity = .off

        await store.send(.taskDeleted(taskA))
        await store.send(.taskDeleted(taskB))

        await store.send(.undoTimerExpired(taskA))

        #expect(store.state.recentlyDeletedTask?.id == taskB)

        await store.send(.undoTimerExpired(taskB)) {
            $0.recentlyDeletedTask = nil
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
                scheduledForToday: true,
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

    // MARK: - Issue #180: Plan-aware quick-add

    @Test func planQuickAddDefaultsTodaySchedulesForToday() {
        let defaults = TaskListFeature.planQuickAddDefaults(for: .today)
        #expect(defaults.scheduledForToday == true)
        #expect(defaults.dueDate == nil)
    }

    @Test func planQuickAddDefaultsInboxLeavesTaskUnscheduled() {
        let defaults = TaskListFeature.planQuickAddDefaults(for: .inbox)
        #expect(defaults.scheduledForToday == false)
        #expect(defaults.dueDate == nil)
    }

    @Test func planQuickAddDefaultsUpcomingSetsTomorrowDueDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let defaults = TaskListFeature.planQuickAddDefaults(for: .upcoming, now: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))

        #expect(defaults.scheduledForToday == false)
        #expect(defaults.dueDate == tomorrow)
    }

    @Test func addTaskInInboxFilterStaysInInbox() async {
        let testID = UUID(0)
        let testDate = Date(timeIntervalSince1970: 1_700_000_000)
        var initialState = TaskListFeature.State()
        initialState.selectedPlanFilter = .inbox

        let savedTask = LockIsolated<TaskItemDTO?>(nil)
        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { savedTask.setValue($0) }
            $0.uuid = .constant(testID)
            $0.date = .constant(testDate)
        }

        await store.send(.newTaskTitleChanged("Inbox task")) {
            $0.newTaskTitle = "Inbox task"
        }

        store.exhaustivity = .off

        await store.send(.addTaskTapped) {
            $0.newTaskTitle = ""
            $0.tasks.append(makeTask(
                id: testID,
                title: "Inbox task",
                scheduledForToday: false,
                isCompleted: false,
                sortOrder: 0
            ))
        }

        let saved = savedTask.value
        #expect(saved?.scheduledForToday == false)
        #expect(saved?.dueDate == nil)
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .inbox, now: testDate).ids == [testID])
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .today, now: testDate).isEmpty)
    }

    @Test func addTaskInUpcomingFilterSetsDueDateAndAppearsInUpcoming() async {
        let testID = UUID(0)
        let testDate = Date(timeIntervalSince1970: 1_700_000_000)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: testDate))!
        var initialState = TaskListFeature.State()
        initialState.selectedPlanFilter = .upcoming

        let savedTask = LockIsolated<TaskItemDTO?>(nil)
        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { savedTask.setValue($0) }
            $0.uuid = .constant(testID)
            $0.date = .constant(testDate)
        }

        await store.send(.newTaskTitleChanged("Upcoming task")) {
            $0.newTaskTitle = "Upcoming task"
        }

        store.exhaustivity = .off

        await store.send(.addTaskTapped) {
            $0.newTaskTitle = ""
            $0.tasks.append(makeTask(
                id: testID,
                title: "Upcoming task",
                scheduledForToday: false,
                isCompleted: false,
                sortOrder: 0,
                dueDate: tomorrow
            ))
        }

        let saved = savedTask.value
        #expect(saved?.scheduledForToday == false)
        #expect(saved?.dueDate == tomorrow)
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .upcoming, now: testDate).ids == [testID])
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .inbox, now: testDate).isEmpty)
    }

    @Test func addTaskInCompletedFilterDoesNotAutoComplete() async {
        let testID = UUID(0)
        let testDate = Date(timeIntervalSince1970: 1_700_000_000)
        var initialState = TaskListFeature.State()
        initialState.selectedPlanFilter = .completed

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTasks = { [] }
            $0.persistenceClient.saveTask = { _ in }
            $0.uuid = .constant(testID)
            $0.date = .constant(testDate)
        }

        await store.send(.newTaskTitleChanged("New active task")) {
            $0.newTaskTitle = "New active task"
        }

        store.exhaustivity = .off

        await store.send(.addTaskTapped) {
            $0.newTaskTitle = ""
            $0.tasks.append(makeTask(
                id: testID,
                title: "New active task",
                scheduledForToday: false,
                isCompleted: false,
                sortOrder: 0
            ))
        }

        #expect(store.state.tasks[id: testID]?.isCompleted == false)
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .completed, now: testDate).isEmpty)
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .inbox, now: testDate).ids == [testID])
    }

    // MARK: - Issue #181: PRO recurrence gate from list

    @Test func recurrenceChangedByFreeUserShowsPaywall() async {
        let taskID = UUID()
        var initialState = TaskListFeature.State()
        initialState.isProUser = false
        initialState.tasks = [
            makeTask(id: taskID, title: "Task", scheduledForToday: true, isCompleted: false, sortOrder: 0)
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in basicTaskDTO(id: taskID) }
            $0.persistenceClient.saveTask = { _ in }
        }

        await store.send(.recurrenceChanged(taskID, RecurrencePreset.weekly.rawValue))
        await store.receive(.delegate(.showPaywall))
        #expect(store.state.tasks[id: taskID]?.recurrenceRule == nil)
    }

    @Test func recurrenceChangedByProUserPersists() async {
        let taskID = UUID()
        let savedTask = LockIsolated<TaskItemDTO?>(nil)
        var initialState = TaskListFeature.State()
        initialState.isProUser = true
        initialState.tasks = [
            makeTask(id: taskID, title: "Task", scheduledForToday: true, isCompleted: false, sortOrder: 0)
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in basicTaskDTO(id: taskID) }
            $0.persistenceClient.saveTask = { savedTask.setValue($0) }
        }

        store.exhaustivity = .off

        await store.send(.recurrenceChanged(taskID, RecurrencePreset.weekly.rawValue)) {
            $0.tasks[id: taskID]?.recurrenceRule = RecurrencePreset.weekly.rawValue
            $0.tasks[id: taskID]?.isRecurringTemplate = true
        }

        let saved = savedTask.value
        #expect(saved?.recurrenceRule == RecurrencePreset.weekly.rawValue)
        #expect(saved?.isRecurringTemplate == true)
    }

    @Test func freeUserCanRemoveRecurrenceFromList() async {
        let taskID = UUID()
        let savedTask = LockIsolated<TaskItemDTO?>(nil)
        var initialState = TaskListFeature.State()
        initialState.isProUser = false
        initialState.tasks = [
            makeTask(
                id: taskID,
                title: "Recurring",
                scheduledForToday: true,
                isCompleted: false,
                sortOrder: 0
            )
        ]
        initialState.tasks[id: taskID]?.recurrenceRule = RecurrencePreset.weekly.rawValue
        initialState.tasks[id: taskID]?.isRecurringTemplate = true

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in
                recurringTaskDTO(id: taskID)
            }
            $0.persistenceClient.saveTask = { savedTask.setValue($0) }
        }

        store.exhaustivity = .off

        await store.send(.recurrenceChanged(taskID, nil)) {
            $0.tasks[id: taskID]?.recurrenceRule = nil
            $0.tasks[id: taskID]?.isRecurringTemplate = false
        }

        #expect(savedTask.value?.recurrenceRule == nil)
        #expect(savedTask.value?.isRecurringTemplate == false)
    }

    @Test func paywallRequestedForwardsToDelegate() async {
        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        }

        await store.send(.paywallRequested)
        await store.receive(.delegate(.showPaywall))
    }

    // MARK: - Issue #179: Filtered plan reorder

    // MARK: - Issue #182: Upcoming includes all future dues

    @Test func planFilteredTasksUpcomingIncludesDueBeyondSevenDays() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar.current
        let dueInTenDays = cal.date(byAdding: .day, value: 10, to: cal.startOfDay(for: now))!
        let taskID = UUID(0)

        let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> = [
            makeTask(
                id: taskID,
                title: "Far future",
                scheduledForToday: false,
                isCompleted: false,
                sortOrder: 0,
                dueDate: dueInTenDays
            ),
        ]

        let upcoming = TaskListFeature.planFilteredTasks(tasks, filter: .upcoming, now: now)
        #expect(upcoming.ids == [taskID])
        #expect(TaskListFeature.planFilteredTasks(tasks, filter: .today, now: now).isEmpty)
        #expect(TaskListFeature.planFilteredTasks(tasks, filter: .inbox, now: now).isEmpty)
    }

    @Test func planFilteredTasksUpcomingStillIncludesDueWithinSevenDays() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar.current
        let dueInThreeDays = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: now))!
        let taskID = UUID(0)

        let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> = [
            makeTask(
                id: taskID,
                title: "Soon",
                scheduledForToday: false,
                isCompleted: false,
                sortOrder: 0,
                dueDate: dueInThreeDays
            ),
        ]

        #expect(TaskListFeature.planFilteredTasks(tasks, filter: .upcoming, now: now).ids == [taskID])
    }

    @Test func everyIncompleteTaskAppearsInExactlyOneActivePlanList() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let dueInTenDays = cal.date(byAdding: .day, value: 10, to: startOfToday)!
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!

        let scenarios: [TaskListFeature.TaskItemState] = [
            makeTask(id: UUID(0), title: "Inbox", scheduledForToday: false, isCompleted: false, sortOrder: 0),
            makeTask(id: UUID(1), title: "Scheduled today", scheduledForToday: true, isCompleted: false, sortOrder: 1),
            makeTask(id: UUID(2), title: "Due today", scheduledForToday: false, isCompleted: false, sortOrder: 2, dueDate: startOfToday),
            makeTask(id: UUID(3), title: "Overdue", scheduledForToday: false, isCompleted: false, sortOrder: 3, dueDate: yesterday),
            makeTask(id: UUID(4), title: "Due tomorrow", scheduledForToday: false, isCompleted: false, sortOrder: 4, dueDate: tomorrow),
            makeTask(id: UUID(5), title: "Due in 10 days", scheduledForToday: false, isCompleted: false, sortOrder: 5, dueDate: dueInTenDays),
            makeTask(
                id: UUID(6),
                title: "Scheduled today with far due",
                scheduledForToday: true,
                isCompleted: false,
                sortOrder: 6,
                dueDate: dueInTenDays
            ),
        ]

        for task in scenarios {
            let tasks = IdentifiedArrayOf<TaskListFeature.TaskItemState>(uniqueElements: [task])
            let activeFilters = PlanFilter.allCases.filter { filter in
                filter != .completed && !TaskListFeature.planFilteredTasks(tasks, filter: filter, now: now).isEmpty
            }
            #expect(activeFilters.count == 1, "Task '\(task.title)' should appear in exactly one active list, got \(activeFilters)")
        }
    }

    @Test func planFilteredTasksExcludesRecurringTemplates() {
        let templateID = UUID(0)
        let instanceID = UUID(1)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        var template = makeTask(id: templateID, title: "Template", scheduledForToday: true, isCompleted: false, sortOrder: 0)
        template.isRecurringTemplate = true
        template.recurrenceRule = RecurrencePreset.weekly.rawValue
        let instance = makeTask(id: instanceID, title: "Instance", scheduledForToday: true, isCompleted: false, sortOrder: 1)

        let tasks = IdentifiedArrayOf(uniqueElements: [template, instance])
        let today = TaskListFeature.planFilteredTasks(tasks, filter: .today, now: now)
        #expect(today.ids == [instanceID])
        #expect(!today.ids.contains(templateID))
    }

    @Test func planFilteredTasksInboxExcludesTodayAndCompleted() {
        let inboxID = UUID(0)
        let todayID = UUID(1)
        let completedID = UUID(2)

        let tasks: IdentifiedArrayOf<TaskListFeature.TaskItemState> = [
            makeTask(id: inboxID, title: "Inbox", scheduledForToday: false, isCompleted: false, sortOrder: 0),
            makeTask(id: todayID, title: "Today", scheduledForToday: true, isCompleted: false, sortOrder: 1),
            makeTask(id: completedID, title: "Done", scheduledForToday: false, isCompleted: true, sortOrder: 2),
        ]

        let filtered = TaskListFeature.planFilteredTasks(tasks, filter: .inbox)

        #expect(filtered.ids == [inboxID])
    }

    @Test func taskMovedInInboxFilterReordersOnlyVisibleTasks() async {
        let inboxA = UUID(0)
        let todayB = UUID(1)
        let inboxC = UUID(2)
        let inboxD = UUID(3)

        var initialState = TaskListFeature.State()
        initialState.selectedPlanFilter = .inbox
        initialState.tasks = [
            makeTask(id: inboxA, title: "Inbox A", scheduledForToday: false, isCompleted: false, sortOrder: 0),
            makeTask(id: todayB, title: "Today B", scheduledForToday: true, isCompleted: false, sortOrder: 1),
            makeTask(id: inboxC, title: "Inbox C", scheduledForToday: false, isCompleted: false, sortOrder: 2),
            makeTask(id: inboxD, title: "Inbox D", scheduledForToday: false, isCompleted: false, sortOrder: 3),
        ]

        let savedOrder = LockIsolated<[(id: UUID, sortOrder: Int)]>([])
        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.saveTaskOrder = { order in savedOrder.setValue(order) }
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        }

        store.exhaustivity = .off

        // Inbox shows [A, C, D]. SwiftUI onMove(0, 2) inserts before index 2 -> [C, A, D].
        await store.send(.taskMoved(IndexSet(integer: 0), 2)) {
            $0.tasks[id: inboxC]?.sortOrder = 0
            $0.tasks[id: inboxA]?.sortOrder = 2
            $0.tasks[id: inboxD]?.sortOrder = 3
            $0.tasks[id: todayB]?.sortOrder = 1
            $0.tasks.sort { $0.sortOrder < $1.sortOrder }
        }

        let expectedOrder: [(UUID, Int)] = [
            (inboxC, 0),
            (todayB, 1),
            (inboxA, 2),
            (inboxD, 3),
        ]
        #expect(savedOrder.value.map { ($0.id, $0.sortOrder) }.elementsEqual(expectedOrder) { $0.0 == $1.0 && $0.1 == $1.1 })
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .inbox).ids == [inboxC, inboxA, inboxD])
    }

    @Test func taskMovedInTodayFilterPreservesNonTodayTasks() async {
        let todayA = UUID(0)
        let inboxB = UUID(1)
        let todayC = UUID(2)

        var initialState = TaskListFeature.State()
        initialState.selectedPlanFilter = .today
        initialState.tasks = [
            makeTask(id: todayA, title: "Today A", scheduledForToday: true, isCompleted: false, sortOrder: 0),
            makeTask(id: inboxB, title: "Inbox B", scheduledForToday: false, isCompleted: false, sortOrder: 1),
            makeTask(id: todayC, title: "Today C", scheduledForToday: true, isCompleted: false, sortOrder: 2),
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.saveTaskOrder = { _ in }
            $0.date = .constant(Date(timeIntervalSince1970: 1_700_000_000))
        }

        store.exhaustivity = .off

        // Today shows [A, C]. SwiftUI onMove(0, 2) moves past the last row -> [C, A].
        await store.send(.taskMoved(IndexSet(integer: 0), 2)) {
            $0.tasks[id: todayC]?.sortOrder = 0
            $0.tasks[id: todayA]?.sortOrder = 2
            $0.tasks[id: inboxB]?.sortOrder = 1
            $0.tasks.sort { $0.sortOrder < $1.sortOrder }
        }

        #expect(store.state.tasks[id: inboxB]?.sortOrder == 1)
        #expect(TaskListFeature.planFilteredTasks(store.state.tasks, filter: .today).ids == [todayC, todayA])
    }

    @Test("sortedPlanTasks orders by priority high to none (#185)")
    func sortedPlanTasksByPriority() {
        let tasks = IdentifiedArrayOf(uniqueElements: [
            makeTask(id: UUID(0), title: "Low", scheduledForToday: false, isCompleted: false, sortOrder: 0, priority: .low),
            makeTask(id: UUID(1), title: "High", scheduledForToday: false, isCompleted: false, sortOrder: 1, priority: .high),
            makeTask(id: UUID(2), title: "None", scheduledForToday: false, isCompleted: false, sortOrder: 2, priority: .none),
        ])
        let sorted = TaskListFeature.sortedPlanTasks(tasks, sortOrder: .priority)
        #expect(sorted.map(\.title) == ["High", "Low", "None"])
    }

    @Test("sortedPlanTasks keeps custom sortOrder (#185)")
    func sortedPlanTasksCustomOrder() {
        let tasks = IdentifiedArrayOf(uniqueElements: [
            makeTask(id: UUID(0), title: "B", scheduledForToday: false, isCompleted: false, sortOrder: 1),
            makeTask(id: UUID(1), title: "A", scheduledForToday: false, isCompleted: false, sortOrder: 0),
        ])
        let sorted = TaskListFeature.sortedPlanTasks(tasks, sortOrder: .custom)
        #expect(sorted.map(\.title) == ["A", "B"])
    }

    @Test("sortedPlanTasks puts nil due dates last (#185)")
    func sortedPlanTasksByDueDate() {
        let early = Date(timeIntervalSince1970: 1_000)
        let late = Date(timeIntervalSince1970: 2_000)
        let tasks = IdentifiedArrayOf(uniqueElements: [
            makeTask(id: UUID(0), title: "No due", scheduledForToday: false, isCompleted: false, sortOrder: 0),
            makeTask(id: UUID(1), title: "Late", scheduledForToday: false, isCompleted: false, sortOrder: 1, dueDate: late),
            makeTask(id: UUID(2), title: "Early", scheduledForToday: false, isCompleted: false, sortOrder: 2, dueDate: early),
        ])
        let sorted = TaskListFeature.sortedPlanTasks(tasks, sortOrder: .dueDate)
        #expect(sorted.map(\.title) == ["Early", "Late", "No due"])
    }

    @Test("addTask save failure rolls back optimistic row (#189)")
    func addTaskSaveFailureRollsBack() async {
        struct TestError: Error {}
        let testID = UUID(0)
        let testDate = Date(timeIntervalSince1970: 1_000_000)

        let store = TestStore(initialState: TaskListFeature.State()) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.saveTask = { _ in throw TestError() }
            $0.uuid = .constant(testID)
            $0.date = .constant(testDate)
        }

        await store.send(.newTaskTitleChanged("Buy groceries")) {
            $0.newTaskTitle = "Buy groceries"
        }

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
                scheduledForToday: true,
                sortOrder: 0,
                createdAt: testDate
            ))
        }

        await store.receive(\.mutationFailed) {
            $0.tasks = []
            $0.newTaskTitle = "Buy groceries"
            $0.mutationError = TestError().localizedDescription
        }
    }

    @Test("completeTask save failure restores completion state (#189)")
    func completeTaskSaveFailureRollsBack() async {
        struct TestError: Error {}
        let taskID = UUID(1)
        var initialState = TaskListFeature.State()
        initialState.tasks = [
            TaskListFeature.TaskItemState(
                id: taskID,
                title: "Task",
                isCompleted: false,
                priority: .none,
                energyLevel: .deep,
                estimatedPomodoros: 1,
                completedPomodoros: 0,
                subtaskProgress: .init(completed: 0, total: 0),
                recurrenceRule: nil,
                isRecurringTemplate: false,
                scheduledForToday: true,
                sortOrder: 0,
                createdAt: Date()
            )
        ]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTask = { _ in basicTaskDTO(id: taskID) }
            $0.persistenceClient.saveTask = { _ in throw TestError() }
        }

        await store.send(.taskCompleted(taskID))

        await store.receive(\.setTaskCompleted) {
            $0.tasks[id: taskID]?.isCompleted = true
        }

        await store.receive(\.mutationFailed) {
            $0.tasks[id: taskID]?.isCompleted = false
            $0.mutationError = TestError().localizedDescription
        }
    }

    @Test("deleteTask save failure restores task and undo banner (#189)")
    func deleteTaskSaveFailureRollsBack() async {
        struct TestError: Error {}
        let taskID = UUID(2)
        let task = TaskListFeature.TaskItemState(
            id: taskID,
            title: "Gone?",
            isCompleted: false,
            priority: .none,
            energyLevel: .deep,
            estimatedPomodoros: 1,
            completedPomodoros: 0,
            subtaskProgress: .init(completed: 0, total: 0),
            recurrenceRule: nil,
            isRecurringTemplate: false,
            scheduledForToday: true,
            sortOrder: 0,
            createdAt: Date()
        )
        var initialState = TaskListFeature.State()
        initialState.tasks = [task]

        let store = TestStore(initialState: initialState) {
            TaskListFeature()
        } withDependencies: {
            $0.persistenceClient.deleteTask = { _ in throw TestError() }
            $0.spotlightClient.deindexTask = { _ in }
        }

        store.exhaustivity = .off
        await store.send(.taskDeleted(taskID)) {
            $0.recentlyDeletedTask = task
            $0.tasks = []
        }

        await store.receive(\.mutationFailed) {
            $0.tasks = [task]
            $0.recentlyDeletedTask = task
            $0.mutationError = TestError().localizedDescription
        }
    }

    private func makeTask(
        id: UUID,
        title: String,
        scheduledForToday: Bool,
        isCompleted: Bool,
        sortOrder: Int,
        dueDate: Date? = nil,
        priority: TaskPriority = .none
    ) -> TaskListFeature.TaskItemState {
        TaskListFeature.TaskItemState(
            id: id,
            title: title,
            isCompleted: isCompleted,
            priority: priority,
            energyLevel: .deep,
            estimatedPomodoros: 1,
            completedPomodoros: 0,
            subtaskProgress: .init(completed: 0, total: 0),
            recurrenceRule: nil,
            isRecurringTemplate: false,
            dueDate: dueDate,
            scheduledForToday: scheduledForToday,
            sortOrder: sortOrder,
            createdAt: Date(timeIntervalSince1970: 1_000_000)
        )
    }
}
