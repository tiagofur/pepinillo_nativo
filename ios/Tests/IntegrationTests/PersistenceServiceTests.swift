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
        
        let schema = Schema(versionedSchema: SchemaV4.self)
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
        
        let schema = Schema(versionedSchema: SchemaV4.self)
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
}
