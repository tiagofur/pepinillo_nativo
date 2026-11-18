// CreateTaskIntentTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// RED→GREEN tests for the Siri "create a task" App Intent (issue #899).
// Uses an on-disk SchemaV6 container with cloudKitDatabase: .none (same
// pattern as SchemaVersioningTests) so persistence is verified without
// touching the real app-group store.

import Testing
import SwiftData
import Foundation
import AppIntents
@testable import Pepinillo

@Suite("CreateTaskIntent", .serialized, .appGroupDefaultsSerialized)
struct CreateTaskIntentTests {

    private func makeContainer(label: String) throws -> (ModelContainer, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("createtask-\(label)-\(UUID().uuidString)", isDirectory: true)
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

    // MARK: - Insertion

    @Test("insertTask persists a task with title, notes and append sortOrder")
    func insertPersistsTask() throws {
        let (container, dir) = try makeContainer(label: "persist")
        defer { cleanup(dir) }

        let result = CreateTaskService.insertTask("Buy oat milk", notes: "the barista one", in: container)
        #expect(result != nil)

        let context = ModelContext(container)
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks[0].title == "Buy oat milk")
        #expect(tasks[0].notes == "the barista one")
        #expect(tasks[0].isCompleted == false)
        #expect(tasks[0].sortOrder == 0)
        #expect(tasks[0].isDirty == true)
    }

    @Test("insertTask appends after the existing max sortOrder")
    func insertAppendsSortOrder() throws {
        let (container, dir) = try makeContainer(label: "append")
        defer { cleanup(dir) }
        let context = ModelContext(container)
        let seed = TaskItem(title: "Existing", priority: .none, energyLevel: .deep, estimatedPomodoros: 1, sortOrder: 7)
        context.insert(seed)
        try context.save()

        let result = CreateTaskService.insertTask("Second", notes: nil, in: container)
        #expect(result?.sortOrder == 8)

        let tasks = try context.fetch(
            FetchDescriptor<TaskItem>(sortBy: [SortDescriptor(\.sortOrder)])
        )
        #expect(tasks.map(\.title) == ["Existing", "Second"])
    }

    @Test("insertTask with blank title returns nil and persists nothing")
    func insertRejectsBlankTitle() throws {
        let (container, dir) = try makeContainer(label: "blank")
        defer { cleanup(dir) }

        #expect(CreateTaskService.insertTask("   ", notes: nil, in: container) == nil)
        #expect(try ModelContext(container).fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    // MARK: - Input normalization (used by the intent before persisting)

    @Test("normalizedTitle trims surrounding whitespace")
    func normalizedTitleTrims() {
        #expect(CreateTaskService.normalizedTitle("  Hola mundo  ") == "Hola mundo")
    }

    @Test("normalizedNotes trims and collapses blank notes to nil")
    func normalizedNotesCollapsesBlankToNil() {
        #expect(CreateTaskService.normalizedNotes("   ") == nil)
        #expect(CreateTaskService.normalizedNotes(nil) == nil)
        #expect(CreateTaskService.normalizedNotes(" nota con espacios ") == "nota con espacios")
    }

    // MARK: - Free-tier gate (same rule as in-app creation, #216)

    @Test("activeTaskCount ignores completed tasks and recurring templates")
    func activeTaskCountIgnoresCompletedAndTemplates() throws {
        let (container, dir) = try makeContainer(label: "count")
        defer { cleanup(dir) }
        let context = ModelContext(container)
        context.insert(TaskItem(title: "Active", priority: .none, energyLevel: .deep, estimatedPomodoros: 1, sortOrder: 0))
        let done = TaskItem(title: "Done", priority: .none, energyLevel: .deep, estimatedPomodoros: 1, sortOrder: 1)
        done.isCompleted = true
        context.insert(done)
        let template = TaskItem(title: "Template", priority: .none, energyLevel: .deep, estimatedPomodoros: 1, sortOrder: 2)
        template.isRecurringTemplate = true
        context.insert(template)
        try context.save()

        #expect(CreateTaskService.activeTaskCount(in: container) == 1)
    }

    @Test("isTaskCreationAllowed blocks free users at the 3-task limit")
    func creationAllowedBlocksFreeAtLimit() {
        #expect(CreateTaskService.isTaskCreationAllowed(isProUser: false, activeCount: 3) == false)
        #expect(CreateTaskService.isTaskCreationAllowed(isProUser: false, activeCount: 2) == true)
        #expect(CreateTaskService.isTaskCreationAllowed(isProUser: true, activeCount: 3) == true)
        #expect(CreateTaskService.isTaskCreationAllowed(isProUser: true, activeCount: 99) == true)
    }
}
