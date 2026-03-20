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
        createdAt: Date = .now
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
    }

    init(from task: TaskItem) {
        self.id = task.id
        self.title = task.title
        self.notes = task.notes
        self.isCompleted = task.isCompleted
        self.priority = task.priority
        self.energyLevel = task.energyLevel
        self.estimatedPomodoros = task.estimatedPomodoros
        self.completedPomodoros = task.completedPomodoros
        self.sortOrder = task.sortOrder
        let progress = task.subtaskProgress
        self.subtasksCompleted = progress.completed
        self.subtasksTotal = progress.total
        self.recurrenceRule = task.recurrenceRule
        self.isRecurringTemplate = task.isRecurringTemplate
        self.dueDate = task.dueDate
        self.scheduledForToday = task.scheduledForToday
        self.completedAt = task.completedAt
        self.createdAt = task.createdAt
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
    public let journalNote: String?
    public let satisfactionRating: Int?

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
        journalNote: String? = nil,
        satisfactionRating: Int? = nil
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
        self.journalNote = journalNote
        self.satisfactionRating = satisfactionRating
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
            journalNote: record.journalNote,
            satisfactionRating: record.satisfactionRating
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
    }
}

@DependencyClient
public struct PersistenceClient: Sendable {
    // Tasks
    public var fetchTasks: @Sendable () async throws -> [TaskItemDTO] = { [] }
    public var saveTask: @Sendable (TaskItemDTO) async throws -> Void
    public var deleteTask: @Sendable (UUID) async throws -> Void

    // Subtasks
    public var fetchSubtasks: @Sendable (UUID) async throws -> [SubTaskDTO] = { _ in [] }
    public var addSubtask: @Sendable (UUID, String) async throws -> SubTaskDTO
    public var toggleSubtask: @Sendable (UUID) async throws -> Void
    public var deleteSubtask: @Sendable (UUID) async throws -> Void
    public var fetchTaskTotalFocusSeconds: @Sendable (UUID) async throws -> TimeInterval = { _ in 0 }

    // Sessions
    public var saveSession: @Sendable (FocusSessionResult) async throws -> Void
    public var fetchSessions: @Sendable (Date, Date) async throws -> [SessionRecordDTO] = { _, _ in [] }
    public var fetchSessionsForTask: @Sendable (UUID) async throws -> [SessionRecordDTO] = { _ in [] }
    public var fetchTaskAnalytics: @Sendable (UUID) async throws -> TaskAnalyticsDTO
    public var saveJournalEntry: @Sendable (UUID, String?, Int?) async throws -> Void

    // Daily Stats
    public var fetchDailyStats: @Sendable (Date) async throws -> DailyStatsDTO? = { _ in nil }

    // Preferences
    public var fetchPreferences: @Sendable () async throws -> UserPreferencesDTO = {
        UserPreferencesDTO(soundEnabled: true, hapticEnabled: true, defaultMode: "pomodoro", themeName: "default")
    }
    public var savePreferences: @Sendable (UserPreferencesDTO) async throws -> Void

    // Recurring Tasks
    public var generateRecurringTasks: @Sendable () async throws -> Void
}

extension PersistenceClient: DependencyKey {
    /// Default stub — replaced at app startup with live(container:).
    public static let liveValue = PersistenceClient()

    public static let testValue = PersistenceClient()

