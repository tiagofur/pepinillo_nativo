// SchemaSnapshotsV5V6.swift
// Pepinillo — Deep Work Companion for Apple
//
// Frozen versioned-schema snapshots for V5 and V6 (extracted from
// SchemaVersioning.swift — cognitive budget; both versions declare frozen
// nested @Model classes and must never change after shipping).

import Foundation
import SwiftData

// MARK: - Schema V5 (CloudKit Unique IDs)

/// Adds `@Attribute(.unique)` on `id` for TaskItem, FocusSessionRecord, and DailyStats (#165).
///
/// Frozen for #991 round 1: V5 declared live model classes, which worked only
/// because no persisted property changed between versions — V7 adding
/// `TaskItem.plannedDate` polluted the declared V5 schema and a real V5 store
/// failed staged migration with "unknown model version" (dual-judged). The
/// snapshot pins the final V5-era schema. Never modify these — create
/// SchemaV8 for further changes.
enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV5.TaskItem.self,
            SchemaV5.SubTask.self,
            SchemaV5.FocusSessionRecord.self,
            SchemaV5.DailyStats.self,
            SchemaV5.UserPreferences.self,
            SchemaV5.ProductivityReport.self,
            SchemaV5.CachedUser.self,
        ]
    }

    // ── V5 Model Definitions ──────────────────────────────────────────
    // Identical to the V6 snapshot: no persisted property changed between
    // the V5 and V6 landings (only CachedUser.birthDate was removed
    // mid-window, un-versioned — production absorbed it; see note above).

    @Model
    final class TaskItem {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var title: String
        var notes: String?
        var isCompleted: Bool
        var completedAt: Date?
        var priority: TaskPriority
        var sortOrder: Int
        var energyLevel: EnergyLevel
        var dueDate: Date?
        var scheduledForToday: Bool = false
        var estimatedPomodoros: Int
        var completedPomodoros: Int
        var preferredMode: String?

        // Sync metadata
        var syncId: String = UUID().uuidString
        var serverId: Int?
        var isDirty: Bool = true
        var isLocallyDeleted: Bool = false
        var syncedAt: Date?

        var recurrenceRule: String?
        var nextOccurrence: Date?
        var isRecurringTemplate: Bool
        var recurringTemplateID: UUID?

        @Relationship(deleteRule: .cascade)
        var subtasks: [SubTask]

        @Relationship(inverse: \FocusSessionRecord.task)
        var sessions: [FocusSessionRecord]

        init(
            title: String,
            notes: String? = nil,
            priority: TaskPriority = .none,
            energyLevel: EnergyLevel = .deep,
            estimatedPomodoros: Int = 1,
            sortOrder: Int = 0
        ) {
            self.id = UUID()
            self.syncId = UUID().uuidString
            self.createdAt = Date.now
            self.updatedAt = Date.now
            self.title = title
            self.notes = notes
            self.isCompleted = false
            self.priority = priority
            self.sortOrder = sortOrder
            self.energyLevel = energyLevel
            self.estimatedPomodoros = estimatedPomodoros
            self.completedPomodoros = 0
            self.isRecurringTemplate = false
            self.scheduledForToday = false
            self.isDirty = true
            self.isLocallyDeleted = false
            self.subtasks = []
            self.sessions = []
        }
    }

    @Model
    final class SubTask {
        var id: UUID
        var title: String
        var isCompleted: Bool
        var sortOrder: Int
        var createdAt: Date

        var parent: TaskItem?

        init(title: String, sortOrder: Int = 0) {
            self.id = UUID()
            self.title = title
            self.isCompleted = false
            self.sortOrder = sortOrder
            self.createdAt = Date.now
        }
    }

    @Model
    final class FocusSessionRecord {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var mode: String
        var phase: String
        var targetDuration: TimeInterval?
        var actualDuration: TimeInterval
        var wasCompleted: Bool
        var interruptions: Int
        var pauseCount: Int = 0
        var totalPauseDuration: TimeInterval = 0
        var pomodoroNumber: Int?
        var journalNote: String?
        var satisfactionRating: Int?
        var isDirty: Bool = true
        var syncedAt: Date?

        var task: TaskItem?

        init() {
            self.id = UUID()
            self.startedAt = Date.now
            self.mode = ""
            self.phase = ""
            self.actualDuration = 0
            self.wasCompleted = false
            self.interruptions = 0
        }
    }

    @Model
    final class DailyStats {
        @Attribute(.unique) var id: UUID
        var date: Date
        var totalFocusSeconds: Int
        var sessionsCompleted: Int
        var tasksCompleted: Int
        var longestStreak: Int
        var pomodoroSeconds: Int
        var flowtimeSeconds: Int
        var timeBlockSeconds: Int
        var stopwatchSeconds: Int
        var pomodoroCount: Int
        var flowtimeCount: Int
        var timeBlockCount: Int
        var stopwatchCount: Int
        var hadFocusSession: Bool

        init(date: Date) {
            self.id = UUID()
            self.date = Calendar.current.startOfDay(for: date)
            self.totalFocusSeconds = 0
            self.sessionsCompleted = 0
            self.tasksCompleted = 0
            self.longestStreak = 0
            self.pomodoroSeconds = 0
            self.flowtimeSeconds = 0
            self.timeBlockSeconds = 0
            self.stopwatchSeconds = 0
            self.pomodoroCount = 0
            self.flowtimeCount = 0
            self.timeBlockCount = 0
            self.stopwatchCount = 0
            self.hadFocusSession = false
        }
    }

    @Model
    final class UserPreferences {
        var id: UUID
        var pomodoroDuration: TimeInterval
        var shortBreakDuration: TimeInterval
        var longBreakDuration: TimeInterval
        var pomodorosPerCycle: Int
        var autoStartBreaks: Bool
        var autoStartWork: Bool
        var defaultBlockDuration: TimeInterval
        var blockMidpointCheckIn: Bool
        var flowtimeMinSessionMinutes: Int
        var flowtimeShowBreakSuggestion: Bool
        var soundEnabled: Bool
        var hapticEnabled: Bool
        var keepScreenOn: Bool
        var defaultMode: String
        var themeName: String
        var followSystemAppearance: Bool
        var appearanceMode: String
        var dailyReminderEnabled: Bool
        var dailyReminderHour: Int
        var dailyReminderMinute: Int
        var hasCompletedOnboarding: Bool
        var currentStreakDays: Int
        var longestStreakDays: Int
        var lastFocusDate: Date?
        var showJournalAfterSession: Bool = true
        var healthLoggingEnabled: Bool
        var isProUser: Bool
        var subscriptionExpiresAt: Date?
        var adhdFriendlyEnabled: Bool = false
        var calendarIntegrationEnabled: Bool = false
        var appleUserID: String? = nil
        var displayName: String? = nil
        var userEmail: String? = nil
        var appleAuthorizationCode: String? = nil

        init() {
            self.id = UUID()
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
            self.soundEnabled = true
            self.hapticEnabled = true
            self.keepScreenOn = false
            self.defaultMode = "pomodoro"
            self.themeName = "default"
            self.followSystemAppearance = true
            self.appearanceMode = "system"
            self.dailyReminderEnabled = false
            self.dailyReminderHour = 9
            self.dailyReminderMinute = 0
            self.hasCompletedOnboarding = false
            self.currentStreakDays = 0
            self.longestStreakDays = 0
            self.healthLoggingEnabled = false
            self.isProUser = false
        }
    }

    @Model
    final class ProductivityReport {
        var id: UUID
        var period: String
        var periodStart: Date
        var periodEnd: Date
        var generatedAt: Date
        var title: String
        var highlightsJSON: String
        var insightsJSON: String
        var recommendationsJSON: String
        var rawPayload: String

        init() {
            self.id = UUID()
            self.period = ""
            self.periodStart = Date.now
            self.periodEnd = Date.now
            self.generatedAt = Date.now
            self.title = ""
            self.highlightsJSON = "[]"
            self.insightsJSON = "[]"
            self.recommendationsJSON = "[]"
            self.rawPayload = ""
        }
    }

    @Model
    final class CachedUser {
        var id: String
        var email: String
        var name: String
        var imageUrl: String?
        var subscriptionTier: String
        var subscriptionExpiresAt: String?
        var emailVerified: Bool
        var appleId: String?
        var createdAt: String
        var updatedAt: String

        init() {
            self.id = ""
            self.email = ""
            self.name = ""
            self.subscriptionTier = "free"
            self.emailVerified = false
            self.createdAt = ""
            self.updatedAt = ""
        }
    }
}

