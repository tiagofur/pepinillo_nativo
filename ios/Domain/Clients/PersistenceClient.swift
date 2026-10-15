// PersistenceClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client for SwiftData persistence.
// Abstracts database operations for testability.

import Foundation
import SwiftData
import ComposableArchitecture

// MARK: - Sendable DTOs (Data Transfer Objects)

/// Sendable representation of TaskItem for crossing concurrency boundaries
public struct TaskItemDTO: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let notes: String?
    public let isCompleted: Bool
    public let priority: TaskPriority
    public let energyLevel: EnergyLevel
    public let estimatedPomodoros: Int
    public let completedPomodoros: Int
    public let sortOrder: Int
    public let subtasksCompleted: Int
    public let subtasksTotal: Int
    public let recurrenceRule: String?
    public let isRecurringTemplate: Bool
    public let dueDate: Date?
    public let scheduledForToday: Bool
    public let completedAt: Date?
    public let createdAt: Date

    // Sync metadata
    public let syncId: String
    public let serverId: Int?
    public let isDirty: Bool
    public let isDeleted: Bool
    public let syncedAt: Date?
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        isCompleted: Bool = false,
        priority: TaskPriority = .none,
        energyLevel: EnergyLevel = .deep,
        estimatedPomodoros: Int = 1,
        completedPomodoros: Int = 0,
        sortOrder: Int = 0,
        subtasksCompleted: Int = 0,
        subtasksTotal: Int = 0,
        recurrenceRule: String? = nil,
        isRecurringTemplate: Bool = false,
        dueDate: Date? = nil,
        scheduledForToday: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        syncId: String = UUID().uuidString,
        serverId: Int? = nil,
        isDirty: Bool = true,
        isDeleted: Bool = false,
        syncedAt: Date? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.isCompleted = isCompleted
        self.priority = priority
        self.energyLevel = energyLevel
        self.estimatedPomodoros = estimatedPomodoros
        self.completedPomodoros = completedPomodoros
        self.sortOrder = sortOrder
        self.subtasksCompleted = subtasksCompleted
        self.subtasksTotal = subtasksTotal
        self.recurrenceRule = recurrenceRule
        self.isRecurringTemplate = isRecurringTemplate
        self.dueDate = dueDate
        self.scheduledForToday = scheduledForToday
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.syncId = syncId
        self.serverId = serverId
        self.isDirty = isDirty
        self.isDeleted = isDeleted
        self.syncedAt = syncedAt
        self.updatedAt = updatedAt
    }

    /// Maps a TaskItem to a DTO. When `subtaskProgress` is provided the subtask
    /// relationship is NOT faulted (avoids N+1 during list mapping); when nil it
    /// falls back to the per-task computed progress.
    init(from task: TaskItem, subtaskProgress: (completed: Int, total: Int)? = nil) {
        self.id = task.id
        self.title = task.title
        self.notes = task.notes
        self.isCompleted = task.isCompleted
        self.priority = task.priority
        self.energyLevel = task.energyLevel
        self.estimatedPomodoros = task.estimatedPomodoros
        self.completedPomodoros = task.completedPomodoros
        self.sortOrder = task.sortOrder
        let progress = subtaskProgress ?? task.subtaskProgress
        self.subtasksCompleted = progress.completed
        self.subtasksTotal = progress.total
        self.recurrenceRule = task.recurrenceRule
        self.isRecurringTemplate = task.isRecurringTemplate
        self.dueDate = task.dueDate
        self.scheduledForToday = task.scheduledForToday
        self.completedAt = task.completedAt
        self.createdAt = task.createdAt
        self.syncId = task.syncId
        self.serverId = task.serverId
        self.isDirty = task.isDirty
        self.isDeleted = task.isLocallyDeleted
        self.syncedAt = task.syncedAt
        self.updatedAt = task.updatedAt
    }

    /// Returns a copy with selective field overrides. Use after `fetchTask` to
    /// avoid partial DTO rebuilds that wipe recurrence/sync metadata (issue #178).
    public func updating(
        isCompleted: Bool? = nil,
        energyLevel: EnergyLevel? = nil
    ) -> TaskItemDTO {
        TaskItemDTO(
            id: id,
            title: title,
            notes: notes,
            isCompleted: isCompleted ?? self.isCompleted,
            priority: priority,
            energyLevel: energyLevel ?? self.energyLevel,
            estimatedPomodoros: estimatedPomodoros,
            completedPomodoros: completedPomodoros,
            sortOrder: sortOrder,
            subtasksCompleted: subtasksCompleted,
            subtasksTotal: subtasksTotal,
            recurrenceRule: recurrenceRule,
            isRecurringTemplate: isRecurringTemplate,
            dueDate: dueDate,
            scheduledForToday: scheduledForToday,
            completedAt: completedAt,
            createdAt: createdAt,
            syncId: syncId,
            serverId: serverId,
            isDirty: isDirty,
            isDeleted: isDeleted,
            syncedAt: syncedAt,
            updatedAt: updatedAt
        )
    }
}

