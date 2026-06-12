// SchemaVersioningTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Real on-disk migration tests. Each test suite creates a SQLite store using a
// frozen schema version, inserts sample rows, then re-opens with the full
// migration plan and asserts that data survived and new columns are present.

import Testing
import SwiftData
import Foundation
@testable import Pepinillo

@Suite("SchemaVersioning", .serialized)
struct SchemaVersioningTests {

    // MARK: - Plan Shape Tests

    @Test("PepinilloMigrationPlan lists versioned schemas in order")
    func migrationPlanSchemasOrdered() {
        let schemas = PepinilloMigrationPlan.schemas
        #expect(schemas.count == 4)
        #expect(schemas[0].versionIdentifier == Schema.Version(1, 0, 0))
        #expect(schemas[1].versionIdentifier == Schema.Version(2, 0, 0))
        #expect(schemas[2].versionIdentifier == Schema.Version(3, 0, 0))
        #expect(schemas[3].versionIdentifier == Schema.Version(4, 0, 0))
    }

    @Test("PepinilloMigrationPlan has three sequential stages")
    func migrationPlanHasThreeStages() {
        #expect(PepinilloMigrationPlan.stages.count == 3)
    }

    @Test("Current schema (V4) includes all persisted models")
    func currentSchemaIncludesAllModels() {
        let modelNames = Set(SchemaV4.models.map { String(describing: $0) })
        #expect(modelNames.contains("TaskItem"))
        #expect(modelNames.contains("SubTask"))
        #expect(modelNames.contains("FocusSessionRecord"))
        #expect(modelNames.contains("DailyStats"))
        #expect(modelNames.contains("UserPreferences"))
        #expect(modelNames.contains("ProductivityReport"))
        #expect(modelNames.contains("CachedUser"))
    }

