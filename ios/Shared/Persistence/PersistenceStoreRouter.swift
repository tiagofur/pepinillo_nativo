// PersistenceStoreRouter.swift
// Pepinillo — Deep Work Companion for Apple
//
// Keeps the launch path local-only, then switches to a CloudKit-backed store
// after entitlement state proves that the user is Pepinillo+ and not
// Everywhere/AI+.

import Foundation
import SwiftData
import OSLog

private let syncRouterLogger = Logger(subsystem: "com.pepinillo.app", category: "sync-router")

#if DEBUG
/// Test hooks for integration tests that exercise reconcile without CloudKit.
enum PersistenceStoreRouterTesting {
    nonisolated(unsafe) static var migrationOverride: ((ModelContainer, ModelContainer) throws -> Void)?
    nonisolated(unsafe) static var openAppleCloudContainerOverride: (() throws -> ModelContainer)?
}
#endif

/// Thread-safe holder for the currently-active BackgroundPersistenceActor.
/// The router updates it on the main actor when the active store swaps; the live
/// PersistenceClient reads it from arbitrary async contexts. The held value is
/// itself Sendable, so only the reference swap needs synchronization.
final class ActivePersistenceActorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var actor: BackgroundPersistenceActor

    init(_ actor: BackgroundPersistenceActor) {
        self.actor = actor
    }

    var current: BackgroundPersistenceActor {
        lock.lock(); defer { lock.unlock() }
        return actor
    }

    func set(_ newActor: BackgroundPersistenceActor) {
        lock.lock(); defer { lock.unlock() }
        actor = newActor
    }
}

@MainActor
final class PersistenceStoreRouter: ObservableObject {
    private(set) var localContainer: ModelContainer
    @Published private(set) var activeContainer: ModelContainer

    private var appleCloudContainer: ModelContainer?
    /// Serialises overlapping `reconcile` calls so only one store swap runs at a time (#164).
    private var reconcileInFlight: Task<Void, Never>?

    /// Background ModelActor that owns its own ModelContext for the active
    /// container. Recreated whenever the active container swaps so persistence
    /// always runs off the main thread against the correct store. Held in a
    /// thread-safe box so the live PersistenceClient can read it from any
    /// async context while the router swaps it on the main actor.
    private let actorBox: ActivePersistenceActorBox

    init(localContainer: ModelContainer) {
        self.localContainer = localContainer
        self.activeContainer = localContainer
        self.actorBox = ActivePersistenceActorBox(BackgroundPersistenceActor(modelContainer: localContainer))
        AppGroupDefaults.activeSyncMode = .local
        AppGroupDefaults.syncStatus = .localOnly
    }

    /// The thread-safe holder for the active background persistence actor. The
    /// live PersistenceClient captures this box and reads `current` on every op.
    func activeActorBox() -> ActivePersistenceActorBox {
        actorBox
    }

    /// Point the active container (and the background actor) at a new container.
    private func setActiveContainer(_ container: ModelContainer) {
        activeContainer = container
        actorBox.set(BackgroundPersistenceActor(modelContainer: container))
    }

    func reconcile(capabilities: UserCapabilities) async {
        if let inFlight = reconcileInFlight {
            await inFlight.value
            return
        }

        let task = Task { @MainActor in
            defer { reconcileInFlight = nil }
            await performReconcile(capabilities: capabilities)
        }
        reconcileInFlight = task
        await task.value
    }

    private func performReconcile(capabilities: UserCapabilities) async {
        if capabilities.backendSync {
            do {
                try await exportAppleCloudDataToLocalIfNeeded(markDirtyForBackend: true)
                appleCloudContainer = nil
                switchToLocal(mode: .backend, status: .backendActive)
            } catch {
                handleAppleCloudExportFailure(error, context: "backend export")
            }
            return
        }

        guard capabilities.appleCloudSync else {
            await demoteToLocalIfNeeded()
            return
        }

        await activateAppleCloud()
    }

    func switchToLocal(
        mode: AppGroupDefaults.SyncMode = .local,
        status: AppGroupDefaults.SyncStatus = .localOnly
    ) {
        setActiveContainer(localContainer)
        AppGroupDefaults.activeSyncMode = mode
        AppGroupDefaults.syncStatus = status
    }

    private func demoteToLocalIfNeeded() async {
        let wasOnAppleCloud = AppGroupDefaults.activeSyncMode == .appleCloud && appleCloudContainer != nil

        do {
            try await exportAppleCloudDataToLocalIfNeeded()
            // Keep the cached CloudKit container for re-buy (#164). Release only when
            // switching to backend VPS sync, where Apple Cloud is permanently demoted.
            if wasOnAppleCloud {
                clearAppleCloudMigrationState()
            }
            switchToLocal(mode: .local, status: .localOnly)
        } catch {
            handleAppleCloudExportFailure(error, context: "demotion export")
        }
    }

