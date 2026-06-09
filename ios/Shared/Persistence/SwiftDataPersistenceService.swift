// SwiftDataPersistenceService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Service wrapping a SwiftData ModelContext. It is isolation-agnostic: it only
// ever touches the injected ModelContext and is always driven from within the
// isolation that owns that context (BackgroundPersistenceActor in the live app).
// Used by PersistenceClient.live to implement all data operations off the main thread.

import Foundation
import SwiftData

public final class SwiftDataPersistenceService {

    private let context: ModelContext

    /// Operate on an explicitly provided context (e.g. a background ModelActor context).
    public init(context: ModelContext) {
        self.context = context
    }

    /// Convenience for callers that want the container's main context (e.g. migration helpers).
    public init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    public func save() throws {
        try context.save()
    }

    // MARK: - Tasks

    public func fetchTasks() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    /// One-shot batch of subtask completion counts keyed by parent task id.
    /// Avoids the N+1 relationship fault of touching `task.subtasks` per task
    /// when mapping a full task list to DTOs.
    public func subtaskProgressByTask() throws -> [UUID: (completed: Int, total: Int)] {
        let descriptor = FetchDescriptor<SubTask>()
        let subtasks = try context.fetch(descriptor)
        var result: [UUID: (completed: Int, total: Int)] = [:]
        for subtask in subtasks {
            guard let parentID = subtask.parent?.id else { continue }
            var entry = result[parentID] ?? (completed: 0, total: 0)
            entry.total += 1
            if subtask.isCompleted { entry.completed += 1 }
            result[parentID] = entry
        }
        return result
    }

    public func saveTask(_ task: TaskItem) throws {
        if task.modelContext == nil {
            context.insert(task)
        }
        task.updatedAt = Date.now
        task.isDirty = true  // Mark dirty for sync
        try context.save()
    }

