// SwiftDataPersistenceService.swift
// Pepinillo — Deep Work Companion for Apple
//
// @MainActor-isolated service wrapping SwiftData ModelContext.
// Used by PersistenceClient.live(container:) to implement all data operations.
// All methods run on MainActor because container.mainContext is @MainActor.

import Foundation
import SwiftData

@MainActor
public final class SwiftDataPersistenceService {

    private let context: ModelContext

    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    // MARK: - Tasks

    public func fetchTasks() throws -> [TaskItem] {
        let descriptor = FetchDescriptor<TaskItem>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    public func saveTask(_ task: TaskItem) throws {
        if task.modelContext == nil {
            context.insert(task)
        }
        task.updatedAt = Date.now
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

    public func toggleTaskCompletion(id: UUID) throws {
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.id == id }
        )
        if let task = try context.fetch(descriptor).first {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date.now : nil
            task.updatedAt = Date.now
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
                if result.wasCompleted && result.mode == .pomodoro {
                    task.completedPomodoros += 1
                    task.updatedAt = Date.now
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
        try context.save()
        return subtask
    }

    public func toggleSubtask(id: UUID) throws {
        let descriptor = FetchDescriptor<SubTask>(predicate: #Predicate { $0.id == id })
        guard let subtask = try context.fetch(descriptor).first else { return }
        subtask.isCompleted.toggle()
        subtask.parent?.updatedAt = Date.now
        try context.save()
    }

    public func deleteSubtask(id: UUID) throws {
        let descriptor = FetchDescriptor<SubTask>(predicate: #Predicate { $0.id == id })
        if let subtask = try context.fetch(descriptor).first {
            subtask.parent?.updatedAt = Date.now
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
}