/// Sendable representation of SubTask for crossing concurrency boundaries
public struct SubTaskDTO: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let isCompleted: Bool
    public let sortOrder: Int

    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
    }

    init(from subtask: SubTask) {
        self.id = subtask.id
        self.title = subtask.title
        self.isCompleted = subtask.isCompleted
        self.sortOrder = subtask.sortOrder
    }
}

/// Sendable representation of FocusSessionRecord
public struct SessionRecordDTO: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let startedAt: Date
    public let endedAt: Date?
    public let mode: String
    public let phase: String
    public let targetDuration: TimeInterval?
    public let actualDuration: TimeInterval
    public let wasCompleted: Bool
    public let interruptions: Int
    public let pauseCount: Int
    public let totalPauseDuration: TimeInterval
    public let pomodoroNumber: Int?
    public let taskID: UUID?
    public let taskServerId: Int?
    public let journalNote: String?
    public let satisfactionRating: Int?
    public let isDirty: Bool
    public let syncedAt: Date?

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        mode: String,
        phase: String = "work",
        targetDuration: TimeInterval? = nil,
        actualDuration: TimeInterval,
        wasCompleted: Bool,
        interruptions: Int,
        pauseCount: Int = 0,
        totalPauseDuration: TimeInterval = 0,
        pomodoroNumber: Int? = nil,
        taskID: UUID?,
        taskServerId: Int? = nil,
        journalNote: String? = nil,
        satisfactionRating: Int? = nil,
        isDirty: Bool = true,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.mode = mode
        self.phase = phase
        self.targetDuration = targetDuration
        self.actualDuration = actualDuration
        self.wasCompleted = wasCompleted
        self.interruptions = interruptions
        self.pauseCount = pauseCount
        self.totalPauseDuration = totalPauseDuration
        self.pomodoroNumber = pomodoroNumber
        self.taskID = taskID
        self.taskServerId = taskServerId
        self.journalNote = journalNote
        self.satisfactionRating = satisfactionRating
        self.isDirty = isDirty
        self.syncedAt = syncedAt
    }

    init(from record: FocusSessionRecord) {
        self.init(
            id: record.id,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            mode: record.mode,
            phase: record.phase,
            targetDuration: record.targetDuration,
            actualDuration: record.actualDuration,
            wasCompleted: record.wasCompleted,
            interruptions: record.interruptions,
            pauseCount: record.pauseCount,
            totalPauseDuration: record.totalPauseDuration,
            pomodoroNumber: record.pomodoroNumber,
            taskID: record.task?.id,
            taskServerId: record.task?.serverId,
            journalNote: record.journalNote,
            satisfactionRating: record.satisfactionRating,
            isDirty: record.isDirty,
            syncedAt: record.syncedAt
        )
    }
}