    @Test("ModelContainer loads with versioned schema V4")
    func modelContainerLoadsWithVersionedSchema() throws {
        let dir = try makeTempDir(label: "schema-load")
        defer { cleanup(dir) }

        let schema = Schema(versionedSchema: SchemaV4.self)
        let config = ModelConfiguration(schema: schema, url: dir.appendingPathComponent("test.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container.schema.entities.isEmpty == false)
    }

    // MARK: - On-Disk Migration: V1 → V4

    @MainActor
    @Test("V1 store migrates to V4: TaskItem data survives and gains sync columns")
    func v1StoreMigratesToV4() throws {
        let dir = try makeTempDir(label: "migration-v1-v4")
        defer { cleanup(dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        // 1. Create a V1 store and insert a task + a session.
        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = container.mainContext
            let task = SchemaV1.TaskItem(title: "V1 task")
            ctx.insert(task)
            let session = SchemaV1.FocusSessionRecord()
            session.mode = "pomodoro"
            session.phase = "work"
            session.actualDuration = 1500
            session.wasCompleted = true
            session.interruptions = 0
            ctx.insert(session)
            try ctx.save()
        }

        // 2. Re-open with full migration plan targeting V4.
        let currentSchema = Schema(versionedSchema: SchemaV4.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let migratedContainer = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let ctx = migratedContainer.mainContext

        // 3. Assert TaskItem data survived.
        let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "V1 task")

        // 4. Assert TaskItem sync columns are present with expected defaults.
        let task = try #require(tasks.first)
        #expect(task.syncId.isEmpty == false, "syncId should be non-empty after migration")
        #expect(task.isDirty == true, "isDirty default is true")
        #expect(task.isLocallyDeleted == false, "isLocallyDeleted default is false")
        #expect(task.syncedAt == nil, "syncedAt starts nil")

        // 5. Assert FocusSessionRecord data survived.
        let sessions = try ctx.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.mode == "pomodoro")
        #expect(sessions.first?.actualDuration == 1500)

        // 6. Assert FocusSessionRecord sync columns are present with expected defaults (added in V4).
        let session = try #require(sessions.first)
        #expect(session.isDirty == true, "FocusSessionRecord.isDirty default is true")
        #expect(session.syncedAt == nil, "FocusSessionRecord.syncedAt starts nil")
    }

    // MARK: - On-Disk Migration: V2 → V4

    @MainActor
    @Test("V2 store migrates to V4: TaskItem and CachedUser data survive, sync columns present")
    func v2StoreMigratesToV4() throws {
        let dir = try makeTempDir(label: "migration-v2-v4")
        defer { cleanup(dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        // 1. Create a V2 store with a task and a cached user.
        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = container.mainContext

            let task = SchemaV2.TaskItem(title: "V2 task")
            ctx.insert(task)

            let user = SchemaV2.CachedUser()
            user.id = "user-123"
            user.email = "test@example.com"
            user.name = "Test User"
            ctx.insert(user)

            try ctx.save()
        }

        // 2. Re-open with the full migration plan.
        let currentSchema = Schema(versionedSchema: SchemaV4.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let migratedContainer = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let ctx = migratedContainer.mainContext

        // 3. TaskItem data survived.
        let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "V2 task")

        // 4. TaskItem sync columns present (added in V3, not V2).
        let task = try #require(tasks.first)
        #expect(task.syncId.isEmpty == false, "syncId gained in V3 migration")
        #expect(task.isDirty == true)
        #expect(task.isLocallyDeleted == false)

        // 5. CachedUser survived (was already present in V2).
        let users = try ctx.fetch(FetchDescriptor<CachedUser>())
        #expect(users.count == 1)
        #expect(users.first?.email == "test@example.com")
    }

    // MARK: - On-Disk Migration: V3 → V4 (FocusSessionRecord sync fields)

    @MainActor
    @Test("V3 store migrates to V4: FocusSessionRecord gains isDirty and syncedAt")
    func v3StoreMigratesToV4() throws {
        let dir = try makeTempDir(label: "migration-v3-v4")
        defer { cleanup(dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        // 1. Create a V3 store — FocusSessionRecord has NO isDirty/syncedAt in V3.
        do {
            let schema = Schema(versionedSchema: SchemaV3.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = container.mainContext

            let task = SchemaV3.TaskItem(title: "V3 task")
            ctx.insert(task)

            let session = SchemaV3.FocusSessionRecord()
            session.mode = "flowtime"
            session.phase = "flow"
            session.actualDuration = 3600
            session.wasCompleted = true
            session.interruptions = 2
            ctx.insert(session)

            try ctx.save()
        }

        // 2. Migrate to V4.
        let currentSchema = Schema(versionedSchema: SchemaV4.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let migratedContainer = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let ctx = migratedContainer.mainContext

        // 3. TaskItem data survived.
        let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "V3 task")

        // 4. FocusSessionRecord data survived.
        let sessions = try ctx.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(sessions.count == 1)
        let session = try #require(sessions.first)
        #expect(session.mode == "flowtime")
        #expect(session.actualDuration == 3600)
        #expect(session.interruptions == 2)

        // 5. FocusSessionRecord.isDirty and syncedAt are now readable (added in V4).
        //    isDirty has a column default of true, syncedAt is nil (optional).
        #expect(session.isDirty == true, "isDirty column default is true after V3→V4 migration")
        #expect(session.syncedAt == nil, "syncedAt is nil for rows that predate V4")
    }

    // MARK: - Write-Round-Trip on Migrated Store

    @MainActor
    @Test("After V2→V4 migration, newly inserted tasks have correct sync defaults")
    func writeRoundTripAfterMigration() throws {
        let dir = try makeTempDir(label: "write-roundtrip")
        defer { cleanup(dir) }
        let storeURL = dir.appendingPathComponent("test.sqlite")

        // Seed a V2 store.
        do {
            let schema = Schema(versionedSchema: SchemaV2.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let ctx = container.mainContext
            ctx.insert(SchemaV2.TaskItem(title: "Legacy task"))
            try ctx.save()
        }

        // Open with full migration plan.
        let currentSchema = Schema(versionedSchema: SchemaV4.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let ctx = container.mainContext

        // Insert a new task using the live model and read it back.
        let newTask = TaskItem(title: "New task post-migration")
        ctx.insert(newTask)
        try ctx.save()

        let tasks = try ctx.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 2)

        let newFetched = try #require(tasks.first(where: { $0.title == "New task post-migration" }))
        #expect(newFetched.syncId.isEmpty == false)
        #expect(newFetched.isDirty == true)
        #expect(newFetched.isLocallyDeleted == false)

        // Also insert a FocusSessionRecord and verify sync fields.
        let newSession = FocusSessionRecord(
            mode: "pomodoro",
            phase: "work",
            startedAt: Date.now,
            endedAt: Date.now,
            actualDuration: 1500,
            targetDuration: 1500,
            wasCompleted: true,
            interruptions: 0,
            pauseCount: 0,
            totalPauseDuration: 0
        )
        ctx.insert(newSession)
        try ctx.save()

        let sessions = try ctx.fetch(FetchDescriptor<FocusSessionRecord>())
        #expect(sessions.count == 1)
        let fetchedSession = try #require(sessions.first)
        #expect(fetchedSession.isDirty == true)
        #expect(fetchedSession.syncedAt == nil)
    }

    // MARK: - Helpers

    private func makeTempDir(label: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-\(label)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
}
