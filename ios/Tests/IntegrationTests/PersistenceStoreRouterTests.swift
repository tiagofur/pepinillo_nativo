// PersistenceStoreRouterTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Integration tests for tier/capability transitions in PersistenceStoreRouter.

import Testing
import Foundation
import SwiftData
@testable import Pepinillo

@Suite("PersistenceStoreRouter Integration Tests")
struct PersistenceStoreRouterTests {

    private let migrationKey = LocalToCloudStoreMigrator.appleCloudInitialMigrationCompleteKey

    private func makeOnDiskContainer(
        directory: URL,
        fileName: String
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV4.self)
        let config = ModelConfiguration(
            schema: schema,
            url: directory.appendingPathComponent(fileName),
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [config]
        )
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pepinillo-router-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fetchTaskTitles(in container: ModelContainer) throws -> [String] {
        let context = container.mainContext
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())
        return tasks.map(\.title).sorted()
    }

    @Test("Demotion awaits cloud→local export before swapping to local store")
    @MainActor
    func demotionExportsCloudDataBeforeLocalSwap() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let localContainer = try makeOnDiskContainer(directory: dir, fileName: "local.sqlite")
        let cloudContainer = try makeOnDiskContainer(directory: dir, fileName: "cloud.sqlite")

        let cloudContext = cloudContainer.mainContext
        let cloudTask = TaskItem(title: "Cloud-only task")
        cloudContext.insert(cloudTask)
        try cloudContext.save()

        let savedMigrationFlag = UserDefaults.standard.bool(forKey: migrationKey)
        defer {
            UserDefaults.standard.set(savedMigrationFlag, forKey: migrationKey)
            PersistenceStoreRouterTesting.migrationOverride = nil
        }
        UserDefaults.standard.set(true, forKey: migrationKey)

        let router = PersistenceStoreRouter(localContainer: localContainer)
        router.activateAppleCloudContainerForTesting(cloudContainer)

        await router.reconcile(capabilities: .free)

        #expect(AppGroupDefaults.activeSyncMode == .local)
        #expect(AppGroupDefaults.syncStatus == .localOnly)
        #expect(router.activeContainer === localContainer)
        #expect(try fetchTaskTitles(in: localContainer) == ["Cloud-only task"])
        #expect(UserDefaults.standard.bool(forKey: migrationKey) == false)
    }

    @Test("Re-buy re-merges local deltas after demotion clears migration flag")
    @MainActor
    func rebuyMergesLocalDeltasAfterDemotion() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let localContainer = try makeOnDiskContainer(directory: dir, fileName: "local.sqlite")
        let cloudContainer = try makeOnDiskContainer(directory: dir, fileName: "cloud.sqlite")

        let cloudContext = cloudContainer.mainContext
        let originalCloudTask = TaskItem(title: "Original cloud task")
        cloudContext.insert(originalCloudTask)
        try cloudContext.save()

        let savedMigrationFlag = UserDefaults.standard.bool(forKey: migrationKey)
        defer {
            UserDefaults.standard.set(savedMigrationFlag, forKey: migrationKey)
            PersistenceStoreRouterTesting.migrationOverride = nil
        }
        UserDefaults.standard.set(true, forKey: migrationKey)

        let router = PersistenceStoreRouter(localContainer: localContainer)
        router.activateAppleCloudContainerForTesting(cloudContainer)

        await router.reconcile(capabilities: .free)
        #expect(UserDefaults.standard.bool(forKey: migrationKey) == false)

        let localContext = localContainer.mainContext
        let localOnlyTask = TaskItem(title: "Local delta after demotion")
        localContext.insert(localOnlyTask)
        try localContext.save()

        await router.reconcile(capabilities: .pepinilloPlus)

        #expect(AppGroupDefaults.activeSyncMode == .appleCloud)
        #expect(AppGroupDefaults.syncStatus == .appleCloudActive)
        #expect(router.activeContainer === cloudContainer)
        #expect(
            try fetchTaskTitles(in: cloudContainer) == [
                "Local delta after demotion",
                "Original cloud task",
            ]
        )
        #expect(UserDefaults.standard.bool(forKey: migrationKey) == true)
    }

    @Test("Demotion export failure keeps Apple Cloud active and surfaces error")
    @MainActor
    func demotionExportFailureKeepsCloudActive() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let localContainer = try makeOnDiskContainer(directory: dir, fileName: "local.sqlite")
        let cloudContainer = try makeOnDiskContainer(directory: dir, fileName: "cloud.sqlite")

        let cloudContext = cloudContainer.mainContext
        cloudContext.insert(TaskItem(title: "Should stay in cloud"))
        try cloudContext.save()

        let savedMigrationFlag = UserDefaults.standard.bool(forKey: migrationKey)
        let savedError = AppGroupDefaults.lastAppleCloudActivationError
        defer {
            UserDefaults.standard.set(savedMigrationFlag, forKey: migrationKey)
            AppGroupDefaults.lastAppleCloudActivationError = savedError
            PersistenceStoreRouterTesting.migrationOverride = nil
        }
        UserDefaults.standard.set(true, forKey: migrationKey)
        AppGroupDefaults.lastAppleCloudActivationError = nil

        struct ExportFailure: Error, CustomStringConvertible {
            var description: String { "simulated demotion export failure" }
        }
        PersistenceStoreRouterTesting.migrationOverride = { _, _ in
            throw ExportFailure()
        }

        let router = PersistenceStoreRouter(localContainer: localContainer)
        router.activateAppleCloudContainerForTesting(cloudContainer)

        await router.reconcile(capabilities: .free)

        #expect(AppGroupDefaults.activeSyncMode == .appleCloud)
        #expect(AppGroupDefaults.syncStatus == .appleCloudUnavailable)
        #expect(router.activeContainer === cloudContainer)
        #expect(AppGroupDefaults.lastAppleCloudActivationError == "simulated demotion export failure")
        #expect(try fetchTaskTitles(in: localContainer).isEmpty)
        #expect(UserDefaults.standard.bool(forKey: migrationKey) == true)
    }

    @Test("Backend export failure keeps Apple Cloud active instead of fire-and-forget swap")
    @MainActor
    func backendExportFailureKeepsCloudActive() async throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let localContainer = try makeOnDiskContainer(directory: dir, fileName: "local.sqlite")
        let cloudContainer = try makeOnDiskContainer(directory: dir, fileName: "cloud.sqlite")

        let cloudContext = cloudContainer.mainContext
        cloudContext.insert(TaskItem(title: "Backend export source"))
        try cloudContext.save()

        let savedError = AppGroupDefaults.lastAppleCloudActivationError
        defer {
            AppGroupDefaults.lastAppleCloudActivationError = savedError
            PersistenceStoreRouterTesting.migrationOverride = nil
        }
        AppGroupDefaults.lastAppleCloudActivationError = nil

        struct ExportFailure: Error, CustomStringConvertible {
            var description: String { "simulated backend export failure" }
        }
        PersistenceStoreRouterTesting.migrationOverride = { _, _ in
            throw ExportFailure()
        }

        let router = PersistenceStoreRouter(localContainer: localContainer)
        router.activateAppleCloudContainerForTesting(cloudContainer)

        await router.reconcile(capabilities: .everywherePlus)

        #expect(AppGroupDefaults.activeSyncMode == .appleCloud)
        #expect(AppGroupDefaults.syncStatus == .appleCloudUnavailable)
        #expect(router.activeContainer === cloudContainer)
        #expect(AppGroupDefaults.lastAppleCloudActivationError == "simulated backend export failure")
        #expect(try fetchTaskTitles(in: localContainer).isEmpty)
    }
}