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