/// Computed per-task analytics (NOT a SwiftData model)
public struct TaskAnalyticsDTO: Sendable, Equatable {
    public let taskID: UUID
    public let taskTitle: String
    public let totalSessions: Int
    public let completedSessions: Int
    public let totalFocusSeconds: Int
    public let avgSessionSeconds: Int
    public let totalInterruptions: Int
    public let avgInterruptionsPerSession: Double
    public let totalPauses: Int
    public let avgSatisfactionRating: Double?
    public let modeDistribution: [String: Int]   // mode → seconds
    public let peakHourBucket: Int?
    public let estimatedPomodoros: Int
    public let completedPomodoros: Int
    public let estimationAccuracy: Double?

    public init(
        taskID: UUID,
        taskTitle: String,
        totalSessions: Int,
        completedSessions: Int,
        totalFocusSeconds: Int,
        avgSessionSeconds: Int,
        totalInterruptions: Int,
        avgInterruptionsPerSession: Double,
        totalPauses: Int,
        avgSatisfactionRating: Double?,
        modeDistribution: [String: Int],
        peakHourBucket: Int?,
        estimatedPomodoros: Int,
        completedPomodoros: Int,
        estimationAccuracy: Double?
    ) {
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.totalSessions = totalSessions
        self.completedSessions = completedSessions
        self.totalFocusSeconds = totalFocusSeconds
        self.avgSessionSeconds = avgSessionSeconds
        self.totalInterruptions = totalInterruptions
        self.avgInterruptionsPerSession = avgInterruptionsPerSession
        self.totalPauses = totalPauses
        self.avgSatisfactionRating = avgSatisfactionRating
        self.modeDistribution = modeDistribution
        self.peakHourBucket = peakHourBucket
        self.estimatedPomodoros = estimatedPomodoros
        self.completedPomodoros = completedPomodoros
        self.estimationAccuracy = estimationAccuracy
    }
}

/// Sendable representation of CachedUser for crossing concurrency boundaries
public struct CachedUserDTO: Sendable, Equatable {
    public let id: String
    public let email: String
    public let name: String
    public let imageUrl: String?
    public let subscriptionTier: String
    public let subscriptionExpiresAt: String?
    public let emailVerified: Bool
    public let appleId: String?
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String, email: String, name: String,
        imageUrl: String? = nil,
        subscriptionTier: String = "free", subscriptionExpiresAt: String? = nil,
        emailVerified: Bool = false, appleId: String? = nil,
        createdAt: String = "", updatedAt: String = ""
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.imageUrl = imageUrl
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.emailVerified = emailVerified
        self.appleId = appleId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from user: CachedUser) {
        self.id = user.id
        self.email = user.email
        self.name = user.name
        self.imageUrl = user.imageUrl
        self.subscriptionTier = user.subscriptionTier
        self.subscriptionExpiresAt = user.subscriptionExpiresAt
        self.emailVerified = user.emailVerified
        self.appleId = user.appleId
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
}

/// Sendable representation of DailyStats
public struct DailyStatsDTO: Sendable, Equatable {
    public let date: Date
    public let totalFocusMinutes: Int
    public let sessionsCompleted: Int
    public let tasksCompleted: Int

    // Per-mode breakdown (minutes)
    public let pomodoroMinutes: Int
    public let flowtimeMinutes: Int
    public let timeBlockMinutes: Int
    public let stopwatchMinutes: Int

    init(
        date: Date,
        totalFocusMinutes: Int,
        sessionsCompleted: Int,
        tasksCompleted: Int,
        pomodoroMinutes: Int = 0,
        flowtimeMinutes: Int = 0,
        timeBlockMinutes: Int = 0,
        stopwatchMinutes: Int = 0
    ) {
        self.date = date
        self.totalFocusMinutes = totalFocusMinutes
        self.sessionsCompleted = sessionsCompleted
        self.tasksCompleted = tasksCompleted
        self.pomodoroMinutes = pomodoroMinutes
        self.flowtimeMinutes = flowtimeMinutes
        self.timeBlockMinutes = timeBlockMinutes
        self.stopwatchMinutes = stopwatchMinutes
    }

