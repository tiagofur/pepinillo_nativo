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
        if capabilities.backendSync {
            exportAppleCloudDataToLocalForBackendIfNeeded()
            switchToLocal(mode: .backend, status: .backendActive)
            return
        }

        guard capabilities.appleCloudSync else {
            switchToLocal(mode: .local, status: .localOnly)
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

    private func activateAppleCloud() async {
        if let appleCloudContainer {
            setActiveContainer(appleCloudContainer)
            AppGroupDefaults.activeSyncMode = .appleCloud
            AppGroupDefaults.syncStatus = .appleCloudActive
            return
        }

        AppGroupDefaults.syncStatus = .activatingAppleCloud
        AppGroupDefaults.lastAppleCloudActivationError = nil

        do {
            let container = try await openAppleCloudContainerWithTimeout()
            let didMigrate = UserDefaults.standard.bool(forKey: "pepAppleCloudInitialMigrationComplete")
            if !didMigrate {
                // Perform the data copy off the main thread; only the container swap
                // (below) needs to happen on @MainActor.
                let source = localContainer
                try await Self.migrateDataOffMain(from: source, to: container)
                UserDefaults.standard.set(true, forKey: "pepAppleCloudInitialMigrationComplete")
            }

            appleCloudContainer = container
            setActiveContainer(container)
            AppGroupDefaults.activeSyncMode = .appleCloud
            AppGroupDefaults.syncStatus = .appleCloudActive
        } catch {
            syncRouterLogger.error("Apple Cloud activation failed: \(String(describing: error), privacy: .public)")
            AppGroupDefaults.activeSyncMode = .local
            AppGroupDefaults.syncStatus = .appleCloudUnavailable
            AppGroupDefaults.lastAppleCloudActivationError = String(describing: error)
            setActiveContainer(localContainer)
        }
    }

    private func exportAppleCloudDataToLocalForBackendIfNeeded() {
        guard AppGroupDefaults.activeSyncMode == .appleCloud, let appleCloudContainer else { return }

        // Capture containers as Sendable references before leaving the main actor.
        let source = appleCloudContainer
        let target = localContainer

        Task.detached(priority: .utility) { [weak self] in
            do {
                try await Self.migrateDataOffMain(from: source, to: target)
                try SwiftDataPersistenceService(container: target).markAllSyncableDataDirty()
            } catch {
                syncRouterLogger.error("Apple Cloud export to backend-local store failed: \(String(describing: error), privacy: .public)")
                await MainActor.run {
                    AppGroupDefaults.lastAppleCloudActivationError = String(describing: error)
                }
            }
            _ = self // suppress unused warning; weak ref keeps router alive during detach
        }
    }

    private func openAppleCloudContainerWithTimeout() async throws -> ModelContainer {
        try await openModelContainerOffMainThread(
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
        to targetContainer: ModelContainer
    ) async throws {
        try await Task.detached(priority: .utility) {
            try Self._migrateDataSync(from: sourceContainer, to: targetContainer)
        }.value
    }

    private nonisolated static func _migrateDataSync(from sourceContainer: ModelContainer, to targetContainer: ModelContainer) throws {
        let source = SwiftDataPersistenceService(container: sourceContainer)
        let target = SwiftDataPersistenceService(container: targetContainer)
        let iso = ISO8601DateFormatter()

        let tasks = try source.fetchTasks().filter { !$0.isDeleted }
        for task in tasks {
            let subtasks = try source.fetchSubtasks(for: task.id).map {
                SubTaskSyncDTO(title: $0.title, isFinished: $0.isCompleted)
            }
            try target.upsertTaskFromServer(TaskSyncDTO(
                id: task.serverId,
                syncId: task.syncId,
                title: task.title,
                description: task.notes,
                energyLevel: task.energyLevel.rawValue,
                recurrenceRule: task.recurrenceRule,
                recurringTemplateId: task.recurringTemplateID?.uuidString,
                createdDate: iso.string(from: task.createdAt),
                finishDate: task.dueDate.map { iso.string(from: $0) },
                isFinished: task.isCompleted,
                priority: task.priority.rawValue,
                estimatedPomodoros: task.estimatedPomodoros,
                completedPomodoros: task.completedPomodoros,
                isDeleted: false,
                subTasks: subtasks.isEmpty ? nil : subtasks,
                updatedAt: iso.string(from: task.updatedAt)
            ), saveImmediately: false)
        }

        let sessions = try source.fetchSessions(from: .distantPast, to: .distantFuture)
        for session in sessions {
            try target.upsertSessionFromServer(FocusSessionSyncDTO(
                id: session.id.uuidString,
                taskId: session.task?.serverId,
                taskSyncId: session.task?.syncId,
                startedAt: iso.string(from: session.startedAt),
                endedAt: session.endedAt.map { iso.string(from: $0) },
                mode: session.mode,
                phase: session.phase,
                durationSeconds: Int(session.actualDuration),
                elapsedSeconds: Int(session.actualDuration),
                pauseCount: session.pauseCount,
                totalPauseSeconds: Int(session.totalPauseDuration),
                wasCompleted: session.wasCompleted,
                createdAt: iso.string(from: session.startedAt),
                updatedAt: iso.string(from: session.startedAt)
            ), saveImmediately: false)
        }

        let prefs = try source.fetchPreferences()
        try target.applyPreferencesDTO(UserPreferencesDTO(from: prefs))

        if let user = try source.fetchCachedUser() {
            try target.saveCachedUser(CachedUserDTO(from: user))
        }

        try target.save()
    }
}
