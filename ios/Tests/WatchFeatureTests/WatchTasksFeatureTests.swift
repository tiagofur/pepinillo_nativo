// WatchTasksFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for the WatchTasksFeature.
// Covers: task tapping (link/unlink), toggle completed,
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

    // MARK: - taskTapped: Linking

    @Test("taskTapped links an incomplete task")
    func taskTappedLinksIncomplete() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskTapped(Self.taskA.id)) {
            $0.linkedTaskID = Self.taskA.id
        }

        await store.receive(.taskLinked(Self.taskA.id, "Write documentation"))
    }

    @Test("taskTapped on a different task switches link")
    func taskTappedSwitchesLink() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.taskA.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Tapping a different task should link the new one
        await store.send(.taskTapped(Self.taskB.id)) {
            $0.linkedTaskID = Self.taskB.id
        }

        await store.receive(.taskLinked(Self.taskB.id, "Review PR"))
    }

    // MARK: - taskTapped: Unlinking

    @Test("taskTapped on already-linked task unlinks it")
    func taskTappedUnlinks() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.taskA.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskTapped(Self.taskA.id)) {
            $0.linkedTaskID = nil
        }

        await store.receive(.taskUnlinked)
    }

    // MARK: - taskTapped: Guard conditions

    @Test("taskTapped on completed task does nothing")
    func taskTappedCompletedTask() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Completed task should be ignored
        await store.send(.taskTapped(Self.completedTask.id))
    }

    @Test("taskTapped on nonexistent task ID does nothing")
    func taskTappedNonexistentID() async {
        let state = Self.stateWithTasks()
        let fakeID = UUID()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskTapped(fakeID))
    }

    @Test("taskTapped on completed task that is already linked still unlinks")
    func taskTappedUnlinksEvenIfCompleted() async {
        // Edge case: a task was linked, then completed externally,
        // tapping it should still unlink because it matches linkedTaskID.
        var state = Self.stateWithTasks()
        state.linkedTaskID = Self.completedTask.id

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.taskTapped(Self.completedTask.id)) {
            $0.linkedTaskID = nil
        }

        await store.receive(.taskUnlinked)
    }

    // MARK: - toggleCompleted

    @Test("toggleCompleted flips isCompleted from false to true")
    func toggleCompletedToTrue() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.toggleCompleted(Self.taskA.id)) {
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

    @Test("toggleCompleted flips isCompleted from true to false")
    func toggleCompletedToFalse() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.toggleCompleted(Self.completedTask.id)) {
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

    @Test("toggleCompleted with nonexistent ID does nothing")
    func toggleCompletedNonexistent() async {
        let state = Self.stateWithTasks()
        let fakeID = UUID()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.toggleCompleted(fakeID))
    }

    @Test("toggleCompleted preserves all other task fields")
    func toggleCompletedPreservesFields() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.toggleCompleted(Self.taskA.id)) {
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

    @Test("double toggle restores original state")
    func doubleToggleRestoresState() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Toggle to completed
        await store.send(.toggleCompleted(Self.taskA.id)) {
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

        // Toggle back to incomplete
        await store.send(.toggleCompleted(Self.taskA.id)) {
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

        await store.send(.tasksReceived(newTasks)) {
            $0.tasks = newTasks
        }
    }

    @Test("tasksReceived with empty list clears tasks")
    func tasksReceivedEmptyList() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        await store.send(.tasksReceived([])) {
            $0.tasks = []
        }
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
        await store.send(.tasksReceived(newTasks)) {
            $0.tasks = newTasks
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

        await store.send(.tasksReceived(manyTasks)) {
            $0.tasks = manyTasks
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

    @Test("link task, receive new tasks, task still linked")
    func linkThenReceiveNewTasks() async {
        var state = Self.stateWithTasks()
        state.linkedTaskID = nil

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Link task A
        await store.send(.taskTapped(Self.taskA.id)) {
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

        await store.send(.tasksReceived([updatedA, Self.taskB])) {
            $0.tasks = [updatedA, Self.taskB]
        }

        // linkedTaskID should persist
        #expect(store.state.linkedTaskID == Self.taskA.id)
    }

    @Test("toggle task then link it")
    func toggleThenLink() async {
        let state = Self.stateWithTasks()

        let store = TestStore(initialState: state) {
            WatchTasksFeature()
        }

        // Complete task A
        await store.send(.toggleCompleted(Self.taskA.id)) {
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

        // Now try to link the completed task — should fail (guard)
        await store.send(.taskTapped(Self.taskA.id))
    }
}