    init(from stats: DailyStats) {
        self.init(
            date: stats.date,
            totalFocusMinutes: stats.totalFocusMinutes,
            sessionsCompleted: stats.sessionsCompleted,
            tasksCompleted: stats.tasksCompleted,
            pomodoroMinutes: stats.pomodoroSeconds / 60,
            flowtimeMinutes: stats.flowtimeSeconds / 60,
            timeBlockMinutes: stats.timeBlockSeconds / 60,
            stopwatchMinutes: stats.stopwatchSeconds / 60
        )
    }
}

/// Sendable representation of UserPreferences
public struct UserPreferencesDTO: Sendable, Equatable {
    public var pomodoroDuration: TimeInterval
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    public var pomodorosPerCycle: Int
    public var autoStartBreaks: Bool
    public var autoStartWork: Bool
    public var defaultBlockDuration: TimeInterval
    public var blockMidpointCheckIn: Bool
    public var flowtimeMinSessionMinutes: Int
    public var flowtimeShowBreakSuggestion: Bool
    public var soundEnabled: Bool
    public var hapticEnabled: Bool
    public var keepScreenOn: Bool
    public var defaultMode: String
    public var themeName: String
    public var followSystemAppearance: Bool
    public var appearanceMode: String
    public var dailyReminderEnabled: Bool
    public var dailyReminderHour: Int
    public var dailyReminderMinute: Int
    public var hasCompletedOnboarding: Bool
    public var currentStreakDays: Int
    public var longestStreakDays: Int
    public var lastFocusDate: Date?
    public var showJournalAfterSession: Bool
    public var healthLoggingEnabled: Bool
    public var adhdFriendlyEnabled: Bool
    public var calendarIntegrationEnabled: Bool
    public var isProUser: Bool
    public var subscriptionExpiresAt: Date?
    public var appleUserID: String?
    public var displayName: String?
    public var userEmail: String?
    /// Apple authorization code captured at the last Sign in with Apple flow.
    /// Sent to the backend on account deletion so Apple user tokens can be
    /// revoked (Sign in with Apple requirement, #196).
    public var appleAuthorizationCode: String?

    public init(soundEnabled: Bool = true, hapticEnabled: Bool = true, defaultMode: String = "pomodoro", themeName: String = "default") {
        self.pomodoroDuration = 25 * 60
        self.shortBreakDuration = 5 * 60
        self.longBreakDuration = 15 * 60
        self.pomodorosPerCycle = 4
        self.autoStartBreaks = true
        self.autoStartWork = false
        self.defaultBlockDuration = 60 * 60
        self.blockMidpointCheckIn = false
        self.flowtimeMinSessionMinutes = 5
        self.flowtimeShowBreakSuggestion = true
        self.soundEnabled = soundEnabled
        self.hapticEnabled = hapticEnabled
        self.keepScreenOn = false
        self.defaultMode = defaultMode
        self.themeName = themeName
        self.followSystemAppearance = true
        self.appearanceMode = "system"
        self.dailyReminderEnabled = false
        self.dailyReminderHour = 9
        self.dailyReminderMinute = 0
        self.hasCompletedOnboarding = false
        self.currentStreakDays = 0
        self.longestStreakDays = 0
        self.showJournalAfterSession = true
        self.healthLoggingEnabled = false
        self.adhdFriendlyEnabled = false
        self.calendarIntegrationEnabled = false
        self.isProUser = false
        self.appleUserID = nil
        self.displayName = nil
        self.userEmail = nil
        self.appleAuthorizationCode = nil
    }

