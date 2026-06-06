// SchemaVersioningTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import SwiftData
import Foundation
@testable import Pepinillo

@Suite("SchemaVersioning", .serialized)
struct SchemaVersioningTests {

    @Test("PepinilloMigrationPlan lists versioned schemas in order")
    func migrationPlanSchemasOrdered() {
        let schemas = PepinilloMigrationPlan.schemas
        #expect(schemas.count == 3)
        #expect(schemas[0].versionIdentifier == Schema.Version(1, 0, 0))
        #expect(schemas[1].versionIdentifier == Schema.Version(2, 0, 0))
        #expect(schemas[2].versionIdentifier == Schema.Version(3, 0, 0))
    }

    @Test("Current schema (V3) includes all persisted models")
    func currentSchemaIncludesAllModels() {
        let modelNames = Set(SchemaV3.models.map { String(describing: $0) })
        #expect(modelNames.contains("TaskItem"))
        #expect(modelNames.contains("SubTask"))
        #expect(modelNames.contains("FocusSessionRecord"))
        #expect(modelNames.contains("DailyStats"))
        #expect(modelNames.contains("UserPreferences"))
        #expect(modelNames.contains("ProductivityReport"))
        #expect(modelNames.contains("CachedUser"))
    }

    @Test("ModelContainer loads with versioned schema")
    func modelContainerLoadsWithVersionedSchema() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-schema-load-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Pepinillo.sqlite")
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        
        let container = try ModelContainer(
            for: schema,
            configurations: [config]
        )
        #expect(container.schema.entities.isEmpty == false)
    }

    @MainActor
    @Test("V1 stores migrate to current schema with sync metadata")
    func v1StoreMigratesToCurrentSchemaWithSyncMetadata() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-schema-migration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("Pepinillo.sqlite")

        do {
            let schema = Schema(versionedSchema: SchemaV1.self)
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            context.insert(SchemaV1.TaskItem(title: "Migrated task"))
            try context.save()
        }

        let currentSchema = Schema(versionedSchema: SchemaV3.self)
        let currentConfig = ModelConfiguration(schema: currentSchema, url: storeURL, cloudKitDatabase: .none)
        let migratedContainer = try ModelContainer(
            for: currentSchema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [currentConfig]
        )
        let tasks = try migratedContainer.mainContext.fetch(FetchDescriptor<TaskItem>())

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Migrated task")
        #expect(tasks.first?.syncId.isEmpty == false)
        #expect(tasks.first?.isDirty == true)
        #expect(tasks.first?.isDeleted == false)
    }
}
