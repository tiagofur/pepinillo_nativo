// PersistenceServiceTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import Foundation
import SwiftData
@testable import Pepinillo

@Suite("SwiftDataPersistenceService Integration Tests")
@MainActor
struct PersistenceServiceTests {
    
    @Test("Soft deleted task sync marks task clean and deletes from DB")
    func softDeleteSyncPurgesTask() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        let service = SwiftDataPersistenceService(context: context)
        
        // 1. Create a task and sync it initially so it gets a serverId and syncedAt
        let task = TaskItem(title: "Task to delete")
        context.insert(task)
        task.serverId = 123
        task.syncedAt = Date.now
        task.isDirty = false
        try context.save()
        
        let syncId = task.syncId
        print("DEBUG: Created task with syncId=\(syncId), serverId=\(String(describing: task.serverId)), syncedAt=\(String(describing: task.syncedAt)), isDirty=\(task.isDirty)")
        
        // 2. Soft-delete the task (should mark isLocallyDeleted = true, isDirty = true)
        try service.softDeleteTask(id: task.id)
        print("DEBUG: After softDeleteTask, isLocallyDeleted=\(task.isLocallyDeleted), isDirty=\(task.isDirty)")
        
        // Fetch to verify soft-deleted state
        let fetchedDirty = try service.fetchDirtyTasks()
        print("DEBUG: fetchedDirty count = \(fetchedDirty.count)")
        if let first = fetchedDirty.first {
            print("DEBUG: fetchedDirty.first: syncId=\(first.syncId), isLocallyDeleted=\(first.isLocallyDeleted), isDirty=\(first.isDirty)")
        }
        
        #expect(fetchedDirty.count == 1)
        #expect(fetchedDirty.first?.syncId == syncId)
        #expect(fetchedDirty.first?.isLocallyDeleted == true)
        #expect(fetchedDirty.first?.isDirty == true)
        
        // 3. Mark tasks synced (simulate sync of deleted task)
        try service.markTasksSynced(syncIds: [syncId], syncTimestamp: "now")
        