    /// Live implementation backed by SwiftData.
    @MainActor
    public static func live(container: ModelContainer) -> PersistenceClient {
        let service = SwiftDataPersistenceService(container: container)

        return PersistenceClient(
            fetchTasks: {
                try await MainActor.run {
                    let tasks = try service.fetchTasks()
                    return tasks.map { TaskItemDTO(from: $0) }
                }
            },
            saveTask: { taskDTO in
                try await MainActor.run {
                    let tasks = try service.fetchTasks()
                    if let existing = tasks.first(where: { $0.id == taskDTO.id }) {
                        existing.title = taskDTO.title
                        existing.notes = taskDTO.notes
                        if existing.isCompleted != taskDTO.isCompleted {
                            existing.isCompleted = taskDTO.isCompleted
                            existing.completedAt = taskDTO.isCompleted ? Date.now : nil
                        }
                        existing.priority = taskDTO.priority
                        existing.energyLevel = taskDTO.energyLevel
                        existing.estimatedPomodoros = taskDTO.estimatedPomodoros
                        existing.completedPomodoros = taskDTO.completedPomodoros
                        existing.sortOrder = taskDTO.sortOrder
                        existing.recurrenceRule = taskDTO.recurrenceRule
                        existing.isRecurringTemplate = taskDTO.isRecurringTemplate
                        existing.dueDate = taskDTO.dueDate
                        existing.scheduledForToday = taskDTO.scheduledForToday
                        // Set nextOccurrence when recurrence rule is first applied
                        if taskDTO.isRecurringTemplate, existing.nextOccurrence == nil,
                           let rule = taskDTO.recurrenceRule,
                           let preset = RecurrencePreset.from(rule: rule) {
                            existing.nextOccurrence = preset.nextDate(after: Calendar.current.startOfDay(for: .now))
                        } else if !taskDTO.isRecurringTemplate {
                            existing.nextOccurrence = nil
                        }
                        try service.saveTask(existing)
                    } else {
                        let newTask = TaskItem(
                            title: taskDTO.title,
                            notes: taskDTO.notes,
                            priority: taskDTO.priority,
                            energyLevel: taskDTO.energyLevel,
                            estimatedPomodoros: taskDTO.estimatedPomodoros,
                            sortOrder: taskDTO.sortOrder
                        )
                        newTask.id = taskDTO.id
                        newTask.isCompleted = taskDTO.isCompleted
                        newTask.completedPomodoros = taskDTO.completedPomodoros
                        newTask.recurrenceRule = taskDTO.recurrenceRule
                        newTask.isRecurringTemplate = taskDTO.isRecurringTemplate
                        newTask.dueDate = taskDTO.dueDate
                        newTask.scheduledForToday = taskDTO.scheduledForToday
                        if taskDTO.isRecurringTemplate,
                           let rule = taskDTO.recurrenceRule,
                           let preset = RecurrencePreset.from(rule: rule) {
                            newTask.nextOccurrence = preset.nextDate(after: Calendar.current.startOfDay(for: .now))
                        }
                        try service.saveTask(newTask)
                    }
                }
            },
            deleteTask: { id in
                try await MainActor.run { try service.deleteTask(id: id) }
            },
            fetchSubtasks: { taskID in
                try await MainActor.run {
                    let subtasks = try service.fetchSubtasks(for: taskID)
                    return subtasks.map { SubTaskDTO(from: $0) }
                }
            },
            addSubtask: { taskID, title in
                try await MainActor.run {
                    let subtask = try service.addSubtask(to: taskID, title: title)
                    return SubTaskDTO(from: subtask)
                }
            },
            toggleSubtask: { id in
                try await MainActor.run { try service.toggleSubtask(id: id) }
            },
            deleteSubtask: { id in
                try await MainActor.run { try service.deleteSubtask(id: id) }
            },
            fetchTaskTotalFocusSeconds: { taskID in
                try await MainActor.run { try service.fetchTaskTotalFocusSeconds(for: taskID) }
            },
            saveSession: { result in
                try await MainActor.run { try service.saveSession(result) }
            },
            fetchSessions: { start, end in
                try await MainActor.run {
                    let records = try service.fetchSessions(from: start, to: end)
                    return records.map { SessionRecordDTO(from: $0) }
                }
            },
            fetchSessionsForTask: { taskID in
                try await MainActor.run {
                    let records = try service.fetchSessionsForTask(taskID: taskID)
                    return records.map { SessionRecordDTO(from: $0) }
                }
            },
            fetchTaskAnalytics: { taskID in
                try await MainActor.run {
                    try service.fetchTaskAnalytics(taskID: taskID)
                }
            },
            saveJournalEntry: { sessionID, note, rating in
                try await MainActor.run {
                    try service.saveJournalEntry(sessionID: sessionID, note: note, rating: rating)
                }
            },
            fetchDailyStats: { date in
                try await MainActor.run {
                    guard let stats = try service.fetchDailyStats(for: date) else { return nil }
                    return DailyStatsDTO(from: stats)
                }
            },
            fetchPreferences: {
                try await MainActor.run {
                    let prefs = try service.fetchPreferences()
                    return UserPreferencesDTO(from: prefs)
                }
            },
            savePreferences: { prefsDTO in
                try await MainActor.run {
                    let prefs = try service.fetchPreferences()
                    prefs.pomodoroDuration = prefsDTO.pomodoroDuration
                    prefs.shortBreakDuration = prefsDTO.shortBreakDuration
                    prefs.longBreakDuration = prefsDTO.longBreakDuration
                    prefs.pomodorosPerCycle = prefsDTO.pomodorosPerCycle
                    prefs.autoStartBreaks = prefsDTO.autoStartBreaks
                    prefs.autoStartWork = prefsDTO.autoStartWork
                    prefs.defaultBlockDuration = prefsDTO.defaultBlockDuration
                    prefs.blockMidpointCheckIn = prefsDTO.blockMidpointCheckIn
                    prefs.flowtimeMinSessionMinutes = prefsDTO.flowtimeMinSessionMinutes
                    prefs.flowtimeShowBreakSuggestion = prefsDTO.flowtimeShowBreakSuggestion
                    prefs.soundEnabled = prefsDTO.soundEnabled
                    prefs.hapticEnabled = prefsDTO.hapticEnabled
                    prefs.keepScreenOn = prefsDTO.keepScreenOn
                    prefs.defaultMode = prefsDTO.defaultMode
                    prefs.themeName = prefsDTO.themeName
                    prefs.followSystemAppearance = prefsDTO.followSystemAppearance
                    prefs.dailyReminderEnabled = prefsDTO.dailyReminderEnabled
                    prefs.dailyReminderHour = prefsDTO.dailyReminderHour
                    prefs.dailyReminderMinute = prefsDTO.dailyReminderMinute
                    prefs.showJournalAfterSession = prefsDTO.showJournalAfterSession
                    prefs.healthLoggingEnabled = prefsDTO.healthLoggingEnabled
                    prefs.adhdFriendlyEnabled = prefsDTO.adhdFriendlyEnabled
                    prefs.calendarIntegrationEnabled = prefsDTO.calendarIntegrationEnabled
                    prefs.isProUser = prefsDTO.isProUser
                    prefs.appleUserID = prefsDTO.appleUserID
                    prefs.displayName = prefsDTO.displayName
                    prefs.userEmail = prefsDTO.userEmail
                    try service.savePreferences(prefs)
                }
            },
            generateRecurringTasks: {
                try await MainActor.run { try service.generateRecurringTasksIfNeeded() }
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
