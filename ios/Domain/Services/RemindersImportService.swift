// RemindersImportService.swift
// Pepinillo — Deep Work Companion for Apple
//
// One-way import from Apple Reminders (EventKit) into Pepinillo tasks.
// Uses EKEventStore to request access and fetch incomplete reminders.
// Import is one-way — no continuous sync back to Reminders.
//
// REQUIREMENTS (Info.plist):
//   NSRemindersUsageDescription = "Pepinillo can import your reminders as tasks."

import Foundation
import EventKit

actor RemindersImportService {

    private let store = EKEventStore()

    enum ImportError: Error, LocalizedError {
        case accessDenied
        case fetchFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return String(localized: "Reminders access was denied. Enable it in Settings.")
            case .fetchFailed:
                return String(localized: "Failed to fetch reminders.")
            }
        }
    }

    /// Request access to Reminders. Returns true if granted.
    func requestAccess() async throws -> Bool {
        try await store.requestFullAccessToReminders()
    }

    /// Fetch all incomplete reminders from all calendars.
    func fetchIncompleteReminders() async throws -> [ImportedReminder] {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        guard status == .fullAccess else {
            throw ImportError.accessDenied
        }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )

        return try await withCheckedThrowingContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                guard let reminders else {
                    continuation.resume(throwing: ImportError.fetchFailed)
                    return
                }
                let imported = reminders.map { reminder in
                    ImportedReminder(
                        externalID: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "Untitled",
                        notes: reminder.notes,
                        priority: Self.mapPriority(reminder.priority),
                        calendarName: reminder.calendar?.title,
                        dueDate: Self.date(from: reminder.dueDateComponents)
                    )
                }
                continuation.resume(returning: imported)
            }
        }
    }

    // MARK: - Private

    private static func mapPriority(_ ekPriority: Int) -> TaskPriority {
        switch ekPriority {
        case 1...4:   return .high
        case 5:       return .medium
        case 6...9:   return .low
        default:      return .none
        }
    }

    private static func date(from components: DateComponents?) -> Date? {
        guard let components else { return nil }
        return Calendar.current.date(from: components)
    }
}

/// Value type representing a reminder ready to be imported as a TaskItem.
struct ImportedReminder: Sendable, Identifiable {
    let externalID: String
    let title: String
    let notes: String?
    let priority: TaskPriority
    let calendarName: String?
    let dueDate: Date?

    var id: String { externalID }

    /// Stable sync key for dedupe across re-imports (#187).
    var reminderSyncID: String { "reminder:\(externalID)" }

    func toTaskItemDTO(sortOrder: Int, syncId: String) -> TaskItemDTO {
        let cal = Calendar.current
        let scheduledForToday: Bool
        if let dueDate {
            scheduledForToday = cal.isDateInToday(dueDate)
        } else {
            scheduledForToday = false
        }
        return TaskItemDTO(
            title: title,
            notes: notes,
            priority: priority,
            sortOrder: sortOrder,
            dueDate: dueDate,
            scheduledForToday: scheduledForToday,
            syncId: syncId
        )
    }
}