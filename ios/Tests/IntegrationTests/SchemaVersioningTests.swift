// SchemaVersioningTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
import SwiftData
import Foundation
@testable import Pepinillo

@Suite("SchemaVersioning")
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

    @Test("ModelContainer loads with versioned schema and in-memory store")
    func modelContainerLoadsWithVersionedSchema() throws {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [config]
        )
        #expect(container.schema.entities.isEmpty == false)
    }
}
