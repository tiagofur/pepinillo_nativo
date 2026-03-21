// SchemaVersioning.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftData VersionedSchema and MigrationPlan for safe schema evolution.
// Without versioning, ANY schema change after launch causes silent data corruption.
//
// ──────────────────────────────────────────────────────────────────────
// HOW TO ADD A NEW SCHEMA VERSION (e.g., V2):
//
// 1. Copy `SchemaV1` → `SchemaV2` (rename the enum).
// 2. Update `versionIdentifier` to `Schema.Version(2, 0, 0)`.
// 3. Modify the @Model classes inside SchemaV2 to reflect the new schema
//    (add/remove/rename properties, change types, etc.).
// 4. Add a migration stage in `PepinilloMigrationPlan.stages`:
//      .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
//    or for complex migrations:
//      .custom(fromVersion: SchemaV1.self, toVersion: SchemaV2.self) { context in
//          // Manual migration logic here
//          try context.save()
//      }
// 5. Add `SchemaV2.self` to the END of `PepinilloMigrationPlan.schemas`.
// 6. The LAST schema in the array is always the "current" one.
// ──────────────────────────────────────────────────────────────────────

import Foundation
import SwiftData
import SwiftUI

// MARK: - Schema V1 (Initial Release)

/// Captures the exact schema at launch. Never modify this enum after shipping —
/// create SchemaV2 instead and add a migration stage.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            SubTask.self,
            FocusSessionRecord.self,
            DailyStats.self,
            UserPreferences.self,
            ProductivityReport.self,
        ]
    }

    // ── V1 Model Definitions ──────────────────────────────────────────
    // These are frozen snapshots of each @Model at the time of V1 release.
    // They must match the current model definitions exactly.

    @Model
    final class TaskItem {
        var id: UUID
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
        var id: UUID
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
        var id: UUID
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
}

// MARK: - Schema V2 (Add CachedUser)

/// Adds CachedUser model for backend auth sync.
/// Lightweight migration — only adds a new table, no existing model changes.
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TaskItem.self,
            SubTask.self,
            FocusSessionRecord.self,
            DailyStats.self,
            UserPreferences.self,
            ProductivityReport.self,
            CachedUser.self,
        ]
    }
}

// MARK: - Migration Plan

/// Defines the ordered list of schema versions and migration stages between them.
/// SwiftData uses this to automatically migrate the persistent store when the app launches.
enum PepinilloMigrationPlan: SchemaMigrationPlan {
    /// Ordered from oldest to newest. The last entry is the current schema.
    static var schemas: [any VersionedSchema.Type] {
        [
            SchemaV1.self,
            SchemaV2.self,
        ]
    }

    /// Migration stages executed in order when upgrading across versions.
    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
        ]
    }
}
