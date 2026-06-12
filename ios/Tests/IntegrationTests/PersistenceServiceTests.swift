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
}
