// CompleteTaskIntentTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// RED→GREEN tests for the Siri "complete a task" App Intent (issue #900).
// Uses an on-disk SchemaV6 container with cloudKitDatabase: .none (same
// pattern as CreateTaskIntentTests) so persistence is verified without
// touching the real app-group store.

import Testing
import SwiftData
import Foundation
import AppIntents
@testable import Pepinillo

@Suite("CompleteTaskIntent", .serialized, .appGroupDefaultsSerialized)
struct CompleteTaskIntentTests {

    private func makeContainer(label: String) throws -> (ModelContainer, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("completetask-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: SchemaV6.self)
        let config = ModelConfiguration(
            schema: schema,
            url: dir.appendingPathComponent("test.sqlite"),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        return (container, dir)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    @discardableResult
    private func insert(
        _ title: String,
        in container: ModelContainer,
        scheduledForToday: Bool = false,
        isLocallyDeleted: Bool = false,
        isRecurringTemplate: Bool = false
    ) -> TaskItem {
        let context = ModelContext(container)
        let task = TaskItem(title: title, notes: nil)
        task.scheduledForToday = scheduledForToday
        task.isLocallyDeleted = isLocallyDeleted
        task.isRecurringTemplate = isRecurringTemplate
        context.insert(task)
        try? context.save()
        return task
    }

    private func reload(_ task: TaskItem, in container: ModelContainer) throws -> TaskItem {
        let context = ModelContext(container)
        let id = task.id
        return try context.fetch(
            FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        ).first!
    }

    // MARK: - T1 (S1): completion persistence

    @Test("markCompleted persists isCompleted and completedAt")
    func markCompletedPersists() throws {
        let (container, dir) = try makeContainer(label: "persist")
        defer { cleanup(dir) }

        let task = insert("Buy oat milk", in: container)
        let later = task.updatedAt.addingTimeInterval(60)

        let outcome = TaskCompletionService.markCompleted(id: task.id, now: later, in: container)

        guard case .completed(let title) = outcome else {
            Issue.record("Expected .completed, got \(outcome)")
            return
        }
        #expect(title == "Buy oat milk")

        let reloaded = try reload(task, in: container)
        #expect(reloaded.isCompleted)
        #expect(reloaded.completedAt == later)
        #expect(reloaded.updatedAt == later)
    }

    @Test("markCompleted on an already-completed task is a no-op keeping the original stamp")
    func markCompletedAlreadyDone() throws {
        let (container, dir) = try makeContainer(label: "already")
        defer { cleanup(dir) }

        let task = insert("Water the plants", in: container)
        let originalStamp = task.updatedAt.addingTimeInterval(60)
        _ = TaskCompletionService.markCompleted(id: task.id, now: originalStamp, in: container)
        let stored = try reload(task, in: container)
        #expect(stored.completedAt == originalStamp)

        let secondTry = TaskCompletionService.markCompleted(id: task.id, now: originalStamp.addingTimeInterval(600), in: container)

        guard case .alreadyCompleted(let title) = secondTry else {
            Issue.record("Expected .alreadyCompleted, got \(secondTry)")
            return
        }
        #expect(title == "Water the plants")

        let reloaded = try reload(task, in: container)
        #expect(reloaded.completedAt == originalStamp)
    }

    @Test("markCompleted ignores tombstoned tasks")
    func markCompletedIgnoresTombstones() throws {
        let (container, dir) = try makeContainer(label: "tombstone")
        defer { cleanup(dir) }

        let task = insert("Deleted ghost", in: container, isLocallyDeleted: true)

        let outcome = TaskCompletionService.markCompleted(id: task.id, now: .now, in: container)

        guard case .notFound = outcome else {
            Issue.record("Expected .notFound for a tombstoned task, got \(outcome)")
            return
        }
        let reloaded = try reload(task, in: container)
        #expect(!reloaded.isCompleted)
        #expect(reloaded.completedAt == nil)
    }

    @Test("markCompleted with an unknown id returns notFound")
    func markCompletedUnknownID() throws {
        let (container, dir) = try makeContainer(label: "unknown")
        defer { cleanup(dir) }

        let outcome = TaskCompletionService.markCompleted(id: UUID(), now: .now, in: container)

        guard case .notFound = outcome else {
            Issue.record("Expected .notFound, got \(outcome)")
            return
        }
    }

    @Test("markCompleted stamps isDirty so the sync push uploads the completion")
    func markCompletedStampsDirty() throws {
        let (container, dir) = try makeContainer(label: "dirty")
        defer { cleanup(dir) }

        insert("Synced first", in: container)
        // Simulate a previous successful sync: fetch through the SAME context
        // that saves — a cross-context mutation is silently dropped by SwiftData.
        let context = ModelContext(container)
        let stored = try context.fetch(FetchDescriptor<TaskItem>()).first!
        stored.isDirty = false
        try context.save()

        let outcome = TaskCompletionService.markCompleted(id: stored.id, now: .now, in: container)

        guard case .completed = outcome else {
            Issue.record("Expected .completed, got \(outcome)")
            return
        }
        let reloaded = try reload(stored, in: container)
        #expect(reloaded.isDirty)
    }

    // MARK: - A5: the shared active-task seam excludes tombstones and templates

    @Test("activeTasks excludes tombstones, completed and recurring templates")
    func activeTasksExcludesTombstonesAndTemplates() throws {
        let (container, dir) = try makeContainer(label: "activetasks")
        defer { cleanup(dir) }

        insert("Alive", in: container, scheduledForToday: true)
        insert("Tombstoned", in: container, isLocallyDeleted: true)
        insert("Done", in: container)
        // Mark the third as completed directly.
        let context = ModelContext(container)
        let done = try context.fetch(FetchDescriptor<TaskItem>()).first { $0.title == "Done" }!
        done.isCompleted = true
        try? context.save()
        insert("Template", in: container, isRecurringTemplate: true)

        let active = TaskIntentService.activeTasks(in: container)

        #expect(active.map(\.title) == ["Alive"])
    }

}
