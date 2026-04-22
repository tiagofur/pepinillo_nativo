// SyncClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for syncing local data with the backend.
// Follows the same pattern as Android's SyncEngine:
// 1. Fetch dirty tasks, 2. Build sync request, 3. Send to server,
// 4. Merge response, 5. Mark synced tasks clean.

import Foundation
import ComposableArchitecture

// MARK: - Dirty Preference Tracking

/// Tracks which preference keys have been modified since last sync.
/// Uses UserDefaults for simplicity since this is just a Set<String>.
public enum PreferenceDirtyTracker {
    private static let dirtyPreferencesKey = "dirtyPreferenceKeys"

    public static func markDirty(_ key: String) {
        var dirty = getDirtyKeys()
        dirty.insert(key)
        UserDefaults.standard.set(Array(dirty), forKey: dirtyPreferencesKey)
    }

    public static func markDirtyKeys(_ keys: [String]) {
        var dirty = getDirtyKeys()
        keys.forEach { dirty.insert($0) }
        UserDefaults.standard.set(Array(dirty), forKey: dirtyPreferencesKey)
    }

    public static func getDirtyKeys() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: dirtyPreferencesKey) ?? []
        return Set(array)
    }

    public static func clearAll() {
        UserDefaults.standard.removeObject(forKey: dirtyPreferencesKey)
    }

    /// All syncable preference keys.
    public static let syncableKeys: Set<String> = [
        "pomodoroMinutes", "shortBreakMinutes", "longBreakMinutes", "sessionsBeforeLongBreak",
        "autoStartBreaks", "autoStartNextPomodoro", "soundEnabled", "hapticEnabled",
        "keepScreenOn", "defaultMode", "themeName", "followSystemAppearance", "appearanceMode",
        "flowtimeMinMinutes", "timeBlockMinutes", "midpointCheckIn", "showJournalAfterSession"
    ]
}

// MARK: - Client

@DependencyClient
public struct SyncClient: Sendable {
    public var syncAll: @Sendable () async throws -> Void
    public var syncTasks: @Sendable () async throws -> Void
    public var syncSessions: @Sendable () async throws -> Void
    public var syncSettings: @Sendable () async throws -> Void
    public var initialUpload: @Sendable () async throws -> Bool  // returns hasExistingData
    public var performInitialSync: @Sendable () async throws -> Void
    public var wipeAndSync: @Sendable () async throws -> Void
    public var hasLocalData: @Sendable () async -> Bool = { false }
}

// MARK: - Sync Error

