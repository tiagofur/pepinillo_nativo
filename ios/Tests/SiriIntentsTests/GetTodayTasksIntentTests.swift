// GetTodayTasksIntentTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// RED→GREEN tests for the Siri "today's tasks" App Intent (issue #900).
// On-disk SchemaV7 container with cloudKitDatabase: .none (same pattern as
// CreateTaskIntentTests).

import Testing
import SwiftData
import Foundation
import AppIntents
@testable import Pepinillo

@Suite("GetTodayTasksIntent", .serialized, .appGroupDefaultsSerialized)
struct GetTodayTasksIntentTests {

    private func makeContainer(label: String) throws -> (ModelContainer, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("todaytasks-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let schema = Schema(versionedSchema: SchemaV7.self)
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
        sortOrder: Int = 0,
        scheduledForToday: Bool = false,
        isCompleted: Bool = false,
        isLocallyDeleted: Bool = false,
        isRecurringTemplate: Bool = false
    ) -> TaskItem {
        let context = ModelContext(container)
        let task = TaskItem(title: title, notes: nil)
        task.sortOrder = sortOrder
        task.scheduledForToday = scheduledForToday
        task.isCompleted = isCompleted
        task.isLocallyDeleted = isLocallyDeleted
        task.isRecurringTemplate = isRecurringTemplate
        context.insert(task)
        try? context.save()
        return task
    }

    private func entities(_ tasks: [TaskItem]) -> [TaskEntity] {
        tasks.map { TaskEntity(id: $0.id.uuidString, title: $0.title, isCompleted: $0.isCompleted) }
    }

    // MARK: - T2 (S2): today's list

    @Test("todayTasks returns scheduledForToday actives in plan order")
    func todayTasksReturnsScheduledActivesInOrder() throws {
        let (container, dir) = try makeContainer(label: "order")
        defer { cleanup(dir) }

        insert("Third", in: container, sortOrder: 3, scheduledForToday: true)
        insert("First", in: container, sortOrder: 1, scheduledForToday: true)
        insert("Unscheduled", in: container, sortOrder: 2, scheduledForToday: false)

        let today = TaskIntentService.todayTasks(in: container)

        #expect(today.map(\.title) == ["First", "Third"])
    }

    @Test("todayTasks excludes completed, tombstoned and recurring-template tasks")
    func todayTasksExcludesInactive() throws {
        let (container, dir) = try makeContainer(label: "exclude")
        defer { cleanup(dir) }

        insert("Done", in: container, scheduledForToday: true, isCompleted: true)
        insert("Ghost", in: container, scheduledForToday: true, isLocallyDeleted: true)
        insert("Template", in: container, scheduledForToday: true, isRecurringTemplate: true)
        insert("Alive", in: container, scheduledForToday: true)

        let today = TaskIntentService.todayTasks(in: container)

        #expect(today.map(\.title) == ["Alive"])
    }

    // MARK: - S2: spoken summary

    @Test("summary for no tasks is the celebratory empty state")
    func summaryEmpty() {
        let summary = TodayTasksService.summary(for: [])

        // The tests run on a Spanish-locale simulator, so the expected value
        // resolves through the same catalog lookup instead of a hard-coded EN sentence.
        #expect(summary == String(localized: "No tasks scheduled for today 🎉"))
    }

    @Test("summary lists every task when within the spoken cap")
    func summaryListsAll() {
        let tasks = entities(names: ["Write docs", "Review PR", "Ship build"])

        let summary = TodayTasksService.summary(for: tasks)

        for name in ["Write docs", "Review PR", "Ship build"] {
            #expect(summary.contains(name))
        }
    }

    @Test("summary caps the spoken list and appends the remainder count")
    func summaryCapsAndCountsRemainder() {
        let names = (1...7).map { "Task \($0)" }
        let tasks = entities(names: names)

        let summary = TodayTasksService.summary(for: tasks, maxListed: 5)

        #expect(summary.contains("Task 1"))
        #expect(summary.contains("Task 5"))
        #expect(!summary.contains("Task 6"))
        #expect(!summary.contains("Task 7"))
    }

    private func entities(names: [String]) -> [TaskEntity] {
        names.map { TaskEntity(id: UUID().uuidString, title: $0, isCompleted: false) }
    }
}
