// TasksWidgetQueryTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Regression tests for the Tasks widget's store query (#983). The shipped
// predicate referenced `isDeleted` — SwiftData's in-memory deletion marker,
// not a TaskItem schema field — and crashed every widget timeline with an
// uncatchable SwiftData trap, so the widget always rendered its empty
// state. These tests execute the real fetch against a SchemaV7 container
// (on-disk, same pattern as GetTodayTasksIntentTests).

import Testing
import SwiftData
import Foundation
@testable import Pepinillo

@Suite("TasksWidgetQuery", .serialized, .appGroupDefaultsSerialized)
struct TasksWidgetQueryTests {

    private func makeContainer(label: String) throws -> (ModelContainer, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("taskswidget-\(label)-\(UUID().uuidString)", isDirectory: true)
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
        createdAt: Date? = nil,
        scheduledForToday: Bool = false,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        isLocallyDeleted: Bool = false,
        isRecurringTemplate: Bool = false
    ) throws -> TaskItem {
        let context = ModelContext(container)
        let task = TaskItem(title: title, notes: nil)
        task.sortOrder = sortOrder
        if let createdAt { task.createdAt = createdAt }
        task.scheduledForToday = scheduledForToday
        task.dueDate = dueDate
        task.isCompleted = isCompleted
        task.isLocallyDeleted = isLocallyDeleted
        task.isRecurringTemplate = isRecurringTemplate
        context.insert(task)
        try context.save()
        return task
    }

    // MARK: - S1/S4: the real fetch must not crash (#983 regression)

    @Test("todayTasks executes the real fetch and returns today's tasks")
    func todayTasksFetchExecutesAndReturnsTodaysTasks() throws {
        let (container, dir) = try makeContainer(label: "regression")
        defer { cleanup(dir) }
        try insert("Alpha", in: container, sortOrder: 1, scheduledForToday: true)
        try insert("Beta", in: container, sortOrder: 2, scheduledForToday: true)

        let today = try TasksWidgetQuery.todayTasks(in: container)

        #expect(today.map(\.title) == ["Alpha", "Beta"])
    }

    // MARK: - Issue #984: >50 non-today tasks must not crowd out today's task

    @Test("a today task survives 55 earlier non-today tasks (fetch bound after filtering)")
    func todayTaskSurvivesLargeNonTodayBacklog() throws {
        let (container, dir) = try makeContainer(label: "crowding-984")
        defer { cleanup(dir) }
        let old = Calendar.current.date(byAdding: .day, value: -30, to: .now)!

        // 55 inbox tasks that sort BEFORE the today task (lower sortOrder).
        for i in 0..<55 {
            try insert("Inbox \(i)", in: container, sortOrder: i, createdAt: old)
        }
        try insert("Today's task", in: container, sortOrder: 100, scheduledForToday: true)

        let today = try TasksWidgetQuery.todayTasks(in: container)

        #expect(today.map(\.title) == ["Today's task"],
                "the fetch limit must apply AFTER the today filter (issue #984)")
    }

    // MARK: - S2: soft-delete exclusion matches the rest of the app

    @Test("tombstoned, completed and recurring-template tasks are excluded")
    func excludesTombstonedCompletedAndTemplateTasks() throws {
        let (container, dir) = try makeContainer(label: "exclusions")
        defer { cleanup(dir) }
        try insert("Active", in: container, sortOrder: 1, scheduledForToday: true)
        try insert("Tombstoned", in: container, sortOrder: 2, scheduledForToday: true, isLocallyDeleted: true)
        try insert("Completed", in: container, sortOrder: 3, scheduledForToday: true, isCompleted: true)
        try insert("Template", in: container, sortOrder: 4, scheduledForToday: true, isRecurringTemplate: true)

        let today = try TasksWidgetQuery.todayTasks(in: container)

        #expect(today.map(\.title) == ["Active"])
    }

    // MARK: - S3: today semantics match the Plan screen

    @Test("today semantics: scheduled for today, due today or overdue — not inbox or upcoming")
    func todaySemanticsMatchesPlanFilter() throws {
        let (container, dir) = try makeContainer(label: "semantics")
        defer { cleanup(dir) }
        let calendar = Calendar.current
        let now = Date.now
        let todayStart = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: todayStart))
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: todayStart))

        try insert("Scheduled", in: container, sortOrder: 1, scheduledForToday: true)
        try insert("DueToday", in: container, sortOrder: 2, dueDate: now)
        try insert("Overdue", in: container, sortOrder: 3, dueDate: yesterday)
        try insert("Upcoming", in: container, sortOrder: 4, dueDate: tomorrow)
        try insert("Inbox", in: container, sortOrder: 5)

        let today = try TasksWidgetQuery.todayTasks(in: container, now: now, calendar: calendar)

        #expect(Set(today.map(\.title)) == ["Scheduled", "DueToday", "Overdue"])
    }

    // MARK: - S3: widget display order

    @Test("orders by sortOrder, newest first within a tie")
    func ordersBySortOrderThenNewestFirst() throws {
        let (container, dir) = try makeContainer(label: "ordering")
        defer { cleanup(dir) }
        let older = Date(timeIntervalSince1970: 1_000_000)
        let newer = Date(timeIntervalSince1970: 1_000_060)

        try insert("Second", in: container, sortOrder: 2, createdAt: older, scheduledForToday: true)
        try insert("First", in: container, sortOrder: 1, createdAt: older, scheduledForToday: true)
        try insert("TieNew", in: container, sortOrder: 3, createdAt: newer, scheduledForToday: true)
        try insert("TieOld", in: container, sortOrder: 3, createdAt: older, scheduledForToday: true)

        let today = try TasksWidgetQuery.todayTasks(in: container)

        #expect(today.map(\.title) == ["First", "Second", "TieNew", "TieOld"])
    }
}