    init(from prefs: UserPreferences) {
        self.pomodoroDuration = prefs.pomodoroDuration
        self.shortBreakDuration = prefs.shortBreakDuration
        self.longBreakDuration = prefs.longBreakDuration
        self.pomodorosPerCycle = prefs.pomodorosPerCycle
        self.autoStartBreaks = prefs.autoStartBreaks
        self.autoStartWork = prefs.autoStartWork
        self.defaultBlockDuration = prefs.defaultBlockDuration
        self.blockMidpointCheckIn = prefs.blockMidpointCheckIn
        self.flowtimeMinSessionMinutes = prefs.flowtimeMinSessionMinutes
        self.flowtimeShowBreakSuggestion = prefs.flowtimeShowBreakSuggestion
        self.soundEnabled = prefs.soundEnabled
        self.hapticEnabled = prefs.hapticEnabled
        self.keepScreenOn = prefs.keepScreenOn
        self.defaultMode = prefs.defaultMode
        self.themeName = prefs.themeName
        self.followSystemAppearance = prefs.followSystemAppearance
        self.appearanceMode = prefs.appearanceMode
        self.dailyReminderEnabled = prefs.dailyReminderEnabled
        self.dailyReminderHour = prefs.dailyReminderHour
        self.dailyReminderMinute = prefs.dailyReminderMinute
        self.hasCompletedOnboarding = prefs.hasCompletedOnboarding
        self.currentStreakDays = prefs.currentStreakDays
        self.longestStreakDays = prefs.longestStreakDays
        self.lastFocusDate = prefs.lastFocusDate
        self.showJournalAfterSession = prefs.showJournalAfterSession
        self.healthLoggingEnabled = prefs.healthLoggingEnabled
        self.adhdFriendlyEnabled = prefs.adhdFriendlyEnabled
        self.calendarIntegrationEnabled = prefs.calendarIntegrationEnabled
        self.isProUser = prefs.isProUser
        self.subscriptionExpiresAt = prefs.subscriptionExpiresAt
        self.appleUserID = prefs.appleUserID
        self.displayName = prefs.displayName
        self.userEmail = prefs.userEmail
        self.appleAuthorizationCode = prefs.appleAuthorizationCode
    }
}

@DependencyClient
public struct PersistenceClient: Sendable {
    // Tasks
    public var fetchTasks: @Sendable () async throws -> [TaskItemDTO] = { [] }
    public var fetchTask: @Sendable (UUID) async throws -> TaskItemDTO? = { _ in nil }
    public var saveTask: @Sendable (TaskItemDTO) async throws -> Void
    public var saveTaskOrder: @Sendable ([(id: UUID, sortOrder: Int)]) async throws -> Void = { _ in }
    public var incrementTaskPomodoros: @Sendable (UUID) async throws -> Void
    public var deleteTask: @Sendable (UUID) async throws -> Void
    /// Clears soft-delete on an existing row, or re-inserts when the row was hard-deleted (undo).
    public var restoreTask: @Sendable (TaskItemDTO) async throws -> Void

    // Subtasks
    public var fetchSubtasks: @Sendable (UUID) async throws -> [SubTaskDTO] = { _ in [] }
    public var fetchSubtasksForTasks: @Sendable ([UUID]) async throws -> [UUID: [SubTaskDTO]] = { _ in [:] }
    public var addSubtask: @Sendable (UUID, String) async throws -> SubTaskDTO
    public var toggleSubtask: @Sendable (UUID) async throws -> Void
    public var deleteSubtask: @Sendable (UUID) async throws -> Void
    public var fetchTaskTotalFocusSeconds: @Sendable (UUID) async throws -> TimeInterval = { _ in 0 }

