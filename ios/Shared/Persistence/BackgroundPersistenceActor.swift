// BackgroundPersistenceActor.swift
// Pepinillo — Deep Work Companion for Apple
//
// @ModelActor that owns its OWN background ModelContext (provided by the
// @ModelActor macro via init(modelContainer:)). All SwiftData reads/writes and
// all @Model -> Sendable DTO mapping happen INSIDE this actor's isolation, so
// no @Model object ever escapes. This moves every persistence operation off the
// main thread, which is the root-cause fix for launch / tab-switch freezes.

import Foundation
import SwiftData

@ModelActor
public actor BackgroundPersistenceActor {

    /// Service operating on this actor's own background context.
    private var service: SwiftDataPersistenceService {
        SwiftDataPersistenceService(context: modelContext)
    }

    // MARK: - Tasks

    func fetchTasks() throws -> [TaskItemDTO] {
        let svc = service
        let tasks = try svc.fetchTasks().filter { !$0.isDeleted }
        // One batch fetch of subtask counts to avoid an N+1 relationship fault.
        let progress = try svc.subtaskProgressByTask()
        return tasks.map { TaskItemDTO(from: $0, subtaskProgress: progress[$0.id] ?? (0, 0)) }
    }

    func saveTask(_ taskDTO: TaskItemDTO) throws {
        let svc = service
        let taskID = taskDTO.id
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == taskID }
        )
        descriptor.fetchLimit = 1
        let existing = try modelContext.fetch(descriptor).first
        if let existing {
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
            existing.isDirty = true  // Mark dirty for sync
            // Set nextOccurrence when recurrence rule is first applied
            if taskDTO.isRecurringTemplate, existing.nextOccurrence == nil,
               let rule = taskDTO.recurrenceRule,
               let preset = RecurrencePreset.from(rule: rule) {
                existing.nextOccurrence = preset.nextDate(after: Calendar.current.startOfDay(for: .now))
            } else if !taskDTO.isRecurringTemplate {
                existing.nextOccurrence = nil
            }
            try svc.saveTask(existing)
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
            newTask.isDirty = true  // New tasks are dirty
            if taskDTO.isRecurringTemplate,
               let rule = taskDTO.recurrenceRule,
               let preset = RecurrencePreset.from(rule: rule) {
                newTask.nextOccurrence = preset.nextDate(after: Calendar.current.startOfDay(for: .now))
            }
            try svc.saveTask(newTask)
        }
    }

    func incrementTaskPomodoros(id: UUID) throws {
        try service.incrementTaskPomodoros(id: id)
    }

    func deleteTask(id: UUID) throws {
        try service.softDeleteTask(id: id)
    }

    // MARK: - Subtasks

    func fetchSubtasks(for taskID: UUID) throws -> [SubTaskDTO] {
        try service.fetchSubtasks(for: taskID).map { SubTaskDTO(from: $0) }
    }

    func addSubtask(to taskID: UUID, title: String) throws -> SubTaskDTO {
        SubTaskDTO(from: try service.addSubtask(to: taskID, title: title))
    }

    func toggleSubtask(id: UUID) throws {
        try service.toggleSubtask(id: id)
    }

    func deleteSubtask(id: UUID) throws {
        try service.deleteSubtask(id: id)
    }

    func fetchTaskTotalFocusSeconds(for taskID: UUID) throws -> TimeInterval {
        try service.fetchTaskTotalFocusSeconds(for: taskID)
    }

    // MARK: - Sessions

    func saveSession(_ result: FocusSessionResult) throws {
        try service.saveSession(result)
    }

    func fetchSessions(from start: Date, to end: Date) throws -> [SessionRecordDTO] {
        try service.fetchSessions(from: start, to: end).map { SessionRecordDTO(from: $0) }
    }

    func fetchSessionsForTask(taskID: UUID) throws -> [SessionRecordDTO] {
        try service.fetchSessionsForTask(taskID: taskID).map { SessionRecordDTO(from: $0) }
    }

    func fetchTaskAnalytics(taskID: UUID) throws -> TaskAnalyticsDTO {
        try service.fetchTaskAnalytics(taskID: taskID)
    }

    func saveJournalEntry(sessionID: UUID, note: String?, rating: Int?) throws {
        try service.saveJournalEntry(sessionID: sessionID, note: note, rating: rating)
    }

    // MARK: - Daily Stats

    func fetchDailyStats(for date: Date) throws -> DailyStatsDTO? {
        guard let stats = try service.fetchDailyStats(for: date) else { return nil }
        return DailyStatsDTO(from: stats)
    }

    func fetchDailyStatsRange(from start: Date, to end: Date) throws -> [DailyStatsDTO] {
        try service.fetchDailyStatsRange(from: start, to: end).map { DailyStatsDTO(from: $0) }
    }

    // MARK: - Preferences

    func fetchPreferences() throws -> UserPreferencesDTO {
        UserPreferencesDTO(from: try service.fetchPreferences())
    }

    func savePreferences(_ prefsDTO: UserPreferencesDTO) throws {
        let svc = service
        let prefs = try svc.fetchPreferences()
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
        prefs.showJournalAfterSession = prefsDTO.showJournalAfterSession
        prefs.healthLoggingEnabled = prefsDTO.healthLoggingEnabled
        prefs.adhdFriendlyEnabled = prefsDTO.adhdFriendlyEnabled
        prefs.calendarIntegrationEnabled = prefsDTO.calendarIntegrationEnabled
        prefs.isProUser = prefsDTO.isProUser
        prefs.appleUserID = prefsDTO.appleUserID
        prefs.displayName = prefsDTO.displayName
        prefs.userEmail = prefsDTO.userEmail
        try svc.savePreferences(prefs)
    }

    // MARK: - Cached User

    func fetchCachedUser() throws -> CachedUserDTO? {
        guard let user = try service.fetchCachedUser() else { return nil }
        return CachedUserDTO(from: user)
    }

    func saveCachedUser(_ dto: CachedUserDTO) throws {
        try service.saveCachedUser(dto)
    }

    func deleteCachedUser() throws {
        try service.deleteCachedUser()
    }

    // MARK: - Recurring Tasks

    func generateRecurringTasks() throws {
        try service.generateRecurringTasksIfNeeded()
    }

    // MARK: - Sync Operations

    func fetchDirtyTasks() throws -> [TaskItemDTO] {
        let svc = service
        let progress = try svc.subtaskProgressByTask()
        return try svc.fetchDirtyTasks().map { TaskItemDTO(from: $0, subtaskProgress: progress[$0.id] ?? (0, 0)) }
    }

    func markTasksSynced(syncIds: [String], syncTimestamp: String) throws {
        try service.markTasksSynced(syncIds: syncIds, syncTimestamp: syncTimestamp)
    }

    func upsertTaskFromServer(_ serverTask: TaskSyncDTO, saveImmediately: Bool) throws {
        try service.upsertTaskFromServer(serverTask, saveImmediately: saveImmediately)
    }

    func save() throws {
        try service.save()
    }

    func purgeTaskBySyncId(_ syncId: String) throws {
        try service.purgeTaskBySyncId(syncId)
    }

    func getLastSyncTimestamp() -> String? {
        service.getLastSyncTimestamp()
    }

    func saveLastSyncTimestamp(_ timestamp: String) {
        service.saveLastSyncTimestamp(timestamp)
    }

    // MARK: - Session Sync Operations

    func fetchDirtySessions() throws -> [SessionRecordDTO] {
        try service.fetchDirtySessions().map { SessionRecordDTO(from: $0) }
    }

    func markSessionsSynced(ids: [UUID]) throws {
        try service.markSessionsSynced(ids: ids)
    }

    func upsertSessionFromServer(_ dto: FocusSessionSyncDTO, saveImmediately: Bool) throws {
        try service.upsertSessionFromServer(dto, saveImmediately: saveImmediately)
    }

    func sessionExists(id: String) throws -> Bool {
        try service.sessionExists(id: id)
    }

    // MARK: - Task-Session Link Resolution

    func fetchTaskBySyncId(_ syncId: String) throws -> TaskItemDTO? {
        try service.fetchTaskBySyncId(syncId).map { TaskItemDTO(from: $0) }
    }

    func fetchTaskByServerId(_ serverId: Int) throws -> TaskItemDTO? {
        try service.fetchTaskByServerId(serverId).map { TaskItemDTO(from: $0) }
    }

    func linkSessionToTask(sessionId: UUID, taskId: UUID, saveImmediately: Bool) throws {
        try service.linkSessionToTask(sessionId: sessionId, taskId: taskId, saveImmediately: saveImmediately)
    }

    // MARK: - Settings Sync

    func getAllPreferencesAsKeyValue() -> [(key: String, value: String, updatedAt: Date)] {
        (try? service.getAllPreferencesAsKeyValue()) ?? []
    }

    func applyServerPreference(key: String, value: String, updatedAt: Date) {
        try? service.applyServerPreference(key: key, value: value, updatedAt: updatedAt)
    }

    // MARK: - Wipe Operations

    /// Deletes all task rows from the store. Throws on save failure so callers
    /// know the wipe did not complete and can abort a wipeAndSync safely.
    func deleteAllTasks() throws {
        try service.deleteAllTasks()
    }

    /// Deletes all session rows from the store. Throws on save failure.
    func deleteAllSessions() throws {
        try service.deleteAllSessions()
    }

    /// Deletes all daily-stat rows from the store. Throws on save failure.
    func deleteAllStats() throws {
        try service.deleteAllStats()
    }

    // MARK: - Counts

    func getTaskCount() -> Int {
        (try? service.getTaskCount()) ?? 0
    }

    func getSessionCount() -> Int {
        (try? service.getSessionCount()) ?? 0
    }

    // MARK: - Session Sync Timestamp

    func getLastSessionSyncTimestamp() -> String? {
        service.getLastSessionSyncTimestamp()
    }

    func saveLastSessionSyncTimestamp(_ timestamp: String) {
        service.saveLastSessionSyncTimestamp(timestamp)
    }
}