    private func activateAppleCloud() async {
        if let appleCloudContainer {
            AppGroupDefaults.lastAppleCloudActivationError = nil

            do {
                try await seedAppleCloudFromLocalIfNeeded(into: appleCloudContainer)
                setActiveContainer(appleCloudContainer)
                AppGroupDefaults.activeSyncMode = .appleCloud
                AppGroupDefaults.syncStatus = .appleCloudActive
            } catch {
                handleAppleCloudActivationFailure(error)
            }
            return
        }

        AppGroupDefaults.syncStatus = .activatingAppleCloud
        AppGroupDefaults.lastAppleCloudActivationError = nil

        do {
            let container = try await openAppleCloudContainerWithTimeout()
            try await seedAppleCloudFromLocalIfNeeded(into: container)

            appleCloudContainer = container
            setActiveContainer(container)
            AppGroupDefaults.activeSyncMode = .appleCloud
            AppGroupDefaults.syncStatus = .appleCloudActive
        } catch {
            handleAppleCloudActivationFailure(error)
        }
    }

    private func exportAppleCloudDataToLocalIfNeeded(markDirtyForBackend: Bool = false) async throws {
        guard AppGroupDefaults.activeSyncMode == .appleCloud, let appleCloudContainer else { return }

        let source = appleCloudContainer
        let target = localContainer
        try await Self.migrateDataOffMain(
            from: source,
            to: target,
            markDirtyForBackend: markDirtyForBackend
        )
    }

    private func seedAppleCloudFromLocalIfNeeded(into cloudContainer: ModelContainer) async throws {
        let migrationKey = LocalToCloudStoreMigrator.appleCloudInitialMigrationCompleteKey
        guard UserDefaults.standard.bool(forKey: migrationKey) == false else { return }

        let source = localContainer
        try await Self.importLegacyStoreIfNeeded(into: source)
        try await Self.migrateDataOffMain(from: source, to: cloudContainer)
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    private func clearAppleCloudMigrationState() {
        UserDefaults.standard.set(false, forKey: LocalToCloudStoreMigrator.appleCloudInitialMigrationCompleteKey)
    }

    private func handleAppleCloudExportFailure(_ error: Error, context: String) {
        syncRouterLogger.error(
            "Apple Cloud \(context, privacy: .public) failed: \(String(describing: error), privacy: .public)"
        )
        AppGroupDefaults.lastAppleCloudActivationError = String(describing: error)
        if AppGroupDefaults.activeSyncMode == .appleCloud {
            AppGroupDefaults.syncStatus = .appleCloudUnavailable
        }
    }

    private func handleAppleCloudActivationFailure(_ error: Error) {
        syncRouterLogger.error("Apple Cloud activation failed: \(String(describing: error), privacy: .public)")
        AppGroupDefaults.activeSyncMode = .local
        AppGroupDefaults.syncStatus = .appleCloudUnavailable
        AppGroupDefaults.lastAppleCloudActivationError = String(describing: error)
        setActiveContainer(localContainer)
    }

    private func openAppleCloudContainerWithTimeout() async throws -> ModelContainer {
        #if DEBUG
        if let override = PersistenceStoreRouterTesting.openAppleCloudContainerOverride {
            return try override()
        }
        #endif
        return try await openModelContainerOffMainThread(
            label: "apple-cloud",
            timeout: 8,
            qos: .utility
        ) {
            try makeAppleCloudModelContainer()
        }
    }

    /// Performs a full data copy between two containers.
    /// This method is intentionally `static nonisolated` so it can be called from a
    /// background Task without hopping to the main actor. Both `SwiftDataPersistenceService`
    /// instances create fresh `ModelContext` objects inside the call, which is safe as
    /// long as they are not shared with any other thread.
    private nonisolated static func migrateDataOffMain(
        from sourceContainer: ModelContainer,
        to targetContainer: ModelContainer,
        markDirtyForBackend: Bool = false
    ) async throws {
        try await Task(priority: .utility) {
            try Task.checkCancellation()
            try Self._migrateDataSync(from: sourceContainer, to: targetContainer)
            if markDirtyForBackend {
                try Task.checkCancellation()
                try SwiftDataPersistenceService(container: targetContainer).markAllSyncableDataDirty()
            }
        }.value
    }

    private nonisolated static func importLegacyStoreIfNeeded(into localContainer: ModelContainer) async throws {
        try await Task(priority: .utility) {
            try Task.checkCancellation()
            try LocalToCloudStoreMigrator.importLegacyStoreIfNeeded(into: localContainer)
        }.value
    }

    private nonisolated static func _migrateDataSync(
        from sourceContainer: ModelContainer,
        to targetContainer: ModelContainer
    ) throws {
        #if DEBUG
        if let override = PersistenceStoreRouterTesting.migrationOverride {
            try override(sourceContainer, targetContainer)
            return
        }
        #endif
        try LocalToCloudStoreMigrator.migrate(from: sourceContainer, to: targetContainer)
    }

    #if DEBUG
    /// Activates a pre-opened stand-in Cloud store without hitting CloudKit.
    func activateAppleCloudContainerForTesting(_ container: ModelContainer) {
        appleCloudContainer = container
        setActiveContainer(container)
        AppGroupDefaults.activeSyncMode = .appleCloud
        AppGroupDefaults.syncStatus = .appleCloudActive
    }
    #endif
}