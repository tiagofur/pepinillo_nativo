// TaskItem.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftData model for user tasks. Syncs via CloudKit.
// Maps to Flutter's TaskEntity but adds energy levels and focus mode affinity.

import Foundation
import SwiftData
import SwiftUI

@Model
public final class TaskItem {
    // MARK: - Identification
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: - Content
    public var title: String
    public var notes: String?
    public var isCompleted: Bool
    public var completedAt: Date?

    // MARK: - Organization
    public var priority: TaskPriority
    public var sortOrder: Int
    public var energyLevel: EnergyLevel
    public var dueDate: Date?
    public var scheduledForToday: Bool = false

    // MARK: - Focus Integration
    public var estimatedPomodoros: Int
    public var completedPomodoros: Int
    public var preferredMode: String?  // FocusMode.rawValue — which mode works best for this task type

    // MARK: - Sync Metadata
    public var syncId: String
    public var serverId: Int?
    public var isDirty: Bool = true
    public var isDeleted: Bool = false
    public var syncedAt: Date?

    // MARK: - Recurrence
    public var recurrenceRule: String?       // iCalendar RRULE string, e.g. "FREQ=DAILY", "FREQ=WEEKLY;BYDAY=MO,WE,FR"
    public var nextOccurrence: Date?         // Next date this task should generate a new instance
    public var isRecurringTemplate: Bool     // True = this is the template, not a generated instance
    public var recurringTemplateID: UUID?    // For generated instances: links back to the template

    // MARK: - Relationships
    @Relationship(deleteRule: .cascade)
    public var subtasks: [SubTask]

    @Relationship(inverse: \FocusSessionRecord.task)
    public var sessions: [FocusSessionRecord]

    // MARK: - Init

    public init(
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
        self.isDeleted = false
        self.subtasks = []
        self.sessions = []
    }

    // MARK: - Computed

    private static let workPhases: Set<String> = ["work", "flow", "block", "freeform"]

    public var totalFocusTime: TimeInterval {
        sessions
            .filter { $0.wasCompleted && (Self.workPhases.contains($0.phase) || $0.phase.isEmpty) }
            .reduce(0) { $0 + $1.actualDuration }
    }

    public var completionPercentage: Double {
        guard estimatedPomodoros > 0 else { return 0 }
        return min(1.0, Double(completedPomodoros) / Double(estimatedPomodoros))
    }

    public var subtaskProgress: (completed: Int, total: Int) {
        let total = subtasks.count
        let completed = subtasks.filter(\.isCompleted).count
        return (completed, total)
    }
}

// MARK: - Recurrence

public enum RecurrencePreset: String, CaseIterable {
    case daily       = "FREQ=DAILY"
    case weekdays    = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
    case weekly      = "FREQ=WEEKLY"
    case biweekly    = "FREQ=WEEKLY;INTERVAL=2"
    case monthly     = "FREQ=MONTHLY"

    public var displayName: String {
        switch self {
        case .daily:     return String(localized: "Daily")
        case .weekdays:  return String(localized: "Weekdays")
        case .weekly:    return String(localized: "Weekly")
        case .biweekly:  return String(localized: "Biweekly")
        case .monthly:   return String(localized: "Monthly")
        }
    }

    public var icon: String {
        switch self {
        case .daily:     return "arrow.clockwise"
        case .weekdays:  return "briefcase"
        case .weekly:    return "calendar"
        case .biweekly:  return "calendar.badge.clock"
        case .monthly:   return "calendar.circle"
        }
    }

    /// Compute the next occurrence date from the given date.
    public func nextDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            var next = calendar.date(byAdding: .day, value: 1, to: date)!
            while calendar.isDateInWeekend(next) {
                next = calendar.date(byAdding: .day, value: 1, to: next)!
            }
            return next
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2, to: date)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }

    public static func from(rule: String) -> RecurrencePreset? {
        allCases.first { $0.rawValue == rule }
    }
}

// MARK: - Supporting Enums

public enum TaskPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    public var displayName: String {
        switch self {
        case .none:   return String(localized: "None")
        case .low:    return String(localized: "Low")
        case .medium: return String(localized: "Medium")
        case .high:   return String(localized: "High")
        }
    }

    public var icon: String {
        switch self {
        case .none:   return ""
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        }
    }

    public static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Energy level for task batching (P1 feature, schema ready now).
public enum EnergyLevel: String, Codable, CaseIterable, Sendable {
    case deep     // Requires full concentration (writing, coding, studying)
    case shallow  // Low-effort tasks (emails, admin, reviews)
    case admin    // Maintenance tasks (filing, organizing, scheduling)

    public var displayName: String {
        switch self {
        case .deep:    return String(localized: "Deep Work")
        case .shallow: return String(localized: "Shallow Work")
        case .admin:   return String(localized: "Admin")
        }
    }

    public var icon: String {
        switch self {
        case .deep:    return "brain.head.profile"
        case .shallow: return "tray"
        case .admin:   return "folder"
        }
    }

    public var color: Color {
        switch self {
        case .deep:    return .purple
        case .shallow: return .blue
        case .admin:   return .orange
        }
    }
}