        // 4. Verify task is physically purged from the database
        let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
        print("DEBUG: allTasks count after sync = \(allTasks.count)")
        #expect(allTasks.isEmpty, "Task should be physically deleted/purged from the database after sync")
    }
    
    @Test("Batch fetching subtasks and sessions returns correct grouped mappings")
    func batchFetchingSubtasksAndSessions() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        
        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        let service = SwiftDataPersistenceService(context: context)
        
        // 1. Create two tasks
        let task1 = TaskItem(title: "Task 1")
        let task2 = TaskItem(title: "Task 2")
        context.insert(task1)
        context.insert(task2)
        try context.save()
        
        // 2. Add subtasks
        let sub1_1 = SubTask(title: "Subtask 1.1", sortOrder: 0)
        sub1_1.parent = task1
        let sub1_2 = SubTask(title: "Subtask 1.2", sortOrder: 1)
        sub1_2.parent = task1
        
        let sub2_1 = SubTask(title: "Subtask 2.1", sortOrder: 0)
        sub2_1.parent = task2
        
        context.insert(sub1_1)
        context.insert(sub1_2)
        context.insert(sub2_1)
        
        // 3. Add sessions
        let session1_1 = FocusSessionRecord(mode: "pomodoro", phase: "work", startedAt: Date.now.addingTimeInterval(-1000), endedAt: Date.now, actualDuration: 1500, targetDuration: nil, wasCompleted: true, interruptions: 0, pauseCount: 0, totalPauseDuration: 0)
        session1_1.task = task1
        
        let session2_1 = FocusSessionRecord(mode: "flowtime", phase: "work", startedAt: Date.now.addingTimeInterval(-2000), endedAt: Date.now.addingTimeInterval(-1000), actualDuration: 1000, targetDuration: nil, wasCompleted: true, interruptions: 0, pauseCount: 0, totalPauseDuration: 0)
        session2_1.task = task2
        
        let session2_2 = FocusSessionRecord(mode: "pomodoro", phase: "work", startedAt: Date.now, endedAt: nil, actualDuration: 500, targetDuration: nil, wasCompleted: false, interruptions: 0, pauseCount: 0, totalPauseDuration: 0)
        session2_2.task = task2
        
        context.insert(session1_1)
        context.insert(session2_1)
        context.insert(session2_2)
        try context.save()
        
        // 4. Test batch subtask fetching
        let subtaskBatch = try service.fetchSubtasks(forTaskIDs: [task1.id, task2.id])
        #expect(subtaskBatch[task1.id]?.count == 2)
        #expect(subtaskBatch[task1.id]?[0].title == "Subtask 1.1")
        #expect(subtaskBatch[task1.id]?[1].title == "Subtask 1.2")
        #expect(subtaskBatch[task2.id]?.count == 1)
        #expect(subtaskBatch[task2.id]?[0].title == "Subtask 2.1")
        
        // 5. Test batch session fetching
        let sessionBatch = try service.fetchSessions(forTaskIDs: [task1.id, task2.id])
        #expect(sessionBatch[task1.id]?.count == 1)
        #expect(sessionBatch[task1.id]?[0].mode == "pomodoro")
        #expect(sessionBatch[task2.id]?.count == 2)
        // Verify sorting by startedAt descending (session2_2 is startedAt now, session2_1 is startedAt past)
        #expect(sessionBatch[task2.id]?[0].mode == "pomodoro") // session2_2
        #expect(sessionBatch[task2.id]?[1].mode == "flowtime") // session2_1
    }

    // MARK: - Issue #74: fetchTask(by:) single-row fetch

    @Test("fetchTask(by:) returns the matching non-deleted task only")
    func fetchTaskByID() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let taskA = TaskItem(title: "Task A")
        let taskB = TaskItem(title: "Task B")
        context.insert(taskA)
        context.insert(taskB)
        // Soft-delete B so we can confirm it's excluded.
        taskB.isLocallyDeleted = true
        try context.save()

        // Existing id → returns A.
        let fetched = try service.fetchTask(by: taskA.id)
        #expect(fetched?.id == taskA.id)
        #expect(fetched?.title == "Task A")

        // Soft-deleted id → returns nil (does not surface deleted rows).
        let deleted = try service.fetchTask(by: taskB.id)
        #expect(deleted == nil)

        // Unknown id → returns nil.
        let unknown = try service.fetchTask(by: UUID())
        #expect(unknown == nil)
    }

    // MARK: - Issue #74: saveTaskOrder batch reorder

    @Test("saveTaskOrder persists new sort orders in a single transaction and marks dirty")
    func saveTaskOrderBatch() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let t1 = TaskItem(title: "1"); t1.sortOrder = 0; t1.isDirty = false
        let t2 = TaskItem(title: "2"); t2.sortOrder = 1; t2.isDirty = false
        let t3 = TaskItem(title: "3"); t3.sortOrder = 2; t3.isDirty = false
        context.insert(t1); context.insert(t2); context.insert(t3)
        try context.save()

        // Reorder: 3, 1, 2 (new sort orders 0, 1, 2)
        try service.saveTaskOrder([
            (id: t3.id, sortOrder: 0),
            (id: t1.id, sortOrder: 1),
            (id: t2.id, sortOrder: 2),
        ])

        // Verify persisted order + dirty flag.
        let fetched = try service.fetchTasks().sorted { $0.sortOrder < $1.sortOrder }
        #expect(fetched.map(\.title) == ["3", "1", "2"])
        #expect(fetched.allSatisfy { $0.isDirty == true })

        // Empty input is a no-op.
        try service.saveTaskOrder([])
        let refetched = try service.fetchTasks().sorted { $0.sortOrder < $1.sortOrder }
        #expect(refetched.map(\.title) == ["3", "1", "2"])
    }

    // MARK: - Issue #73: lifetime aggregate counts

    @Test("Aggregate session counts (lifetime) match manual tallies")
    func aggregateSessionCounts() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let cal = Calendar.current
        func session(_ mode: String, _ phase: String, _ hour: Int, _ completed: Bool) -> FocusSessionRecord {
            // Pin startedAt to today at the given hour so early-bird (< 8) is deterministic.
            var comps = cal.dateComponents([.year, .month, .day], from: Date.now)
            comps.hour = hour
            comps.minute = 5
            let startedAt = cal.date(from: comps) ?? Date.now
            return FocusSessionRecord(
                mode: mode, phase: phase,
                startedAt: startedAt, endedAt: startedAt,
                actualDuration: 1500, targetDuration: nil,
                wasCompleted: completed, interruptions: 0,
                pauseCount: 0, totalPauseDuration: 0
            )
        }

        let sessions: [FocusSessionRecord] = [
            session("pomodoro", "work", 6, true),     // early bird + completed pomodoro work
            session("pomodoro", "work", 10, true),    // completed pomodoro work
            session("pomodoro", "work", 12, false),   // incomplete pomodoro work
            session("pomodoro", "work", 9, true),     // completed pomodoro work
            session("flowtime", "flow", 8, true),     // completed flowtime
            session("flowtime", "flow", 11, false),   // incomplete flowtime
            session("timeBlock", "block", 7, true),   // early bird, not pomodoro/flowtime
        ]
        sessions.forEach { context.insert($0) }
        try context.save()

        let from = Date.distantPast
        #expect(try service.fetchSessionCount(from: from) == 7)
        // Early bird: started < 08:00 → pomodoro@6 + timeBlock@7 = 2
        #expect(try service.fetchEarlyBirdSessionCount(from: from) == 2)
        // Completed pomodoro work-phase: @6, @10, @9 = 3
        // (In real data every completed pomodoro has phase == "work"; empty-phase
        // is a legacy edge that the aggregate intentionally does not count.)
        #expect(try service.fetchCompletedPomodoroCount(from: from) == 3)
        // Completed flowtime: @8 = 1
        #expect(try service.fetchCompletedFlowtimeCount(from: from) == 1)

        // Bounds: a `from` in the future excludes everything.
        let future = Date.now.addingTimeInterval(86_400 * 365)
        #expect(try service.fetchSessionCount(from: future) == 0)
    }

    @Test("normalizeScheduledForToday clears stale manual Today pins (#190)")
    func normalizeScheduledForTodayClearsStalePins() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-normalize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let cal = Calendar.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let startOfToday = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: startOfToday)!

        let stale = TaskItem(title: "Pinned yesterday")
        stale.scheduledForToday = true
        stale.updatedAt = yesterday
        context.insert(stale)

        let dueToday = TaskItem(title: "Due today")
        dueToday.scheduledForToday = true
        dueToday.dueDate = startOfToday
        dueToday.updatedAt = yesterday
        context.insert(dueToday)
        try context.save()

        try service.normalizeScheduledForToday(now: now)

        #expect(stale.scheduledForToday == false)
        #expect(dueToday.scheduledForToday == true)
    }
}