    // Sessions
    public var saveSession: @Sendable (FocusSessionResult) async throws -> Void
    /// Rebuild DailyStats aggregates from stored sessions (S4).
    public var rebuildDailyStatsFromSessions: @Sendable () async throws -> Void
    public var fetchSessions: @Sendable (Date, Date) async throws -> [SessionRecordDTO] = { _, _ in [] }
    // Lifetime aggregate counts (issue #73) — cheap SQLite COUNTs bounded by `from`.
    public var fetchSessionCount: @Sendable (Date) async throws -> Int = { _ in 0 }
    public var fetchEarlyBirdSessionCount: @Sendable (Date) async throws -> Int = { _ in 0 }
    public var fetchCompletedPomodoroCount: @Sendable (Date) async throws -> Int = { _ in 0 }
    public var fetchCompletedFlowtimeCount: @Sendable (Date) async throws -> Int = { _ in 0 }
    public var fetchSessionsForTask: @Sendable (UUID) async throws -> [SessionRecordDTO] = { _ in [] }
    public var fetchSessionsForTasks: @Sendable ([UUID]) async throws -> [UUID: [SessionRecordDTO]] = { _ in [:] }
    public var fetchTaskAnalytics: @Sendable (UUID) async throws -> TaskAnalyticsDTO
    public var saveJournalEntry: @Sendable (UUID, String?, Int?) async throws -> Void

    // Daily Stats
    public var fetchDailyStats: @Sendable (Date) async throws -> DailyStatsDTO? = { _ in nil }
    public var fetchDailyStatsRange: @Sendable (Date, Date) async throws -> [DailyStatsDTO] = { _, _ in [] }

    // Preferences
    public var fetchPreferences: @Sendable () async throws -> UserPreferencesDTO = {
        UserPreferencesDTO(soundEnabled: true, hapticEnabled: true, defaultMode: "pomodoro", themeName: "default")
    }
    public var savePreferences: @Sendable (UserPreferencesDTO) async throws -> Void

    // Achievements (S1-S2): seed the store from derived achievements on first
    // load and overlay stored first-unlock dates. No default on purpose —
    // tests must stub explicitly so silent fallbacks never mask wiring gaps.
    public var resolveAchievements: @Sendable ([UserAchievement]) async throws -> [UserAchievement]

    // Cached User
    public var fetchCachedUser: @Sendable () async throws -> CachedUserDTO? = { nil }
    public var saveCachedUser: @Sendable (CachedUserDTO) async throws -> Void
    public var deleteCachedUser: @Sendable () async throws -> Void

    // Recurring Tasks
    public var generateRecurringTasks: @Sendable () async throws -> Void

    // Sync Operations
    public var fetchDirtyTasks: @Sendable () async throws -> [TaskItemDTO] = { [] }
    public var markTasksSynced: @Sendable (_ syncIds: [String], _ syncTimestamp: String) async throws -> Void
    public var upsertTaskFromServer: @Sendable (TaskSyncDTO, Bool) async throws -> Void
    public var save: @Sendable () async throws -> Void
    public var purgeTaskBySyncId: @Sendable (String) async throws -> Void
    public var getLastSyncTimestamp: @Sendable () async throws -> String? = { nil }
    public var saveLastSyncTimestamp: @Sendable (String) async throws -> Void

    // Session Sync Operations
    public var fetchDirtySessions: @Sendable () async throws -> [SessionRecordDTO] = { [] }
    public var markSessionsSynced: @Sendable ([UUID]) async throws -> Void
    public var upsertSessionFromServer: @Sendable (FocusSessionSyncDTO, Bool) async throws -> Void
    public var sessionExists: @Sendable (String) async throws -> Bool = { _ in false }

    // Task-Session Link Resolution
    public var fetchTaskBySyncId: @Sendable (String) async throws -> TaskItemDTO? = { _ in nil }
    public var fetchTaskByServerId: @Sendable (Int) async throws -> TaskItemDTO? = { _ in nil }
    public var linkSessionToTask: @Sendable (_ sessionId: UUID, _ taskId: UUID, _ saveImmediately: Bool) async throws -> Void

    // Settings Sync
    public var getAllPreferencesAsKeyValue: @Sendable () async -> [(key: String, value: String, updatedAt: Date)] = { [] }
    public var applyServerPreference: @Sendable (_ key: String, _ value: String, _ updatedAt: Date) async -> Void