    public func deleteTask(id: UUID) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try context.fetch(descriptor).first {
            context.delete(task)
            try context.save()
        }
    }

    /// Soft-delete: marks the task as deleted and dirty for sync, instead of removing it.
    /// Tasks that have never been synced (no serverId, no syncedAt) are hard-deleted immediately.
    public func softDeleteTask(id: UUID) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try context.fetch(descriptor).first {
            if task.serverId == nil && task.syncedAt == nil {
                // Never synced — safe to hard delete
                context.delete(task)
            } else {
                task.isDeleted = true
                task.isDirty = true
                task.updatedAt = Date.now
            }
            try context.save()
        }
    }

    public func toggleTaskCompletion(id: UUID) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try context.fetch(descriptor).first {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date.now : nil
            task.updatedAt = Date.now
            task.isDirty = true  // Mark dirty for sync
            try context.save()
        }
    }

    public func incrementTaskPomodoros(id: UUID) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try context.fetch(descriptor).first {
            task.completedPomodoros += 1
            task.updatedAt = Date.now
            task.isDirty = true
            try context.save()
        }
    }

    // MARK: - Sessions

    public func saveSession(_ result: FocusSessionResult) throws {
        let record = FocusSessionRecord(from: result)

        // Link to task and update pomodoro count
        if let taskID = result.linkedTaskID {
            let taskDescriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.id == taskID }
            )
            if let task = try context.fetch(taskDescriptor).first {
                record.task = task
                if result.wasCompleted && result.mode == .pomodoro, case .work = result.phase {
                    task.completedPomodoros += 1
                    task.updatedAt = Date.now
                    task.isDirty = true  // Mark dirty for sync
                }
            }
        }

        context.insert(record)
        try updateOrCreateDailyStats(with: result)
        try context.save()
    }

    public func fetchSessions(from start: Date, to end: Date) throws -> [FocusSessionRecord] {
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.startedAt >= start && $0.startedAt <= end },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    public func fetchSessionsForTask(taskID: UUID) throws -> [FocusSessionRecord] {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
        guard let task = try context.fetch(descriptor).first else { return [] }
        return task.sessions.sorted { $0.startedAt > $1.startedAt }
    }

    public func fetchTaskAnalytics(taskID: UUID) throws -> TaskAnalyticsDTO {
        let taskDescriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
        guard let task = try context.fetch(taskDescriptor).first else {
            throw PersistenceError.notFound
        }

        let sessions = task.sessions
        let totalSessions = sessions.count
        let completedSessions = sessions.filter(\.wasCompleted).count
        let totalFocusSeconds = Int(sessions.reduce(0.0) { $0 + $1.actualDuration })
        let avgSessionSeconds = totalSessions > 0 ? totalFocusSeconds / totalSessions : 0
        let totalInterruptions = sessions.reduce(0) { $0 + $1.interruptions }
        let avgInterruptionsPerSession = totalSessions > 0
            ? Double(totalInterruptions) / Double(totalSessions)
            : 0.0
        let totalPauses = sessions.reduce(0) { $0 + $1.pauseCount }

        // Average satisfaction (only rated sessions)
        let ratedSessions = sessions.compactMap(\.satisfactionRating)
        let avgSatisfactionRating: Double? = ratedSessions.isEmpty
            ? nil
            : Double(ratedSessions.reduce(0, +)) / Double(ratedSessions.count)

        // Mode distribution: mode → total seconds
        var modeDistribution: [String: Int] = [:]
        for session in sessions {
            modeDistribution[session.mode, default: 0] += Int(session.actualDuration)
        }

        // Peak hour bucket: hour with most sessions
        let calendar = Calendar.current
        var hourCounts: [Int: Int] = [:]
        for session in sessions {
            let hour = calendar.component(.hour, from: session.startedAt)
            hourCounts[hour, default: 0] += 1
        }
        let peakHourBucket = hourCounts.max(by: { $0.value < $1.value })?.key

        // Estimation accuracy: completedPomodoros / estimatedPomodoros
        let estimated = task.estimatedPomodoros
        let completed = task.completedPomodoros
        let estimationAccuracy: Double? = estimated > 0
            ? Double(completed) / Double(estimated)
            : nil

        return TaskAnalyticsDTO(
            taskID: task.id,
            taskTitle: task.title,
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            totalFocusSeconds: totalFocusSeconds,
            avgSessionSeconds: avgSessionSeconds,
            totalInterruptions: totalInterruptions,
            avgInterruptionsPerSession: avgInterruptionsPerSession,
            totalPauses: totalPauses,
            avgSatisfactionRating: avgSatisfactionRating,
            modeDistribution: modeDistribution,
            peakHourBucket: peakHourBucket,
            estimatedPomodoros: estimated,
            completedPomodoros: completed,
            estimationAccuracy: estimationAccuracy
        )
    }

    public func saveJournalEntry(sessionID: UUID, note: String?, rating: Int?) throws {
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.id == sessionID }
        )
        guard let record = try context.fetch(descriptor).first else { return }
        record.journalNote = note
        record.satisfactionRating = rating
        try context.save()
    }

    // MARK: - Daily Stats

    public func fetchDailyStats(for date: Date) throws -> DailyStats? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.date == startOfDay }
        )
        return try context.fetch(descriptor).first
    }

    public func fetchDailyStatsRange(from start: Date, to end: Date) throws -> [DailyStats] {
        let startDay = Calendar.current.startOfDay(for: start)
        let endDay = Calendar.current.startOfDay(for: end)
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.date >= startDay && $0.date <= endDay },
            sortBy: [SortDescriptor(\.date)]
        )
        return try context.fetch(descriptor)
    }

    // MARK: - Preferences

    public func fetchPreferences() throws -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        // First launch: create defaults
        let defaults = UserPreferences()
        context.insert(defaults)
        try context.save()
        return defaults
    }

    public func savePreferences(_ prefs: UserPreferences) throws {
        if prefs.modelContext == nil {
            context.insert(prefs)
        }
        try context.save()
    }

    public func applyPreferencesDTO(_ prefsDTO: UserPreferencesDTO) throws {
        let prefs = try fetchPreferences()
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
        prefs.appearanceMode = prefsDTO.appearanceMode
        prefs.dailyReminderEnabled = prefsDTO.dailyReminderEnabled
        prefs.dailyReminderHour = prefsDTO.dailyReminderHour
        prefs.dailyReminderMinute = prefsDTO.dailyReminderMinute
        prefs.hasCompletedOnboarding = prefsDTO.hasCompletedOnboarding
        prefs.currentStreakDays = prefsDTO.currentStreakDays
        prefs.longestStreakDays = prefsDTO.longestStreakDays
        prefs.lastFocusDate = prefsDTO.lastFocusDate
        prefs.showJournalAfterSession = prefsDTO.showJournalAfterSession
        prefs.healthLoggingEnabled = prefsDTO.healthLoggingEnabled
        prefs.adhdFriendlyEnabled = prefsDTO.adhdFriendlyEnabled
        prefs.calendarIntegrationEnabled = prefsDTO.calendarIntegrationEnabled
        prefs.isProUser = prefsDTO.isProUser
        prefs.subscriptionExpiresAt = prefsDTO.subscriptionExpiresAt
        prefs.appleUserID = prefsDTO.appleUserID
        prefs.displayName = prefsDTO.displayName
        prefs.userEmail = prefsDTO.userEmail
        try savePreferences(prefs)
    }

    // MARK: - Recurring Tasks

    /// Generates task instances from recurring templates whose nextOccurrence <= today.
    public func generateRecurringTasksIfNeeded(for date: Date = .now) throws {
        let today = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isRecurringTemplate == true }
        )
        let templates = try context.fetch(descriptor)

        for template in templates {
            guard let nextOccurrence = template.nextOccurrence,
                  nextOccurrence <= today,
                  let ruleString = template.recurrenceRule,
                  let preset = RecurrencePreset.from(rule: ruleString) else {
                continue
            }

            // Check if we already generated an instance for today
            let templateID = template.id
            let checkDescriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate {
                    $0.recurringTemplateID == templateID && $0.createdAt >= today
                }
            )
            let existing = try context.fetch(checkDescriptor)
            guard existing.isEmpty else { continue }

            // Create a new instance from the template
            let instance = TaskItem(
                title: template.title,
                notes: template.notes,
                priority: template.priority,
                energyLevel: template.energyLevel,
                estimatedPomodoros: template.estimatedPomodoros,
                sortOrder: template.sortOrder
            )
            instance.recurringTemplateID = template.id
            instance.isRecurringTemplate = false
            context.insert(instance)

            // Advance the template's nextOccurrence
            template.nextOccurrence = preset.nextDate(after: today)
            template.updatedAt = Date.now
        }

        try context.save()
    }

    // MARK: - Subtasks

    public func fetchSubtasks(for taskID: UUID) throws -> [SubTask] {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
        guard let task = try context.fetch(descriptor).first else { return [] }
        return task.subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    public func addSubtask(to taskID: UUID, title: String) throws -> SubTask {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
        guard let task = try context.fetch(descriptor).first else {
            throw PersistenceError.notFound
        }
        let sortOrder = task.subtasks.count
        let subtask = SubTask(title: title, sortOrder: sortOrder)
        context.insert(subtask)
        subtask.parent = task
        task.updatedAt = Date.now
        task.isDirty = true  // Mark dirty for sync
        try context.save()
        return subtask
    }

    public func toggleSubtask(id: UUID) throws {
        let descriptor = FetchDescriptor<SubTask>(predicate: #Predicate { $0.id == id })
        guard let subtask = try context.fetch(descriptor).first else { return }
        subtask.isCompleted.toggle()
        subtask.parent?.updatedAt = Date.now
        subtask.parent?.isDirty = true  // Mark dirty for sync
        try context.save()
    }

    public func deleteSubtask(id: UUID) throws {
        let descriptor = FetchDescriptor<SubTask>(predicate: #Predicate { $0.id == id })
        if let subtask = try context.fetch(descriptor).first {
            subtask.parent?.updatedAt = Date.now
            subtask.parent?.isDirty = true  // Mark dirty for sync
            context.delete(subtask)
            try context.save()
        }
    }

    public func fetchTaskTotalFocusSeconds(for taskID: UUID) throws -> TimeInterval {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
        guard let task = try context.fetch(descriptor).first else { return 0 }
        return task.totalFocusTime
    }

    // MARK: - Cached User

    public func fetchCachedUser() throws -> CachedUser? {
        let descriptor = FetchDescriptor<CachedUser>()
        return try context.fetch(descriptor).first
    }

    public func saveCachedUser(_ dto: CachedUserDTO) throws {
        // Delete existing first (singleton pattern)
        try deleteCachedUser()
        let user = CachedUser()
        user.id = dto.id
        user.email = dto.email
        user.name = dto.name
        user.imageUrl = dto.imageUrl
        user.birthDate = dto.birthDate
        user.subscriptionTier = dto.subscriptionTier
        user.subscriptionExpiresAt = dto.subscriptionExpiresAt
        user.emailVerified = dto.emailVerified
        user.appleId = dto.appleId
        user.createdAt = dto.createdAt
        user.updatedAt = dto.updatedAt
        context.insert(user)
        try context.save()
    }

    public func deleteCachedUser() throws {
        let descriptor = FetchDescriptor<CachedUser>()
        let users = try context.fetch(descriptor)
        for user in users {
            context.delete(user)
        }
        try context.save()
    }

    // MARK: - Sync Operations

    /// Fetch all tasks that have been modified locally and need to be synced.
    public func fetchDirtyTasks() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDirty == true }
        )
        return try context.fetch(descriptor)
    }

    /// Mark tasks as synced (clean) after successful sync.
    public func markTasksSynced(syncIds: [String], syncTimestamp: String) throws {
        let now = Date.now
        for syncId in syncIds {
            let syncIdCopy = syncId
            let descriptor = FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.syncId == syncIdCopy }
            )
            if let task = try context.fetch(descriptor).first {
                task.isDirty = false
                task.syncedAt = now
            }
        }
        // Purge soft-deleted tasks that have been synced
        let deletedDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDeleted == true && $0.isDirty == false }
        )
        let deletedTasks = try context.fetch(deletedDescriptor)
        for task in deletedTasks {
            context.delete(task)
        }
        try context.save()
    }

    /// Insert or update a task from server data (last-write-wins merge).
    public func upsertTaskFromServer(_ serverTask: TaskSyncDTO, saveImmediately: Bool = true) throws {
        let serverSyncId = serverTask.syncId
        let syncIdDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.syncId == serverSyncId }
        )
        let localBySyncId = try context.fetch(syncIdDescriptor).first

        // Also try to find by serverId
        let serverIdValue = serverTask.id ?? 0
        let serverIdDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.serverId == serverIdValue }
        )
        let localByServerId = serverIdValue > 0 ? try context.fetch(serverIdDescriptor).first : nil

        let local = localBySyncId ?? localByServerId

        if let local {
            // Only update if local isn't dirty (server wins for clean tasks)
            guard !local.isDirty else { return }

            local.title = serverTask.title ?? local.title
            local.notes = serverTask.description
            local.isCompleted = serverTask.isFinished
            local.completedAt = serverTask.isFinished ? (local.completedAt ?? Date.now) : nil
            local.priority = TaskPriority(rawValue: serverTask.priority) ?? .none
            local.energyLevel = Self.energyLevelFromString(serverTask.energyLevel)
            local.estimatedPomodoros = serverTask.estimatedPomodoros
            local.completedPomodoros = serverTask.completedPomodoros
            local.recurrenceRule = serverTask.recurrenceRule
            if let templateId = serverTask.recurringTemplateId {
                local.recurringTemplateID = UUID(uuidString: templateId)
            }
            if let createdStr = serverTask.createdDate {
                local.createdAt = ISO8601DateFormatter().date(from: createdStr) ?? local.createdAt
            }
            if let finishStr = serverTask.finishDate {
                local.dueDate = ISO8601DateFormatter().date(from: finishStr)
            } else {
                local.dueDate = nil
            }
            local.serverId = serverTask.id
            local.isDirty = false
            local.syncedAt = Date.now
            local.updatedAt = Date.now

            // Update subtasks from server
            if let serverSubTasks = serverTask.subTasks {
                // Remove existing subtasks and replace with server data
                for existing in local.subtasks {
                    context.delete(existing)
                }
                local.subtasks = []
                for (index, serverSub) in serverSubTasks.enumerated() {
                    let sub = SubTask(title: serverSub.title ?? "", sortOrder: index)
                    sub.isCompleted = serverSub.isFinished
                    context.insert(sub)
                    sub.parent = local
                }
            }
        } else {
            // New task from server — insert
            let newTask = TaskItem(
                title: serverTask.title ?? "",
                notes: serverTask.description,
                priority: TaskPriority(rawValue: serverTask.priority) ?? .none,
                energyLevel: Self.energyLevelFromString(serverTask.energyLevel),
                estimatedPomodoros: serverTask.estimatedPomodoros
            )
            newTask.syncId = serverTask.syncId
            newTask.serverId = serverTask.id
            newTask.isCompleted = serverTask.isFinished
            newTask.completedAt = serverTask.isFinished ? Date.now : nil
            newTask.completedPomodoros = serverTask.completedPomodoros
            newTask.recurrenceRule = serverTask.recurrenceRule
            newTask.isDeleted = serverTask.isDeleted
            newTask.isDirty = false
            newTask.syncedAt = Date.now
            if let templateId = serverTask.recurringTemplateId {
                newTask.recurringTemplateID = UUID(uuidString: templateId)
            }
            if let createdStr = serverTask.createdDate {
                newTask.createdAt = ISO8601DateFormatter().date(from: createdStr) ?? Date.now
            }
            if let finishStr = serverTask.finishDate {
                newTask.dueDate = ISO8601DateFormatter().date(from: finishStr)
            }
            context.insert(newTask)

            // Add subtasks from server
            if let serverSubTasks = serverTask.subTasks {
                for (index, serverSub) in serverSubTasks.enumerated() {
                    let sub = SubTask(title: serverSub.title ?? "", sortOrder: index)
                    sub.isCompleted = serverSub.isFinished
                    context.insert(sub)
                    sub.parent = newTask
                }
            }
        }
        if saveImmediately {
            try context.save()
        }
    }

    /// Permanently delete a task by syncId (used when server reports deletion).
    public func purgeTaskBySyncId(_ syncId: String) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.syncId == syncId }
        )
        if let task = try context.fetch(descriptor).first {
            context.delete(task)
            try context.save()
        }
    }

    /// Get the last sync timestamp from UserDefaults.
    public func getLastSyncTimestamp() -> String? {
        UserDefaults.standard.string(forKey: "lastTaskSyncTimestamp")
    }

    /// Save the last sync timestamp to UserDefaults.
    public func saveLastSyncTimestamp(_ timestamp: String) {
        UserDefaults.standard.set(timestamp, forKey: "lastTaskSyncTimestamp")
    }

    /// Convert energy level string from server to EnergyLevel enum.
    private static func energyLevelFromString(_ str: String?) -> EnergyLevel {
        switch str?.lowercased() {
        case "deep": return .deep
        case "shallow", "light": return .shallow
        case "admin": return .admin
        default: return .deep
        }
    }

    // MARK: - Private

    // MARK: - Errors

    enum PersistenceError: Error {
        case notFound
    }

    private func updateOrCreateDailyStats(with result: FocusSessionResult) throws {
        let day = Calendar.current.startOfDay(for: result.startedAt)
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.date == day }
        )
        let stats: DailyStats
        if let existing = try context.fetch(descriptor).first {
            stats = existing
        } else {
            stats = DailyStats(date: day)
            context.insert(stats)
        }
        stats.recordSession(result)
    }

    // MARK: - Session Sync

    public func fetchDirtySessions() throws -> [FocusSessionRecord] {
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.isDirty == true }
        )
        return try context.fetch(descriptor)
    }

    public func markSessionsSynced(ids: [UUID]) throws {
        // Fetch only the records we need to mark, one predicate lookup per id.
        // #Predicate cannot capture a [UUID] array directly in SwiftData, so we
        // iterate with a limit-1 descriptor per id — still vastly cheaper than
        // loading the entire FocusSessionRecord table.
        let now = Date.now
        for id in ids {
            let idCopy = id
            var descriptor = FetchDescriptor<FocusSessionRecord>(
                predicate: #Predicate { $0.id == idCopy }
            )
            descriptor.fetchLimit = 1
            if let record = try context.fetch(descriptor).first {
                record.isDirty = false
                record.syncedAt = now
            }
        }
        try context.save()
    }

    public func markAllSyncableDataDirty() throws {
        let taskDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDeleted == false }
        )
        for task in try context.fetch(taskDescriptor) {
            task.isDirty = true
            task.syncedAt = nil
            task.updatedAt = Date.now
        }

        let sessionDescriptor = FetchDescriptor<FocusSessionRecord>()
        for record in try context.fetch(sessionDescriptor) {
            record.isDirty = true
            record.syncedAt = nil
        }

        try context.save()
    }

    public func upsertSessionFromServer(_ dto: FocusSessionSyncDTO, saveImmediately: Bool = true) throws {
        // Check if session already exists by ID
        guard let sessionUUID = UUID(uuidString: dto.id) else { return }
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.id == sessionUUID }
        )
        if try context.fetch(descriptor).first != nil {
            // Already exists locally, don't overwrite
            return
        }

        // Create new record from server data
        let iso = ISO8601DateFormatter()
        let startedAt = iso.date(from: dto.startedAt) ?? Date.now
        let endedAt = dto.endedAt.flatMap { iso.date(from: $0) }

        let record = FocusSessionRecord(
            mode: dto.mode,
            phase: dto.phase,
            startedAt: startedAt,
            endedAt: endedAt,
            actualDuration: TimeInterval(dto.elapsedSeconds),
            targetDuration: nil,
            wasCompleted: dto.wasCompleted,
            interruptions: 0,
            pauseCount: dto.pauseCount,
            totalPauseDuration: TimeInterval(dto.totalPauseSeconds)
        )
        record.id = sessionUUID
        record.isDirty = false
        record.syncedAt = Date.now

        context.insert(record)
        if saveImmediately {
            try context.save()
        }
    }

    public func sessionExists(id: String) throws -> Bool {
        guard let uuid = UUID(uuidString: id) else { return false }
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.id == uuid }
        )
        return try !context.fetch(descriptor).isEmpty
    }

    // MARK: - Task-Session Link Resolution

    /// Find a task by its sync UUID string.
    public func fetchTaskBySyncId(_ syncId: String) throws -> TaskItem? {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.syncId == syncId }
        )
        return try context.fetch(descriptor).first
    }

    /// Find a task by its server integer ID.
    public func fetchTaskByServerId(_ serverId: Int) throws -> TaskItem? {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        return try context.fetch(descriptor).first
    }

    /// Link a focus session to a task by setting its SwiftData relationship.
    public func linkSessionToTask(sessionId: UUID, taskId: UUID, saveImmediately: Bool = true) throws {
        let sessionDescriptor = FetchDescriptor<FocusSessionRecord>(
            predicate: #Predicate { $0.id == sessionId }
        )
        guard let session = try context.fetch(sessionDescriptor).first else { return }

        let taskDescriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == taskId }
        )
        guard let task = try context.fetch(taskDescriptor).first else { return }

        session.task = task
        if saveImmediately {
            try context.save()
        }
    }

    // MARK: - Settings Sync

    /// Syncable preference keys and their mapping to UserPreferences properties.
    private static let syncableKeys: Set<String> = [
        "pomodoroMinutes", "shortBreakMinutes", "longBreakMinutes", "sessionsBeforeLongBreak",
        "autoStartBreaks", "autoStartNextPomodoro", "soundEnabled", "hapticEnabled",
        "keepScreenOn", "defaultMode", "themeName", "followSystemAppearance", "appearanceMode",
        "flowtimeMinMinutes", "timeBlockMinutes", "midpointCheckIn", "showJournalAfterSession"
    ]

    /// Reads all syncable preferences as key-value pairs with their update timestamps.
    public func getAllPreferencesAsKeyValue() throws -> [(key: String, value: String, updatedAt: Date)] {
        let prefs = try fetchPreferences()
        let now = Date.now
        var result: [(key: String, value: String, updatedAt: Date)] = []

        result.append(("pomodoroMinutes", String(Int(prefs.pomodoroDuration / 60)), now))
        result.append(("shortBreakMinutes", String(Int(prefs.shortBreakDuration / 60)), now))
        result.append(("longBreakMinutes", String(Int(prefs.longBreakDuration / 60)), now))
        result.append(("sessionsBeforeLongBreak", String(prefs.pomodorosPerCycle), now))
        result.append(("autoStartBreaks", String(prefs.autoStartBreaks), now))
        result.append(("autoStartNextPomodoro", String(prefs.autoStartWork), now))
        result.append(("soundEnabled", String(prefs.soundEnabled), now))
        result.append(("hapticEnabled", String(prefs.hapticEnabled), now))
        result.append(("keepScreenOn", String(prefs.keepScreenOn), now))
        result.append(("defaultMode", prefs.defaultMode, now))
        result.append(("themeName", prefs.themeName, now))
        result.append(("followSystemAppearance", String(prefs.followSystemAppearance), now))
        result.append(("appearanceMode", prefs.appearanceMode, now))
        result.append(("flowtimeMinMinutes", String(prefs.flowtimeMinSessionMinutes), now))
        result.append(("timeBlockMinutes", String(Int(prefs.defaultBlockDuration / 60)), now))
        result.append(("midpointCheckIn", String(prefs.blockMidpointCheckIn), now))
        result.append(("showJournalAfterSession", String(prefs.showJournalAfterSession), now))

        return result
    }

    /// Applies a single server preference by key.
    public func applyServerPreference(key: String, value: String, updatedAt: Date) throws {
        let prefs = try fetchPreferences()

        switch key {
        case "pomodoroMinutes":
            if let v = Int(value) { prefs.pomodoroDuration = TimeInterval(v * 60) }
        case "shortBreakMinutes":
            if let v = Int(value) { prefs.shortBreakDuration = TimeInterval(v * 60) }
        case "longBreakMinutes":
            if let v = Int(value) { prefs.longBreakDuration = TimeInterval(v * 60) }
        case "sessionsBeforeLongBreak":
            if let v = Int(value) { prefs.pomodorosPerCycle = v }
        case "autoStartBreaks":
            prefs.autoStartBreaks = (value == "true")
        case "autoStartNextPomodoro":
            prefs.autoStartWork = (value == "true")
        case "soundEnabled":
            prefs.soundEnabled = (value == "true")
        case "hapticEnabled":
            prefs.hapticEnabled = (value == "true")
        case "keepScreenOn":
            prefs.keepScreenOn = (value == "true")
        case "defaultMode":
            prefs.defaultMode = value
        case "themeName":
            prefs.themeName = value
        case "followSystemAppearance":
            prefs.followSystemAppearance = (value == "true")
        case "appearanceMode":
            prefs.appearanceMode = value
        case "flowtimeMinMinutes":
            if let v = Int(value) { prefs.flowtimeMinSessionMinutes = v }
        case "timeBlockMinutes":
            if let v = Int(value) { prefs.defaultBlockDuration = TimeInterval(v * 60) }
        case "midpointCheckIn":
            prefs.blockMidpointCheckIn = (value == "true")
        case "showJournalAfterSession":
            prefs.showJournalAfterSession = (value == "true")
        default:
            break
        }

        try savePreferences(prefs)
    }

    // MARK: - Wipe Operations

    public func deleteAllTasks() throws {
        let descriptor = FetchDescriptor<TaskItem>()
        let tasks = try context.fetch(descriptor)
        for task in tasks { context.delete(task) }
        try context.save()
    }

    public func deleteAllSessions() throws {
        let descriptor = FetchDescriptor<FocusSessionRecord>()
        let sessions = try context.fetch(descriptor)
        for session in sessions { context.delete(session) }
        try context.save()
    }

    public func deleteAllStats() throws {
        let descriptor = FetchDescriptor<DailyStats>()
        let stats = try context.fetch(descriptor)
        for stat in stats { context.delete(stat) }
        try context.save()
    }

    // MARK: - Count Operations

    public func getTaskCount() throws -> Int {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.isDeleted == false }
        )
        return try context.fetchCount(descriptor)
    }

    public func getSessionCount() throws -> Int {
        let descriptor = FetchDescriptor<FocusSessionRecord>()
        return try context.fetchCount(descriptor)
    }

    // MARK: - Session Sync Timestamp

    public func getLastSessionSyncTimestamp() -> String? {
        UserDefaults.standard.string(forKey: "lastSessionSyncTimestamp")
    }

    public func saveLastSessionSyncTimestamp(_ timestamp: String) {
        UserDefaults.standard.set(timestamp, forKey: "lastSessionSyncTimestamp")
    }
}