// MARK: - Schema V6 (Add AchievementRecord)

/// Adds the AchievementRecord table for persisted achievements (S1-S2).
/// Lightweight migration — only adds a new table, no existing model changes.
/// Mirrors V5 style (live model classes).
///
/// Frozen snapshot for #991: V7 changes TaskItem (adds `plannedDate`), so V6
/// now pins every model exactly as shipped through V6 (with the V5
/// `@Attribute(.unique)` ids). Never modify these — create SchemaV8 for
/// further changes.
enum SchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            SchemaV6.TaskItem.self,
            SchemaV6.SubTask.self,
            SchemaV6.FocusSessionRecord.self,
            SchemaV6.DailyStats.self,
            SchemaV6.UserPreferences.self,
            SchemaV6.ProductivityReport.self,
            SchemaV6.CachedUser.self,
            SchemaV6.AchievementRecord.self,
        ]
    }

    // ── V6 Model Definitions ──────────────────────────────────────────
    // Frozen snapshot of each @Model at the time of V6 (live classes until
    // V7 changed TaskItem). They must match the shipped V6 model exactly.

    @Model
    final class TaskItem {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var updatedAt: Date
        var title: String
        var notes: String?
        var isCompleted: Bool
        var completedAt: Date?
        var priority: TaskPriority
        var sortOrder: Int
        var energyLevel: EnergyLevel
        var dueDate: Date?
        var scheduledForToday: Bool = false
        var estimatedPomodoros: Int
        var completedPomodoros: Int
        var preferredMode: String?

        // Sync metadata
        var syncId: String = UUID().uuidString
        var serverId: Int?
        var isDirty: Bool = true
        var isLocallyDeleted: Bool = false
        var syncedAt: Date?

        var recurrenceRule: String?
        var nextOccurrence: Date?
        var isRecurringTemplate: Bool
        var recurringTemplateID: UUID?

        @Relationship(deleteRule: .cascade)
        var subtasks: [SubTask]

        @Relationship(inverse: \FocusSessionRecord.task)
        var sessions: [FocusSessionRecord]

        init(
            title: String,
            notes: String? = nil,
            priority: TaskPriority = .none,
            energyLevel: EnergyLevel = .deep,
            estimatedPomodoros: Int = 1,
            sortOrder: Int = 0
        ) {
            self.id = UUID()
            self.syncId = UUID().uuidString
            self.createdAt = Date.now
            self.updatedAt = Date.now
            self.title = title
            self.notes = notes
            self.isCompleted = false
            self.priority = priority
            self.sortOrder = sortOrder
            self.energyLevel = energyLevel
            self.estimatedPomodoros = estimatedPomodoros
            self.completedPomodoros = 0
            self.isRecurringTemplate = false
            self.scheduledForToday = false
            self.isDirty = true
            self.isLocallyDeleted = false
            self.subtasks = []
            self.sessions = []
        }
    }

    @Model
    final class SubTask {
        var id: UUID
        var title: String
        var isCompleted: Bool
        var sortOrder: Int
        var createdAt: Date

        var parent: TaskItem?

        init(title: String, sortOrder: Int = 0) {
            self.id = UUID()
            self.title = title
            self.isCompleted = false
            self.sortOrder = sortOrder
            self.createdAt = Date.now
        }
    }

    @Model
    final class FocusSessionRecord {
        @Attribute(.unique) var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var mode: String
        var phase: String
        var targetDuration: TimeInterval?
        var actualDuration: TimeInterval
        var wasCompleted: Bool
        var interruptions: Int
        var pauseCount: Int = 0
        var totalPauseDuration: TimeInterval = 0
        var pomodoroNumber: Int?
        var journalNote: String?
        var satisfactionRating: Int?
        var isDirty: Bool = true
        var syncedAt: Date?

        var task: TaskItem?

        init() {
            self.id = UUID()
            self.startedAt = Date.now
            self.mode = ""
            self.phase = ""
            self.actualDuration = 0
            self.wasCompleted = false
            self.interruptions = 0
        }
    }

    @Model
    final class DailyStats {
        @Attribute(.unique) var id: UUID
        var date: Date
        var totalFocusSeconds: Int
        var sessionsCompleted: Int
        var tasksCompleted: Int
        var longestStreak: Int
        var pomodoroSeconds: Int
        var flowtimeSeconds: Int
        var timeBlockSeconds: Int
        var stopwatchSeconds: Int
        var pomodoroCount: Int
        var flowtimeCount: Int
        var timeBlockCount: Int
        var stopwatchCount: Int
        var hadFocusSession: Bool

        init(date: Date) {
            self.id = UUID()
            self.date = Calendar.current.startOfDay(for: date)
            self.totalFocusSeconds = 0
            self.sessionsCompleted = 0
            self.tasksCompleted = 0
            self.longestStreak = 0
            self.pomodoroSeconds = 0
            self.flowtimeSeconds = 0
            self.timeBlockSeconds = 0
            self.stopwatchSeconds = 0
            self.pomodoroCount = 0
            self.flowtimeCount = 0
            self.timeBlockCount = 0
            self.stopwatchCount = 0
            self.hadFocusSession = false
        }
    }

    @Model
    final class UserPreferences {
        var id: UUID
        var pomodoroDuration: TimeInterval
        var shortBreakDuration: TimeInterval
        var longBreakDuration: TimeInterval
        var pomodorosPerCycle: Int
        var autoStartBreaks: Bool
        var autoStartWork: Bool
        var defaultBlockDuration: TimeInterval
        var blockMidpointCheckIn: Bool
        var flowtimeMinSessionMinutes: Int
        var flowtimeShowBreakSuggestion: Bool
        var soundEnabled: Bool
        var hapticEnabled: Bool
        var keepScreenOn: Bool
        var defaultMode: String
        var themeName: String
        var followSystemAppearance: Bool
        var appearanceMode: String
        var dailyReminderEnabled: Bool
        var dailyReminderHour: Int
        var dailyReminderMinute: Int
        var hasCompletedOnboarding: Bool
        var currentStreakDays: Int
        var longestStreakDays: Int
        var lastFocusDate: Date?
        var showJournalAfterSession: Bool = true
        var healthLoggingEnabled: Bool
        var isProUser: Bool
        var subscriptionExpiresAt: Date?
        var adhdFriendlyEnabled: Bool = false
        var calendarIntegrationEnabled: Bool = false
        var appleUserID: String? = nil
        var displayName: String? = nil
        var userEmail: String? = nil
        var appleAuthorizationCode: String? = nil

        init() {
            self.id = UUID()
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
            self.soundEnabled = true
            self.hapticEnabled = true
            self.keepScreenOn = false
            self.defaultMode = "pomodoro"
            self.themeName = "default"
            self.followSystemAppearance = true
            self.appearanceMode = "system"
            self.dailyReminderEnabled = false
            self.dailyReminderHour = 9
            self.dailyReminderMinute = 0
            self.hasCompletedOnboarding = false
            self.currentStreakDays = 0
            self.longestStreakDays = 0
            self.healthLoggingEnabled = false
            self.isProUser = false
        }
    }

    @Model
    final class ProductivityReport {
        var id: UUID
        var period: String
        var periodStart: Date
        var periodEnd: Date
        var generatedAt: Date
        var title: String
        var highlightsJSON: String
        var insightsJSON: String
        var recommendationsJSON: String
        var rawPayload: String

        init() {
            self.id = UUID()
            self.period = ""
            self.periodStart = Date.now
            self.periodEnd = Date.now
            self.generatedAt = Date.now
            self.title = ""
            self.highlightsJSON = "[]"
            self.insightsJSON = "[]"
            self.recommendationsJSON = "[]"
            self.rawPayload = ""
        }
    }

    @Model
    final class CachedUser {
        var id: String
        var email: String
        var name: String
        var imageUrl: String?
        var subscriptionTier: String
        var subscriptionExpiresAt: String?
        var emailVerified: Bool
        var appleId: String?
        var createdAt: String
        var updatedAt: String

        init() {
            self.id = ""
            self.email = ""
            self.name = ""
            self.subscriptionTier = "free"
            self.emailVerified = false
            self.createdAt = ""
            self.updatedAt = ""
        }
    }

    @Model
    final class AchievementRecord {
        @Attribute(.unique) var id: String
        var progress: Int
        var unlockedAt: Date?

        init(achievementID: String, progress: Int, unlockedAt: Date? = nil) {
            self.id = achievementID
            self.progress = progress
            self.unlockedAt = unlockedAt
        }
    }
}