    // Wipe and Sync (throwing — callers must handle failure to avoid partial wipes)
    public var deleteAllTasks: @Sendable () async throws -> Void
    public var deleteAllSessions: @Sendable () async throws -> Void
    public var deleteAllStats: @Sendable () async throws -> Void

    // Counts
    public var getTaskCount: @Sendable () async -> Int = { 0 }
    public var getSessionCount: @Sendable () async -> Int = { 0 }

    // Session Sync Timestamp
    public var getLastSessionSyncTimestamp: @Sendable () async -> String? = { nil }
    public var saveLastSessionSyncTimestamp: @Sendable (String) async -> Void
}

extension PersistenceClient: DependencyKey {
    /// Default stub — replaced at app startup with live(container:).
    public static let liveValue = PersistenceClient()

    public static let testValue = PersistenceClient()

    /// Live implementation backed by SwiftData.
    public static func live(container: ModelContainer) -> PersistenceClient {
        let actor = BackgroundPersistenceActor(modelContainer: container)
        return live(actorProvider: { actor })
    }

    /// Live implementation backed by an actor provider so the active store can
    /// move from local SwiftData to the Apple Cloud store after launch. The
    /// provider always vends the currently-active BackgroundPersistenceActor,
    /// so every operation runs off the main thread on a background ModelContext.
    public static func live(
        actorProvider: @escaping @Sendable () -> BackgroundPersistenceActor
    ) -> PersistenceClient {
        return PersistenceClient(
            fetchTasks: {
                try await actorProvider().fetchTasks()
            },
            fetchTask: { id in
                try await actorProvider().fetchTask(by: id)
            },
            saveTask: { taskDTO in
                try await actorProvider().saveTask(taskDTO)
            },
            saveTaskOrder: { order in
                try await actorProvider().saveTaskOrder(order)
            },
            incrementTaskPomodoros: { id in
                try await actorProvider().incrementTaskPomodoros(id: id)
            },
            deleteTask: { id in
                try await actorProvider().deleteTask(id: id)
            },
            restoreTask: { taskDTO in
                try await actorProvider().restoreTask(taskDTO)
            },
            fetchSubtasks: { taskID in
                try await actorProvider().fetchSubtasks(for: taskID)
            },
            fetchSubtasksForTasks: { taskIDs in
                try await actorProvider().fetchSubtasksForTasks(taskIDs: taskIDs)
            },
            addSubtask: { taskID, title in
                try await actorProvider().addSubtask(to: taskID, title: title)
            },
            toggleSubtask: { id in
                try await actorProvider().toggleSubtask(id: id)
            },
            deleteSubtask: { id in
                try await actorProvider().deleteSubtask(id: id)
            },
            fetchTaskTotalFocusSeconds: { taskID in
                try await actorProvider().fetchTaskTotalFocusSeconds(for: taskID)
            },
            saveSession: { result in
                try await actorProvider().saveSession(result)
            },
            rebuildDailyStatsFromSessions: {
                try await actorProvider().rebuildDailyStatsFromSessions()
            },
            fetchSessions: { start, end in
                try await actorProvider().fetchSessions(from: start, to: end)
            },
            fetchSessionCount: { from in
                try await actorProvider().fetchSessionCount(from: from)
            },
            fetchEarlyBirdSessionCount: { from in
                try await actorProvider().fetchEarlyBirdSessionCount(from: from)
            },
            fetchCompletedPomodoroCount: { from in
                try await actorProvider().fetchCompletedPomodoroCount(from: from)
            },
            fetchCompletedFlowtimeCount: { from in
                try await actorProvider().fetchCompletedFlowtimeCount(from: from)
            },
            fetchSessionsForTask: { taskID in
                try await actorProvider().fetchSessionsForTask(taskID: taskID)
            },
            fetchSessionsForTasks: { taskIDs in
                try await actorProvider().fetchSessionsForTasks(taskIDs: taskIDs)
            },
            fetchTaskAnalytics: { taskID in
                try await actorProvider().fetchTaskAnalytics(taskID: taskID)
            },
            saveJournalEntry: { sessionID, note, rating in
                try await actorProvider().saveJournalEntry(sessionID: sessionID, note: note, rating: rating)
            },
            fetchDailyStats: { date in
                try await actorProvider().fetchDailyStats(for: date)
            },
            fetchDailyStatsRange: { start, end in
                try await actorProvider().fetchDailyStatsRange(from: start, to: end)
            },
            fetchPreferences: {
                try await actorProvider().fetchPreferences()
            },
            savePreferences: { prefsDTO in
                try await actorProvider().savePreferences(prefsDTO)
            },
            resolveAchievements: { derived in
                try await actorProvider().resolveAchievements(derived)
            },
            fetchCachedUser: {
                try await actorProvider().fetchCachedUser()
            },
            saveCachedUser: { dto in
                try await actorProvider().saveCachedUser(dto)
            },
            deleteCachedUser: {
                try await actorProvider().deleteCachedUser()
            },
            generateRecurringTasks: {
                try await actorProvider().generateRecurringTasks()
            },
            fetchDirtyTasks: {
                try await actorProvider().fetchDirtyTasks()
            },
            markTasksSynced: { syncIds, syncTimestamp in
                try await actorProvider().markTasksSynced(syncIds: syncIds, syncTimestamp: syncTimestamp)
            },
            upsertTaskFromServer: { serverTask, saveImmediately in
                try await actorProvider().upsertTaskFromServer(serverTask, saveImmediately: saveImmediately)
            },
            save: {
                try await actorProvider().save()
            },
            purgeTaskBySyncId: { syncId in
                try await actorProvider().purgeTaskBySyncId(syncId)
            },
            getLastSyncTimestamp: {
                await actorProvider().getLastSyncTimestamp()
            },
            saveLastSyncTimestamp: { timestamp in
                await actorProvider().saveLastSyncTimestamp(timestamp)
            },
            fetchDirtySessions: {
                try await actorProvider().fetchDirtySessions()
            },
            markSessionsSynced: { sessionIDs in
                try await actorProvider().markSessionsSynced(ids: sessionIDs)
            },
            upsertSessionFromServer: { dto, saveImmediately in
                try await actorProvider().upsertSessionFromServer(dto, saveImmediately: saveImmediately)
            },
            sessionExists: { sessionId in
                try await actorProvider().sessionExists(id: sessionId)
            },
            fetchTaskBySyncId: { syncId in
                try await actorProvider().fetchTaskBySyncId(syncId)
            },
            fetchTaskByServerId: { serverId in
                try await actorProvider().fetchTaskByServerId(serverId)
            },
            linkSessionToTask: { sessionId, taskId, saveImmediately in
                try await actorProvider().linkSessionToTask(sessionId: sessionId, taskId: taskId, saveImmediately: saveImmediately)
            },
            getAllPreferencesAsKeyValue: {
                await actorProvider().getAllPreferencesAsKeyValue()
            },
            applyServerPreference: { key, value, updatedAt in
                await actorProvider().applyServerPreference(key: key, value: value, updatedAt: updatedAt)
            },
            deleteAllTasks: {
                try await actorProvider().deleteAllTasks()
            },
            deleteAllSessions: {
                try await actorProvider().deleteAllSessions()
            },
            deleteAllStats: {
                try await actorProvider().deleteAllStats()
            },
            getTaskCount: {
                await actorProvider().getTaskCount()
            },
            getSessionCount: {
                await actorProvider().getSessionCount()
            },
            getLastSessionSyncTimestamp: {
                await actorProvider().getLastSessionSyncTimestamp()
            },
            saveLastSessionSyncTimestamp: { timestamp in
                await actorProvider().saveLastSessionSyncTimestamp(timestamp)
            }
        )
    }
}

extension DependencyValues {
    public var persistenceClient: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
