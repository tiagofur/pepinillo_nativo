// WatchTasksFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for the WatchTasksFeature.
// Covers: task long press (link/unlink), tap (toggle completed),
// task list reception, and guard conditions.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

// MARK: - WatchTasksFeature Tests

@MainActor
@Suite("WatchTasksFeature Reducer")
struct WatchTasksFeatureTests {

    // MARK: - Helpers

    private static let taskA = WatchTaskItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: "Write documentation",
        isCompleted: false,
        priority: 2,
        estimatedPomodoros: 3,
        completedPomodoros: 1
    )

    private static let taskB = WatchTaskItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        title: "Review PR",
        isCompleted: false,
        priority: 1,
        estimatedPomodoros: 1,
        completedPomodoros: 0
    )

    private static let completedTask = WatchTaskItem(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        title: "Deploy hotfix",
        isCompleted: true,
        priority: 3,
        estimatedPomodoros: 1,
        completedPomodoros: 1
    )

    private static func stateWithTasks(_ tasks: [WatchTaskItem] = [taskA, taskB, completedTask]) -> WatchTasksFeature.State {
        var state = WatchTasksFeature.State()
        state.tasks = tasks
        return state
    }

    // MARK: - taskTapped: Completion toggle

    @Test("taskTapped toggles completion of an incomplete task")
    func taskTappedTogglesCompletion() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskTapped(Self.taskA.id))

        await store.receive(.setCompleted(Self.taskA.id, true)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }
    }

    // MARK: - taskLongPressed: Linking

    @Test("taskLongPressed links an incomplete task")
    func taskLongPressedLinksIncomplete() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskLongPressed(Self.taskA.id)) {
            $0.linkedTaskID = Self.taskA.id
        }

        await store.receive(.taskLinked(Self.taskA.id, "Write documentation"))
    }

    @Test("taskLongPressed on a different task switches link")
    func taskLongPressedSwitchesLink() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.taskA.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskLongPressed(Self.taskB.id)) {
            $0.linkedTaskID = Self.taskB.id
        }

        await store.receive(.taskLinked(Self.taskB.id, "Review PR"))
    }

    // MARK: - taskLongPressed: Unlinking

    @Test("taskLongPressed on already-linked task unlinks it")
    func taskLongPressedUnlinks() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.taskA.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskLongPressed(Self.taskA.id)) {
            $0.linkedTaskID = nil
        }

        await store.receive(.taskUnlinked)
    }

    // MARK: - taskLongPressed: Guard conditions

    @Test("taskLongPressed on completed task does nothing")
    func taskLongPressedCompletedTask() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskLongPressed(Self.completedTask.id))
    }

    @Test("taskLongPressed on nonexistent task ID does nothing")
    func taskLongPressedNonexistentID() async {
        let state = Self.stateWithTasks()
        let fakeID = UUID()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskLongPressed(fakeID))
    }

    @Test("taskLongPressed on completed task that is already linked still unlinks")
    func taskLongPressedUnlinksEvenIfCompleted() async {
        // Edge case: a task was linked, then completed externally,
        // long pressing it should still unlink because it matches linkedTaskID.
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.completedTask.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskLongPressed(Self.completedTask.id)) {
            $0.linkedTaskID = nil
        }

        await store.receive(.taskUnlinked)
    }

    // MARK: - setCompleted

    @Test("setCompleted sets isCompleted from false to true")
    func setCompletedToTrue() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.setCompleted(Self.taskA.id, true)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }
    }

    @Test("setCompleted sets isCompleted from true to false")
    func setCompletedToFalse() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.setCompleted(Self.completedTask.id, false)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.completedTask.id })!
            $0.tasks[idx] = WatchTaskItem(
                id: Self.completedTask.id,
                title: "Deploy hotfix",
                isCompleted: false,
                priority: 3,
                estimatedPomodoros: 1,
                completedPomodoros: 1
            )
        }
    }

    @Test("setCompleted with nonexistent ID does nothing")
    func setCompletedNonexistent() async {
        let state = Self.stateWithTasks()
        let fakeID = UUID()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.setCompleted(fakeID, true))
    }

    @Test("setCompleted is idempotent when state already matches")
    func setCompletedIdempotent() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.setCompleted(Self.taskA.id, false))
    }

    @Test("setCompleted preserves all other task fields")
    func setCompletedPreservesFields() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.setCompleted(Self.taskA.id, true)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            let toggled = $0.tasks[idx]
            // After mutation, verify all non-completion fields are preserved
            #expect(toggled.title == "Write documentation")
            #expect(toggled.priority == 2)
            #expect(toggled.estimatedPomodoros == 3)
            #expect(toggled.completedPomodoros == 1)
            // Apply actual mutation for TestStore correctness
            $0.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }
    }

    @Test("set then unset restores original state")
    func setThenUnsetRestoresState() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Mark completed
        await store.send(.setCompleted(Self.taskA.id, true)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }

        // Mark incomplete again
        await store.send(.setCompleted(Self.taskA.id, false)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: false,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }
    }

    // MARK: - taskLinked / taskUnlinked (pass-through)

    @Test("taskLinked action is a no-op in child reducer")
    func taskLinkedNoOp() async {
        let store = TestStore(initialState: WatchTasksFeature.State()) {
            WatchTasksFeature()
        }

        await store.send(.taskLinked(UUID(), "Some task"))
    }

    @Test("taskUnlinked action is a no-op in child reducer")
    func taskUnlinkedNoOp() async {
        let store = TestStore(initialState: WatchTasksFeature.State()) {
            WatchTasksFeature()
        }

        await store.send(.taskUnlinked)
    }

    // MARK: - tasksReceived

    @Test("tasksReceived replaces entire task list")
    func tasksReceivedReplacesList() async {
        var state = WatchTasksFeature.State()
        state.tasks = [Self.taskA]

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        let newTasks = [Self.taskB, Self.completedTask]

        await store.send(.tasksReceived(newTasks, sentAt: 100)) {
            $0.tasks = newTasks
            $0.lastTasksReceivedAt = 100
        }
    }

    @Test("tasksReceived with empty list clears tasks")
    func tasksReceivedEmptyList() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.tasksReceived([], sentAt: 100)) {
            $0.tasks = []
            $0.lastTasksReceivedAt = 100
        }
    }

    @Test("tasksReceived ignores stale sentAt")
    func tasksReceivedIgnoresStaleSentAt() async {
        var state = Self.stateWithTasks()
        state.lastTasksReceivedAt = 200

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.tasksReceived([Self.taskB], sentAt: 100))
    }

    @Test("tasksReceived preserves linked task ID")
    func tasksReceivedPreservesLinkedID() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.taskA.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // New tasks received — linkedTaskID should remain unchanged
        let newTasks = [Self.taskA, Self.taskB]
        await store.send(.tasksReceived(newTasks, sentAt: 100)) {
            $0.tasks = newTasks
            $0.lastTasksReceivedAt = 100
            // linkedTaskID not touched by tasksReceived
        }

        #expect(store.state.linkedTaskID == Self.taskA.id)
    }

    @Test("tasksReceived with large list works correctly")
    func tasksReceivedLargeList() async {
        let state = WatchTasksFeature.State()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        let manyTasks = (0..<50).map { i in
            WatchTaskItem(
                id: UUID(),
                title: "Task \(i)",
                isCompleted: i % 3 == 0,
                priority: i % 4,
                estimatedPomodoros: (i % 5) + 1,
                completedPomodoros: i % 3
            )
        }

        await store.send(.tasksReceived(manyTasks, sentAt: 100)) {
            $0.tasks = manyTasks
            $0.lastTasksReceivedAt = 100
        }
    }

    // MARK: - Initial State

    @Test("default state has empty tasks and no linked task")
    func defaultState() {
        let state = WatchTasksFeature.State()
        #expect(state.tasks.isEmpty)
        #expect(state.linkedTaskID == nil)
    }

    // MARK: - Combined Scenarios

    @Test("link task via long press, receive new tasks, task still linked")
    func linkThenReceiveNewTasks() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = nil

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Link task A via long press
        await store.send(.taskLongPressed(Self.taskA.id)) {
            $0.linkedTaskID = Self.taskA.id
        }
        await store.receive(.taskLinked(Self.taskA.id, "Write documentation"))

        // Receive updated task list (task A still there)
        let updatedA = WatchTaskItem(
            id: Self.taskA.id,
            title: "Write documentation",
            isCompleted: false,
            priority: 2,
            estimatedPomodoros: 3,
            completedPomodoros: 2  // pomodoros progressed
        )

        await store.send(.tasksReceived([updatedA, Self.taskB], sentAt: 100)) {
            $0.tasks = [updatedA, Self.taskB]
            $0.lastTasksReceivedAt = 100
        }

        // linkedTaskID should persist
        #expect(store.state.linkedTaskID == Self.taskA.id)
    }

    @Test("toggle task then try to link it via long press")
    func toggleThenLink() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Complete task A
        await store.send(.setCompleted(Self.taskA.id, true)) {
            let idx = $0.tasks.firstIndex(where: { $0.id == Self.taskA.id })!
            $0.tasks[idx] = WatchTaskItem(
                id: Self.taskA.id,
                title: "Write documentation",
                isCompleted: true,
                priority: 2,
                estimatedPomodoros: 3,
                completedPomodoros: 1
            )
        }

        // Now try to link the completed task via long press — should fail (guard)
        await store.send(.taskLongPressed(Self.taskA.id))
    }
}
