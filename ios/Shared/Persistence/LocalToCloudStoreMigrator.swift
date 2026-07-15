// LocalToCloudStoreMigrator.swift
// Pepinillo — Deep Work Companion for Apple
//
// Copies SwiftData entities between on-disk containers while preserving primary
// keys and relationships. Used for local→Apple Cloud seeding, Apple Cloud→local
// export, and one-shot recovery from the legacy Pepinillo.sqlite store.

import Foundation
import SwiftData
import OSLog

private let migratorLogger = Logger(subsystem: "com.pepinillo.app", category: "store-migrator")

enum LocalToCloudStoreMigrator {
    static let legacyImportCompleteKey = "pepLegacyCloudKitStoreImportComplete"
    /// Set after the first local→Apple Cloud seed; cleared on demotion so re-buy re-merges local deltas.
    static let appleCloudInitialMigrationCompleteKey = "pepAppleCloudInitialMigrationComplete"

    /// Full store-to-store copy. Safe to call from a background thread; each
    /// container gets its own ephemeral `ModelContext`.
    static func migrate(
        from sourceContainer: ModelContainer,
        to targetContainer: ModelContainer
    ) throws {
        let source = ModelContext(sourceContainer)
        let target = ModelContext(targetContainer)

        var taskByID: [UUID: TaskItem] = [:]
        try copyTasks(from: source, to: target, taskByID: &taskByID)
        try copySessions(from: source, to: target, taskByID: taskByID)
        try copyDailyStats(from: source, to: target)
        try copyProductivityReports(from: source, to: target)
        try copyPreferences(from: source, to: target)
        try copyCachedUser(from: source, to: target)

        try target.save()
    }

    /// One-shot import from the legacy CloudKit-backed `Pepinillo.sqlite` file
    /// into the launch-critical local store. Opens the legacy file as local-only
    /// SQLite (no CloudKit) to avoid startup hangs.
    static func importLegacyStoreIfNeeded(into localContainer: ModelContainer) throws {
        guard UserDefaults.standard.bool(forKey: legacyImportCompleteKey) == false else { return }

        let legacyURL = AppGroup.legacyCloudKitStoreURL
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return }

        migratorLogger.info("Importing legacy store from \(legacyURL.path, privacy: .public)")

        let legacyContainer = try openLegacyModelContainer(at: legacyURL)
        try migrate(from: legacyContainer, to: localContainer)

