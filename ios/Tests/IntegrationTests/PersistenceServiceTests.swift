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
        
        // 2. Soft-delete the task (should mark isLocallyDeleted = true, isDirty = true)
        try service.softDeleteTask(id: task.id)
        
        // Fetch to verify soft-deleted state
        let fetchedDirty = try service.fetchDirtyTasks()
        
        #expect(fetchedDirty.count == 1)
        #expect(fetchedDirty.first?.syncId == syncId)
        #expect(fetchedDirty.first?.isLocallyDeleted == true)
        #expect(fetchedDirty.first?.isDirty == true)
        
        // 3. Mark tasks synced (simulate sync of deleted task)
        try service.markTasksSynced(syncIds: [syncId], syncTimestamp: "now")
        
        // 4. Verify task is physically purged from the database
        let allTasks = try context.fetch(FetchDescriptor<TaskItem>())
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

    @Test("markAllSyncableDataDirty includes soft-deleted tombstones")
    func markAllSyncableDataDirtyIncludesTombstones() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let live = TaskItem(title: "Live")
        live.isDirty = false
        context.insert(live)
        let tombstone = TaskItem(title: "Gone")
        tombstone.isLocallyDeleted = true
        tombstone.isDirty = false
        tombstone.syncId = "sync-gone"
        context.insert(tombstone)
        try context.save()

        try service.markAllSyncableDataDirty()

        // Both re-push after a store switch — the tombstone as a delete (S2).
        #expect(live.isDirty == true)
        #expect(tombstone.isDirty == true)
    }

    @Test("rebuildDailyStatsFromSessions recomputes aggregates per day and mode")
    func rebuildDailyStatsRecomputesAggregates() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        // Midday anchors: immune to midnight boundary flakiness.
        let todayNoon = try #require(Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: Date.now)))
        let yesterdayNoon = try #require(Calendar.current.date(byAdding: .day, value: -1, to: todayNoon))

        func insertSession(mode: String, start: Date, seconds: TimeInterval) {
            context.insert(FocusSessionRecord(
                mode: mode,
                phase: "work",
                startedAt: start,
                endedAt: start.addingTimeInterval(seconds),
                actualDuration: seconds,
                targetDuration: seconds,
                wasCompleted: true,
                interruptions: 0,
                pauseCount: 0,
                totalPauseDuration: 0
            ))
        }
        insertSession(mode: "pomodoro", start: todayNoon, seconds: 1500)
        insertSession(mode: "flowtime", start: todayNoon.addingTimeInterval(3600), seconds: 600)
        insertSession(mode: "stopwatch", start: yesterdayNoon, seconds: 300)
        try context.save()

        try service.deleteAllStats()
        try service.rebuildDailyStatsFromSessions()

        let stats = try context.fetch(FetchDescriptor<DailyStats>())
        #expect(stats.count == 2)
        let day = Calendar.current.startOfDay(for: Date.now)
        let todayStats = try #require(stats.first(where: { $0.date == day }))
        #expect(todayStats.totalFocusSeconds == 2100)
        #expect(todayStats.pomodoroSeconds == 1500)
        #expect(todayStats.flowtimeSeconds == 600)
        #expect(todayStats.sessionsCompleted == 2)
        #expect(todayStats.hadFocusSession == true)
        let prevDay = try #require(Calendar.current.date(byAdding: .day, value: -1, to: day))
        let yesterdayStats = try #require(stats.first(where: { $0.date == prevDay }))
        #expect(yesterdayStats.totalFocusSeconds == 300)
    }

    @Test("saveJournalEntry marks the session dirty for re-push")
    func saveJournalEntryMarksSessionDirty() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let record = FocusSessionRecord(
            mode: "pomodoro",
            phase: "work",
            startedAt: Date.now,
            endedAt: nil,
            actualDuration: 1500,
            targetDuration: 1500,
            wasCompleted: true,
            interruptions: 0,
            pauseCount: 0,
            totalPauseDuration: 0
        )
        record.isDirty = false // simulate an already-synced session
        context.insert(record)
        try context.save()

        try service.saveJournalEntry(sessionID: record.id, note: "Great flow", rating: 5)

        #expect(record.journalNote == "Great flow")
        #expect(record.satisfactionRating == 5)
        // S5 RED pre-fix: the journal stays clean and never re-pushes.
        #expect(record.isDirty == true)
    }

    @Test("upsertSessionFromServer restores journal fields on insert")
    func upsertRestoresJournalFields() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let dto = FocusSessionSyncDTO(
            id: UUID().uuidString,
            startedAt: "2024-01-01T00:00:00Z",
            endedAt: "2024-01-01T00:25:00Z",
            mode: "pomodoro",
            phase: "work",
            durationSeconds: 1500,
            elapsedSeconds: 1500,
            journalNote: "Great flow",
            satisfactionRating: 5,
            wasCompleted: true,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:25:00Z"
        )

        try service.upsertSessionFromServer(dto, true)

        let records = try context.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(records.count == 1)
        #expect(records.first?.journalNote == "Great flow")
        #expect(records.first?.satisfactionRating == 5)
    }

    @Test("fetchSessions excludes sessions exactly on the window end")
    func fetchSessionsExcludesBoundaryEnd() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let calendar = Calendar.current
        let day0 = calendar.startOfDay(for: Date.now)
        let day1 = try #require(calendar.date(byAdding: .day, value: 1, to: day0))
        let day2 = try #require(calendar.date(byAdding: .day, value: 1, to: day1))

        func insertSession(at start: Date, seconds: TimeInterval) {
            context.insert(FocusSessionRecord(
                mode: "pomodoro",
                phase: "work",
                startedAt: start,
                endedAt: start.addingTimeInterval(seconds),
                actualDuration: seconds,
                targetDuration: seconds,
                wasCompleted: true,
                interruptions: 0,
                pauseCount: 0,
                totalPauseDuration: 0
            ))
        }
        insertSession(at: day0.addingTimeInterval(3600), seconds: 600)
        insertSession(at: day1, seconds: 900)
        insertSession(at: day1.addingTimeInterval(3600), seconds: 300)
        try context.save()

        let firstWindow = try service.fetchSessions(from: day0, to: day1)
        let secondWindow = try service.fetchSessions(from: day1, to: day2)

        // S4 RED pre-fix: the boundary session counts in both windows.
        #expect(firstWindow.count == 1)
        #expect(secondWindow.count == 2)
        #expect((firstWindow + secondWindow).filter({ $0.startedAt == day1 }).count == 1)
    }

    @Test("applyServerPreference keeps unpushed local edits")
    func applyServerPreferenceKeepsDirtyLocalEdits() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let savedDirty = PreferenceDirtyTracker.getDirtyKeys()
        defer {
            PreferenceDirtyTracker.clearAll()
            PreferenceDirtyTracker.markDirtyKeys(Array(savedDirty))
        }

        // Local edit, not yet pushed.
        let prefs = try service.fetchPreferences()
        prefs.pomodoroDuration = TimeInterval(30 * 60)
        try service.savePreferences(prefs)
        PreferenceDirtyTracker.markDirty("pomodoroMinutes")

        try service.applyServerPreference(key: "pomodoroMinutes", value: "25", updatedAt: Date.now.addingTimeInterval(3600))

        let after = try service.fetchPreferences()
        // S5 RED pre-fix: the pull overwrites the newer local edit.
        #expect(after.pomodoroDuration == TimeInterval(30 * 60))
    }

    @Test("applyServerPreference applies server value for clean keys")
    func applyServerPreferenceAppliesCleanKeys() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-test-persistence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = SwiftDataPersistenceService(context: context)

        let savedDirty = PreferenceDirtyTracker.getDirtyKeys()
        defer {
            PreferenceDirtyTracker.clearAll()
            PreferenceDirtyTracker.markDirtyKeys(Array(savedDirty))
        }
        PreferenceDirtyTracker.clearAll()

        // Clean but diverged local value (e.g. after a push): server wins.
        let prefs = try service.fetchPreferences()
        prefs.pomodoroDuration = TimeInterval(30 * 60)
        try service.savePreferences(prefs)

        try service.applyServerPreference(key: "pomodoroMinutes", value: "25", updatedAt: Date.now)

        let after = try service.fetchPreferences()
        #expect(after.pomodoroDuration == TimeInterval(25 * 60))
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
