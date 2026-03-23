// SyncClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for syncing local data with the backend.
// Follows the same pattern as Android's SyncEngine:
// 1. Fetch dirty tasks, 2. Build sync request, 3. Send to server,
// 4. Merge response, 5. Mark synced tasks clean.

import Foundation
import ComposableArchitecture

// MARK: - Client

@DependencyClient
public struct SyncClient: Sendable {
    public var syncAll: @Sendable () async throws -> Void
    public var syncTasks: @Sendable () async throws -> Void
    public var syncSessions: @Sendable () async throws -> Void
}

// MARK: - Live implementation

extension SyncClient: DependencyKey {
    public static var liveValue: SyncClient {
        @Dependency(\.apiClient) var apiClient
        @Dependency(\.persistenceClient) var persistence
        @Dependency(\.keychainClient) var keychain

        return SyncClient(
            syncAll: {
                guard await keychain.hasTokens() else { return }
                @Dependency(\.syncClient) var syncClient
                try await syncClient.syncTasks()
                try await syncClient.syncSessions()
            },
            syncTasks: {
                guard await keychain.hasTokens() else { return }

                // 1. Get dirty tasks from local DB
                let dirtyTasks = try await persistence.fetchDirtyTasks()
                // If no dirty tasks and no last sync, still sync to pull server data
                let lastSyncAt = try await persistence.getLastSyncTimestamp()
                if dirtyTasks.isEmpty && lastSyncAt != nil {
                    // Nothing dirty and we've synced before — still do a pull
                }

                // 2. Separate deleted task syncIds from tasks to push
                let deletedSyncIds = dirtyTasks.filter { $0.isDeleted }.map(\.syncId)
                let tasksToSync = dirtyTasks.filter { !$0.isDeleted }

                // 3. Convert to API DTOs
                let iso = ISO8601DateFormatter()
                let cachedUser = try await persistence.fetchCachedUser()
                let userId = cachedUser?.id

                var taskDTOs: [TaskSyncDTO] = []
                for task in tasksToSync {
                    // Fetch subtasks for this task
                    let subtasks = try await persistence.fetchSubtasks(task.id)
                    let subTaskDTOs = subtasks.map { SubTaskSyncDTO(
                        id: $0.serverId,
                        taskId: task.serverId,
                        title: $0.title,
                        isFinished: $0.isCompleted
                    ) }

                    let dto = TaskSyncDTO(
                        id: task.serverId,
                        syncId: task.syncId,
                        userId: userId,
                        title: task.title,
                        description: task.notes,
                        energyLevel: task.energyLevel.rawValue.lowercased(),
                        recurrenceRule: task.recurrenceRule,
                        recurringTemplateId: nil,
                        createdDate: iso.string(from: task.createdAt),
                        finishDate: task.dueDate.map { iso.string(from: $0) },
                        isFinished: task.isCompleted,
                        priority: task.priority.rawValue,
                        estimatedPomodoros: task.estimatedPomodoros,
                        completedPomodoros: task.completedPomodoros,
                        isDeleted: false,
                        subTasks: subTaskDTOs.isEmpty ? nil : subTaskDTOs,
                        updatedAt: iso.string(from: task.updatedAt)
                    )
                    taskDTOs.append(dto)
                }

                // 4. Build request
                let request = TaskSyncRequest(
                    tasks: taskDTOs,
                    deletedSyncIds: deletedSyncIds,
                    lastSyncAt: lastSyncAt
                )

                // 5. Call API
                let response = try await apiClient.syncTasks(request)

                // 6. Merge server tasks into local DB
                for serverTask in response.tasks {
                    try await persistence.upsertTaskFromServer(serverTask)
                }

                // 7. Delete locally what server says is deleted
                for deletedId in response.deletedSyncIds {
                    try await persistence.purgeTaskBySyncId(deletedId)
                }

                // 8. Mark synced tasks as clean
                let syncedIds = tasksToSync.map(\.syncId)
                if !syncedIds.isEmpty {
                    try await persistence.markTasksSynced(syncedIds, response.syncTimestamp)
                }

                // Also mark deleted tasks' syncIds as synced so they get purged
                if !deletedSyncIds.isEmpty {
                    try await persistence.markTasksSynced(deletedSyncIds, response.syncTimestamp)
                }

                // 9. Save sync timestamp
                try await persistence.saveLastSyncTimestamp(response.syncTimestamp)
            },
            syncSessions: {
                guard await keychain.hasTokens() else { return }

                // Get cached user ID for syncing
                let cachedUser = try await persistence.fetchCachedUser()
                let userId = cachedUser?.id ?? ""

                // For now: placeholder implementation
                // In a full implementation, this would:
                // 1. Fetch dirty sessions from persistence
                // 2. Convert to API DTOs
                // 3. POST to /pomodoro/sessions
                // 4. Mark sessions as synced
                // NOTE: Requires fetchDirtySessions method on PersistenceClient
                // and createSession method on APIClient
            }
        )
    }

    public static let testValue = SyncClient()
}

// MARK: - DependencyValues registration

extension DependencyValues {
    public var syncClient: SyncClient {
        get { self[SyncClient.self] }
        set { self[SyncClient.self] = newValue }
    }
}