        UserDefaults.standard.set(true, forKey: legacyImportCompleteKey)
        migratorLogger.info("Legacy store import complete")
    }

    // MARK: - Tasks + Subtasks

    private static func copyTasks(
        from source: ModelContext,
        to target: ModelContext,
        taskByID: inout [UUID: TaskItem]
    ) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        let sourceTasks = try source.fetch(descriptor)

        for sourceTask in sourceTasks where !sourceTask.isLocallyDeleted {
            let task = try upsertTask(sourceTask, in: target)
            taskByID[sourceTask.id] = task
            try copySubtasks(from: sourceTask, to: task, in: target)
        }
    }

    private static func upsertTask(_ source: TaskItem, in target: ModelContext) throws -> TaskItem {
        if let existing = try fetchTask(by: source.id, in: target) {
            guard source.updatedAt >= existing.updatedAt else { return existing }
            applyTaskFields(from: source, to: existing)
            return existing
        }

        let copy = TaskItem(
            title: source.title,
            notes: source.notes,
            priority: source.priority,
            energyLevel: source.energyLevel,
            estimatedPomodoros: source.estimatedPomodoros,
            sortOrder: source.sortOrder
        )
        applyTaskFields(from: source, to: copy)
        target.insert(copy)
        return copy
    }

    private static func applyTaskFields(from source: TaskItem, to copy: TaskItem) {
        copy.id = source.id
        copy.createdAt = source.createdAt
        copy.updatedAt = source.updatedAt
        copy.title = source.title
        copy.notes = source.notes
        copy.isCompleted = source.isCompleted
        copy.completedAt = source.completedAt
        copy.priority = source.priority
        copy.sortOrder = source.sortOrder
        copy.energyLevel = source.energyLevel
        copy.dueDate = source.dueDate
        copy.scheduledForToday = source.scheduledForToday
        copy.estimatedPomodoros = source.estimatedPomodoros
        copy.completedPomodoros = source.completedPomodoros
        copy.preferredMode = source.preferredMode
        copy.syncId = source.syncId
        copy.serverId = source.serverId
        copy.isDirty = source.isDirty
        copy.isLocallyDeleted = source.isLocallyDeleted
        copy.syncedAt = source.syncedAt
        copy.recurrenceRule = source.recurrenceRule
        copy.nextOccurrence = source.nextOccurrence
        copy.isRecurringTemplate = source.isRecurringTemplate
        copy.recurringTemplateID = source.recurringTemplateID
    }

    private static func copySubtasks(
        from sourceTask: TaskItem,
        to targetTask: TaskItem,
        in target: ModelContext
    ) throws {
        let existingSubtasks = try target.fetch(FetchDescriptor<SubTask>())
        for subtask in existingSubtasks where subtask.parent?.id == targetTask.id {
            target.delete(subtask)
        }

        for sourceSub in sourceTask.subtasks.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let copy = SubTask(title: sourceSub.title, sortOrder: sourceSub.sortOrder)
            copy.id = sourceSub.id
            copy.isCompleted = sourceSub.isCompleted
            copy.createdAt = sourceSub.createdAt
            target.insert(copy)
            copy.parent = targetTask
        }
    }

    // MARK: - Sessions

    private static func copySessions(
        from source: ModelContext,
        to target: ModelContext,
        taskByID: [UUID: TaskItem]
    ) throws {
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            sortBy: [SortDescriptor(\.startedAt)]
        )
        let sourceSessions = try source.fetch(descriptor)

        for sourceSession in sourceSessions {
            let copy = try upsertSession(sourceSession, in: target)
            if let sourceTaskID = sourceSession.task?.id {
                copy.task = taskByID[sourceTaskID]
            } else {
                copy.task = nil
            }
        }
    }

    private static func upsertSession(
        _ source: FocusSessionRecord,
        in target: ModelContext
    ) throws -> FocusSessionRecord {
        if let existing = try fetchSession(by: source.id, in: target) {
            guard sessionRevisionTimestamp(source) >= sessionRevisionTimestamp(existing) else {
                return existing
            }
            applySessionFields(from: source, to: existing)
            return existing
        }

        let copy = FocusSessionRecord(
            mode: source.mode,
            phase: source.phase,
            startedAt: source.startedAt,
            endedAt: source.endedAt,
            actualDuration: source.actualDuration,
            targetDuration: source.targetDuration,
            wasCompleted: source.wasCompleted,
            interruptions: source.interruptions,
            pauseCount: source.pauseCount,
            totalPauseDuration: source.totalPauseDuration
        )
        applySessionFields(from: source, to: copy)
        target.insert(copy)
        return copy
    }

    private static func applySessionFields(
        from source: FocusSessionRecord,
        to copy: FocusSessionRecord
    ) {
        copy.id = source.id
        copy.startedAt = source.startedAt
        copy.endedAt = source.endedAt
        copy.mode = source.mode
        copy.phase = source.phase
        copy.targetDuration = source.targetDuration
        copy.actualDuration = source.actualDuration
        copy.wasCompleted = source.wasCompleted
        copy.interruptions = source.interruptions
        copy.pauseCount = source.pauseCount
        copy.totalPauseDuration = source.totalPauseDuration
        copy.pomodoroNumber = source.pomodoroNumber
        copy.journalNote = source.journalNote
        copy.satisfactionRating = source.satisfactionRating
        copy.isDirty = source.isDirty
        copy.syncedAt = source.syncedAt
    }

    // MARK: - Analytics

    private static func copyDailyStats(from source: ModelContext, to target: ModelContext) throws {
        let sourceStats = try source.fetch(FetchDescriptor<DailyStats>(sortBy: [SortDescriptor(\.date)]))
        for sourceStat in sourceStats {
            let startOfDay = Calendar.current.startOfDay(for: sourceStat.date)
            let copy: DailyStats
            if let existing = try fetchDailyStats(for: startOfDay, in: target) {
                guard dailyStatsRevisionScore(sourceStat) >= dailyStatsRevisionScore(existing) else {
                    continue
                }
                copy = existing
            } else {
                copy = DailyStats(date: startOfDay)
                copy.id = sourceStat.id
                target.insert(copy)
            }

            copy.date = startOfDay
            copy.totalFocusSeconds = sourceStat.totalFocusSeconds
            copy.sessionsCompleted = sourceStat.sessionsCompleted
            copy.tasksCompleted = sourceStat.tasksCompleted
            copy.longestStreak = sourceStat.longestStreak
            copy.pomodoroSeconds = sourceStat.pomodoroSeconds
            copy.flowtimeSeconds = sourceStat.flowtimeSeconds
            copy.timeBlockSeconds = sourceStat.timeBlockSeconds
            copy.stopwatchSeconds = sourceStat.stopwatchSeconds
            copy.pomodoroCount = sourceStat.pomodoroCount
            copy.flowtimeCount = sourceStat.flowtimeCount
            copy.timeBlockCount = sourceStat.timeBlockCount
            copy.stopwatchCount = sourceStat.stopwatchCount
            copy.hadFocusSession = sourceStat.hadFocusSession
        }
    }

    private static func copyProductivityReports(
        from source: ModelContext,
        to target: ModelContext
    ) throws {
        let sourceReports = try source.fetch(
            FetchDescriptor<ProductivityReport>(sortBy: [SortDescriptor(\.generatedAt)])
        )

        for sourceReport in sourceReports {
            if let existing = try fetchProductivityReport(by: sourceReport.id, in: target) {
                applyProductivityReportFields(from: sourceReport, to: existing)
                continue
            }

            let copy = ProductivityReport(
                id: sourceReport.id,
                period: sourceReport.period,
                periodStart: sourceReport.periodStart,
                periodEnd: sourceReport.periodEnd,
                generatedAt: sourceReport.generatedAt,
                title: sourceReport.title,
                highlights: sourceReport.highlights,
                insights: sourceReport.insights,
                recommendations: sourceReport.recommendations,
                rawPayload: sourceReport.rawPayload
            )
            target.insert(copy)
        }
    }

    private static func applyProductivityReportFields(
        from source: ProductivityReport,
        to copy: ProductivityReport
    ) {
        copy.period = source.period
        copy.periodStart = source.periodStart
        copy.periodEnd = source.periodEnd
        copy.generatedAt = source.generatedAt
        copy.title = source.title
        copy.highlightsJSON = source.highlightsJSON
        copy.insightsJSON = source.insightsJSON
        copy.recommendationsJSON = source.recommendationsJSON
        copy.rawPayload = source.rawPayload
    }

    // MARK: - Preferences + Cached User

    private static func copyPreferences(from source: ModelContext, to target: ModelContext) throws {
        guard let sourcePrefs = try source.fetch(FetchDescriptor<UserPreferences>()).first else { return }

        let targetPrefs = try target.fetch(FetchDescriptor<UserPreferences>())
        for prefs in targetPrefs {
            target.delete(prefs)
        }

        let copy = UserPreferences()
        copy.id = sourcePrefs.id
        copy.pomodoroDuration = sourcePrefs.pomodoroDuration
        copy.shortBreakDuration = sourcePrefs.shortBreakDuration
        copy.longBreakDuration = sourcePrefs.longBreakDuration
        copy.pomodorosPerCycle = sourcePrefs.pomodorosPerCycle
        copy.autoStartBreaks = sourcePrefs.autoStartBreaks
        copy.autoStartWork = sourcePrefs.autoStartWork
        copy.defaultBlockDuration = sourcePrefs.defaultBlockDuration
        copy.blockMidpointCheckIn = sourcePrefs.blockMidpointCheckIn
        copy.flowtimeMinSessionMinutes = sourcePrefs.flowtimeMinSessionMinutes
        copy.flowtimeShowBreakSuggestion = sourcePrefs.flowtimeShowBreakSuggestion
        copy.soundEnabled = sourcePrefs.soundEnabled
        copy.hapticEnabled = sourcePrefs.hapticEnabled
        copy.keepScreenOn = sourcePrefs.keepScreenOn
        copy.defaultMode = sourcePrefs.defaultMode
        copy.themeName = sourcePrefs.themeName
        copy.followSystemAppearance = sourcePrefs.followSystemAppearance
        copy.appearanceMode = sourcePrefs.appearanceMode
        copy.dailyReminderEnabled = sourcePrefs.dailyReminderEnabled
        copy.dailyReminderHour = sourcePrefs.dailyReminderHour
        copy.dailyReminderMinute = sourcePrefs.dailyReminderMinute
        copy.hasCompletedOnboarding = sourcePrefs.hasCompletedOnboarding
        copy.currentStreakDays = sourcePrefs.currentStreakDays
        copy.longestStreakDays = sourcePrefs.longestStreakDays
        copy.lastFocusDate = sourcePrefs.lastFocusDate
        copy.showJournalAfterSession = sourcePrefs.showJournalAfterSession
        copy.healthLoggingEnabled = sourcePrefs.healthLoggingEnabled
        copy.isProUser = sourcePrefs.isProUser
        copy.subscriptionExpiresAt = sourcePrefs.subscriptionExpiresAt
        copy.adhdFriendlyEnabled = sourcePrefs.adhdFriendlyEnabled
        copy.calendarIntegrationEnabled = sourcePrefs.calendarIntegrationEnabled
        copy.appleUserID = sourcePrefs.appleUserID
        copy.displayName = sourcePrefs.displayName
        copy.userEmail = sourcePrefs.userEmail
        target.insert(copy)
    }

    private static func copyCachedUser(from source: ModelContext, to target: ModelContext) throws {
        guard let sourceUser = try source.fetch(FetchDescriptor<CachedUser>()).first else { return }

        let targetUsers = try target.fetch(FetchDescriptor<CachedUser>())
        for user in targetUsers {
            target.delete(user)
        }

        let copy = CachedUser()
        copy.id = sourceUser.id
        copy.email = sourceUser.email
        copy.name = sourceUser.name
        copy.imageUrl = sourceUser.imageUrl
        copy.birthDate = sourceUser.birthDate
        copy.subscriptionTier = sourceUser.subscriptionTier
        copy.subscriptionExpiresAt = sourceUser.subscriptionExpiresAt
        copy.emailVerified = sourceUser.emailVerified
        copy.appleId = sourceUser.appleId
        copy.createdAt = sourceUser.createdAt
        copy.updatedAt = sourceUser.updatedAt
        target.insert(copy)
    }

    // MARK: - LWW Helpers

    /// Sessions lack `updatedAt`; use the latest session boundary as the revision clock.
    private static func sessionRevisionTimestamp(_ session: FocusSessionRecord) -> Date {
        session.endedAt ?? session.startedAt
    }

    /// Prefer the DailyStats row with newer aggregate totals for the same day key.
    private static func dailyStatsRevisionScore(_ stats: DailyStats) -> Int {
        stats.totalFocusSeconds * 1_000
            + stats.sessionsCompleted * 10
            + stats.tasksCompleted
    }

    // MARK: - Fetch Helpers

    private static func fetchTask(by id: UUID, in context: ModelContext) throws -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchSession(by id: UUID, in context: ModelContext) throws -> FocusSessionRecord? {
        var descriptor = FetchDescriptor<FocusSessionRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func fetchDailyStats(for date: Date, in context: ModelContext) throws -> DailyStats? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyStats>(predicate: #Predicate { $0.date == startOfDay })
        return try context.fetch(descriptor).first
    }

    private static func fetchProductivityReport(by id: UUID, in context: ModelContext) throws -> ProductivityReport? {
        var descriptor = FetchDescriptor<ProductivityReport>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Legacy Container

    private static func openLegacyModelContainer(at url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV5.self)
        let config = ModelConfiguration(
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: PepinilloMigrationPlan.self,
            configurations: [config]
        )
    }
}