enum SyncError: Error {
    case notAuthenticated
    case notPro
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
                guard AppGroupDefaults.isProUser else { return }
                @Dependency(\.syncClient) var syncClient
                try await syncClient.syncSettings()
                try await syncClient.syncTasks()

            },
            syncTasks: {
                guard await keychain.hasTokens() else { return }
                guard AppGroupDefaults.isProUser else { return }

                // 1. Get dirty tasks from local DB
                let dirtyTasks = try await persistence.fetchDirtyTasks()
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
                    let subtasks = try await persistence.fetchSubtasks(task.id)
                    let subTaskDTOs = subtasks.map { SubTaskSyncDTO(
                        id: nil,
                        taskId: task.serverId,
                        title: $0.title,
                        isFinished: $0.isCompleted
                    ) }

                    let completedSessions = try await persistence.fetchSessionsForTask(task.id).filter(\.wasCompleted)
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
                            trackingMode = "flowtime"
                        case "timeBlock":
                            focusedSecondsTimeblock += focusSeconds
                            trackingMode = "timeBlock"
                        case "stopwatch":
                            focusedSecondsStopwatch += focusSeconds
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
                if !deletedSyncIds.isEmpty {
                    try await persistence.markTasksSynced(deletedSyncIds, response.syncTimestamp)
                }

                // 9. Save sync timestamp
                try await persistence.saveLastSyncTimestamp(response.syncTimestamp)
            },
            syncSessions: {
                guard await keychain.hasTokens() else { return }
                guard AppGroupDefaults.isProUser else { return }

                let iso = ISO8601DateFormatter()

                // 1. Get dirty sessions and convert to DTOs
                let dirtySessions = try await persistence.fetchDirtySessions()
                let sessionDTOs = dirtySessions.map { session in
                    FocusSessionSyncDTO(
                        id: session.id.uuidString,
                        taskId: session.taskServerId,
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
                }

                // 2. Get last session sync timestamp
                let lastSyncAt = await persistence.getLastSessionSyncTimestamp()

                // 3. Batch sync via POST /sync/sessions
                let request = SessionSyncRequest(
                    sessions: sessionDTOs,
                    lastSyncAt: lastSyncAt
                )

                let response = try await apiClient.syncSessions(request)

                // 4. Process response: upsert returned sessions locally
                for serverSession in response.sessions {
                    let exists = try await persistence.sessionExists(serverSession.id)
                    if !exists {
                        try await persistence.upsertSessionFromServer(serverSession)
                    }
                }

                // 4b. Resolve inbound task links (taskSyncId → local task)
                for serverSession in response.sessions {
                    guard let sessionUUID = UUID(uuidString: serverSession.id) else { continue }
                    if let taskSyncId = serverSession.taskSyncId, !taskSyncId.isEmpty {
                        if let task = try await persistence.fetchTaskBySyncId(taskSyncId) {
                            try await persistence.linkSessionToTask(sessionUUID, task.id)
                        }
                    } else if let taskId = serverSession.taskId {
                        if let task = try await persistence.fetchTaskByServerId(taskId) {
                            try await persistence.linkSessionToTask(sessionUUID, task.id)
                        }
                    }
                }

                // 5. Mark dirty sessions as synced
                if !dirtySessions.isEmpty {
                    let syncedIDs = dirtySessions.map(\.id)
                    try await persistence.markSessionsSynced(syncedIDs)
                }

                // 6. Store server timestamp
                await persistence.saveLastSessionSyncTimestamp(response.serverTimestamp)
            },
            syncSettings: {
                guard await keychain.hasTokens() else { return }
                guard AppGroupDefaults.isProUser else { return }

                let iso = ISO8601DateFormatter()

                // 1. Get dirty preference keys
                let dirtyKeys = PreferenceDirtyTracker.getDirtyKeys()

                // 2. Read all current preference values
                let allPrefs = await persistence.getAllPreferencesAsKeyValue()

                // 3. Build request with only dirty preferences
                let dirtyItems: [PreferenceSyncItem]
                if dirtyKeys.isEmpty {
                    dirtyItems = []
                } else {
                    dirtyItems = allPrefs
                        .filter { dirtyKeys.contains($0.key) }
                        .map { pref in
                            PreferenceSyncItem(
                                key: pref.key,
                                value: pref.value,
                                updatedAt: iso.string(from: pref.updatedAt)
                            )
                        }
                }

                let request = PreferenceSyncRequest(preferences: dirtyItems)

                // 4. PUT /preferences
                let response = try await apiClient.upsertPreferences(request)

                // 5. Apply server response (newer keys win — server handles LWW)
                for serverPref in response.preferences {
                    let serverDate = iso.date(from: serverPref.updatedAt) ?? Date.now
                    await persistence.applyServerPreference(serverPref.key, serverPref.value, serverDate)
                }

                // 6. Clear dirty keys
                PreferenceDirtyTracker.clearAll()
            },
            initialUpload: {
                guard await keychain.hasTokens() else {
                    throw SyncError.notAuthenticated
                }
                // initialUpload is allowed for all users (free + pro) to migrate
                // local data to the server on first authenticated session.

                let iso = ISO8601DateFormatter()
                let deviceId = keychain.getOrCreateDeviceId()

                // Collect all local tasks
                let allTasks = try await persistence.fetchTasks()
                let cachedUser = try await persistence.fetchCachedUser()
                let userId = cachedUser?.id

                var taskDTOs: [TaskSyncDTO] = []
                for task in allTasks where !task.isDeleted {
                    let subtasks = try await persistence.fetchSubtasks(task.id)
                    let subTaskDTOs = subtasks.map { SubTaskSyncDTO(
                        id: nil,
                        taskId: task.serverId,
                        title: $0.title,
                        isFinished: $0.isCompleted
                    ) }

                    taskDTOs.append(TaskSyncDTO(
                        id: task.serverId,
                        syncId: task.syncId,
                        userId: userId,
                        title: task.title,
                        description: task.notes,
                        energyLevel: task.energyLevel.rawValue.lowercased(),
                        recurrenceRule: task.recurrenceRule,
                        createdDate: iso.string(from: task.createdAt),
                        finishDate: task.dueDate.map { iso.string(from: $0) },
                        isFinished: task.isCompleted,
                        priority: task.priority.rawValue,
                        estimatedPomodoros: task.estimatedPomodoros,
                        completedPomodoros: task.completedPomodoros,
                        subTasks: subTaskDTOs.isEmpty ? nil : subTaskDTOs,
                        updatedAt: iso.string(from: task.updatedAt)
                    ))
                }

                // Collect all local sessions
                let startOfTime = Date.distantPast
                let sessions = try await persistence.fetchSessions(startOfTime, Date.now)
                let sessionDTOs = sessions.map { session in
                    FocusSessionSyncDTO(
                        id: session.id.uuidString,
                        taskId: session.taskServerId,
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
                }

                // Collect all local settings
                let allPrefs = await persistence.getAllPreferencesAsKeyValue()
                let settingItems = allPrefs.map { pref in
                    PreferenceSyncItem(
                        key: pref.key,
                        value: pref.value,
                        updatedAt: iso.string(from: pref.updatedAt)
                    )
                }

                // POST /sync/initial-upload
                let request = InitialUploadRequest(
                    deviceId: deviceId,
                    tasks: taskDTOs,
                    sessions: sessionDTOs,
                    settings: settingItems
                )

                let response = try await apiClient.initialUpload(request)

                // Process response
                for serverTask in response.tasks {
                    try await persistence.upsertTaskFromServer(serverTask)
                }
                for serverSession in response.sessions {
                    let exists = try await persistence.sessionExists(serverSession.id)
                    if !exists {
                        try await persistence.upsertSessionFromServer(serverSession)
                    }
                }
                // Resolve inbound task links for server sessions
                for serverSession in response.sessions {
                    guard let sessionUUID = UUID(uuidString: serverSession.id) else { continue }
                    if let taskSyncId = serverSession.taskSyncId, !taskSyncId.isEmpty {
                        if let task = try await persistence.fetchTaskBySyncId(taskSyncId) {
                            try await persistence.linkSessionToTask(sessionUUID, task.id)
                        }
                    } else if let taskId = serverSession.taskId {
                        if let task = try await persistence.fetchTaskByServerId(taskId) {
                            try await persistence.linkSessionToTask(sessionUUID, task.id)
                        }
                    }
                }
                for serverPref in response.settings {
                    let serverDate = iso.date(from: serverPref.updatedAt) ?? Date.now
                    await persistence.applyServerPreference(serverPref.key, serverPref.value, serverDate)
                }

                // Mark all as synced
                try await persistence.saveLastSyncTimestamp(response.serverTimestamp)
                await persistence.saveLastSessionSyncTimestamp(response.serverTimestamp)
                PreferenceDirtyTracker.clearAll()

                return response.hasExistingData
            },
            performInitialSync: {
                guard await keychain.hasTokens() else {
                    throw SyncError.notAuthenticated
                }
                // performInitialSync is allowed for all users (free + pro) to pull
                // server data on first authenticated session.

                let iso = ISO8601DateFormatter()
                var taskCursor: String? = nil
                var sessionCursor: String? = nil
                let pageLimit = 100

                // Paginated fetch loop
                var hasMoreData = true
                while hasMoreData {
                    let response = try await apiClient.getFullSync(taskCursor, sessionCursor, pageLimit)

                    // Process tasks
                    for serverTask in response.tasks.items {
                        try await persistence.upsertTaskFromServer(serverTask)
                    }

                    // Process sessions
                    for serverSession in response.sessions.items {
                        let exists = try await persistence.sessionExists(serverSession.id)
                        if !exists {
                            try await persistence.upsertSessionFromServer(serverSession)
                        }
                    }
                    // Resolve inbound task links for server sessions
                    for serverSession in response.sessions.items {
                        guard let sessionUUID = UUID(uuidString: serverSession.id) else { continue }
                        if let taskSyncId = serverSession.taskSyncId, !taskSyncId.isEmpty {
                            if let task = try await persistence.fetchTaskBySyncId(taskSyncId) {
                                try await persistence.linkSessionToTask(sessionUUID, task.id)
                            }
                        } else if let taskId = serverSession.taskId {
                            if let task = try await persistence.fetchTaskByServerId(taskId) {
                                try await persistence.linkSessionToTask(sessionUUID, task.id)
                            }
                        }
                    }

                    // Process settings (only on first page)
                    if taskCursor == nil && sessionCursor == nil {
                        for serverPref in response.settings {
                            let serverDate = iso.date(from: serverPref.updatedAt) ?? Date.now
                            await persistence.applyServerPreference(serverPref.key, serverPref.value, serverDate)
                        }
                    }

                    // Update cursors
                    taskCursor = response.tasks.nextCursor
                    sessionCursor = response.sessions.nextCursor
                    hasMoreData = response.tasks.hasMore || response.sessions.hasMore

                    // Save timestamp
                    try await persistence.saveLastSyncTimestamp(response.serverTimestamp)
                    await persistence.saveLastSessionSyncTimestamp(response.serverTimestamp)
                }

                PreferenceDirtyTracker.clearAll()
            },
            wipeAndSync: {
                guard await keychain.hasTokens() else {
                    throw SyncError.notAuthenticated
                }
                guard AppGroupDefaults.isProUser else { return }

                // Delete all local data
                await persistence.deleteAllTasks()
                await persistence.deleteAllSessions()
                await persistence.deleteAllStats()

                // Clear sync timestamps
                try await persistence.saveLastSyncTimestamp("")
                await persistence.saveLastSessionSyncTimestamp("")

                // Perform full download
                @Dependency(\.syncClient) var syncClient
                try await syncClient.performInitialSync()
            },
            hasLocalData: {
                let taskCount = await persistence.getTaskCount()
                let sessionCount = await persistence.getSessionCount()
                return taskCount > 0 || sessionCount > 0
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
