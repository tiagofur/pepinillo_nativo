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

@MainActor
final class PersistenceStoreRouter: ObservableObject {
    private(set) var localContainer: ModelContainer
    @Published private(set) var activeContainer: ModelContainer

    private var appleCloudContainer: ModelContainer?

    init(localContainer: ModelContainer) {
        self.localContainer = localContainer
        self.activeContainer = localContainer
        AppGroupDefaults.activeSyncMode = .local
        AppGroupDefaults.syncStatus = .localOnly
    }

    func activeService() -> SwiftDataPersistenceService {
        SwiftDataPersistenceService(container: activeContainer)
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
        activeContainer = localContainer
        AppGroupDefaults.activeSyncMode = mode
        AppGroupDefaults.syncStatus = status
    }

    private func activateAppleCloud() async {
        if let appleCloudContainer {
            activeContainer = appleCloudContainer
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
                try migrateData(from: localContainer, to: container)
                UserDefaults.standard.set(true, forKey: "pepAppleCloudInitialMigrationComplete")
            }

            appleCloudContainer = container
            activeContainer = container
            AppGroupDefaults.activeSyncMode = .appleCloud
            AppGroupDefaults.syncStatus = .appleCloudActive
        } catch {
            syncRouterLogger.error("Apple Cloud activation failed: \(String(describing: error), privacy: .public)")
            AppGroupDefaults.activeSyncMode = .local
            AppGroupDefaults.syncStatus = .appleCloudUnavailable
            AppGroupDefaults.lastAppleCloudActivationError = String(describing: error)
            activeContainer = localContainer
        }
    }

    private func exportAppleCloudDataToLocalForBackendIfNeeded() {
        guard AppGroupDefaults.activeSyncMode == .appleCloud, let appleCloudContainer else { return }

        do {
            try migrateData(from: appleCloudContainer, to: localContainer)
            try SwiftDataPersistenceService(container: localContainer).markAllSyncableDataDirty()
        } catch {
            syncRouterLogger.error("Apple Cloud export to backend-local store failed: \(String(describing: error), privacy: .public)")
            AppGroupDefaults.lastAppleCloudActivationError = String(describing: error)
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

    private func migrateData(from sourceContainer: ModelContainer, to targetContainer: ModelContainer) throws {
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
            ))
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
            ))
        }

        let prefs = try source.fetchPreferences()
        try target.applyPreferencesDTO(UserPreferencesDTO(from: prefs))

        if let user = try source.fetchCachedUser() {
            try target.saveCachedUser(CachedUserDTO(from: user))
        }
    }
}
