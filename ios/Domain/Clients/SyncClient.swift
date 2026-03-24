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

                    // Calculate tracking metrics from sessions
                    let completedSessions = task.sessions.filter(\.wasCompleted)
                    var completedFlowtimeSessions = 0
                    var completedTimeblockSessions = 0
                    var completedStopwatchSeconds = 0
                    var focusedSecondsPomodoro = 0
                    var focusedSecondsFlowtime = 0
                    var focusedSecondsTimeblock = 0
                    var focusedSecondsStopwatch = 0
                    var trackingMode = "pomodoro"

                    for session in completedSessions {
                        let focusSeconds = Int(session.actualDuration)
                        switch session.mode {
                        case "pomodoro":
                            focusedSecondsPomodoro += focusSeconds
                            trackingMode = "pomodoro"
                        case "flowtime":
                            focusedSecondsFlowtime += focusSeconds
                            completedFlowtimeSessions += 1
                            trackingMode = "flowtime"
                        case "timeBlock":
                            focusedSecondsTimeblock += focusSeconds
                            completedTimeblockSessions += 1
                            trackingMode = "timeBlock"
                        case "stopwatch":
                            focusedSecondsStopwatch += focusSeconds
                            completedStopwatchSeconds = focusedSecondsStopwatch
                            trackingMode = "stopwatch"
                        default:
                            break
                        }
                    }

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
                        category: nil,
                        trackingMode: trackingMode,
                        estimatedPomodoros: task.estimatedPomodoros,
                        completedPomodoros: task.completedPomodoros,
                        focusedSeconds: Int(completedSessions.reduce(0) { $0 + $1.actualDuration }),
                        focusedSecondsPomodoro: focusedSecondsPomodoro,
                        focusedSecondsFlowtime: focusedSecondsFlowtime,
                        focusedSecondsTimeblock: focusedSecondsTimeblock,
                        focusedSecondsStopwatch: focusedSecondsStopwatch,
                        activeSessionId: nil,
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

                let iso = ISO8601DateFormatter()

                // 1. Push dirty sessions to server
                let dirtySessions = try await persistence.fetchDirtySessions()
                var syncedIDs: [UUID] = []

                for session in dirtySessions {
                    let dto = FocusSessionSyncDTO(
                        id: session.id.uuidString,
                        taskId: nil, // Task linking handled separately
                        startedAt: iso.string(from: session.startedAt),
                        endedAt: session.endedAt.map { iso.string(from: $0) },
                        mode: session.mode.lowercased(),
                        phase: session.phase,
                        durationSeconds: Int(session.actualDuration),
                        elapsedSeconds: Int(session.actualDuration),
                        pauseCount: session.pauseCount,
                        totalPauseSeconds: Int(session.totalPauseDuration),
                        wasCompleted: session.wasCompleted,
                        createdAt: iso.string(from: session.startedAt),
                        updatedAt: iso.string(from: session.startedAt)
                    )
                    do {
                        _ = try await apiClient.createSession(dto)
                        syncedIDs.append(session.id)
                    } catch {
                        // Log but continue with other sessions
                        print("[SyncClient] Failed to sync session \(session.id): \(error)")
                    }
                }

                if !syncedIDs.isEmpty {
                    try await persistence.markSessionsSynced(syncedIDs)
                }

                // 2. Pull all sessions from server
                do {
                    let serverSessions = try await apiClient.getAllSessions()
                    for serverSession in serverSessions {
                        let exists = try await persistence.sessionExists(serverSession.id)
                        if !exists {
                            try await persistence.upsertSessionFromServer(serverSession)
                        }
                    }
                } catch {
                    // Non-fatal: log but don't throw for pull failures
                    print("[SyncClient] Failed to pull sessions: \(error)")
                }
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
