// GetWeeklyReportIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Siri / Apple Intelligence intent: "How was my focus this week in Pepinillo?"
// Returns a spoken summary of weekly productivity data without opening the app.

import AppIntents
import Foundation
import SwiftData

struct GetWeeklyReportIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Weekly Focus Report"
    static let description = IntentDescription(
        "Get a summary of your focus productivity this week compared to last week.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = try? makeIntentsModelContainer() else {
            return .result(dialog: "I couldn't access your focus data right now.")
        }

        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        guard let currentStart = calendar.date(byAdding: .day, value: -6, to: today),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: today),
              let previousStart = calendar.date(byAdding: .day, value: -13, to: today) else {
            return .result(dialog: "I couldn't compute the date range.")
        }
        let previousEnd = currentStart

        // Fetch sessions for both weeks
        let currentPredicate = #Predicate<FocusSessionRecord> {
            $0.startedAt >= currentStart && $0.startedAt < endOfToday
        }
        let previousPredicate = #Predicate<FocusSessionRecord> {
            $0.startedAt >= previousStart && $0.startedAt < previousEnd
        }

        let currentRecords = (try? context.fetch(FetchDescriptor(predicate: currentPredicate))) ?? []
        let previousRecords = (try? context.fetch(FetchDescriptor(predicate: previousPredicate))) ?? []

        let currentSessions = currentRecords.map { $0.toDTO() }
        let previousSessions = previousRecords.map { $0.toDTO() }

        // Fetch streak
        let prefs = (try? context.fetch(FetchDescriptor<UserPreferences>()))?.first
        let streak = prefs?.currentStreakDays ?? 0

        let service = WeeklyReportService()
        let report = service.computeWeeklyReport(
            currentWeekSessions: currentSessions,
            previousWeekSessions: previousSessions,
            currentStreakDays: streak
        )

        return .result(dialog: "\(formatReport(report))")
    }

    private func formatReport(_ report: WeeklyReportData) -> String {
        if report.currentWeekSessions == 0 {
            return String(localized: "You haven't had any focus sessions this week yet. Ready to start one?")
        }

        let hours = report.currentWeekMinutes / 60
        let mins = report.currentWeekMinutes % 60
        var parts: [String] = []

        // Total
        if hours > 0 {
            parts.append(String(localized: "This week you focused for \(hours) hours and \(mins) minutes across \(report.currentWeekSessions) sessions."))
        } else {
            parts.append(String(localized: "This week you focused for \(mins) minutes across \(report.currentWeekSessions) sessions."))
        }

        // Trend
        if report.previousWeekSessions > 0 {
            let delta = report.minutesDelta
            if delta > 0 {
                parts.append(String(localized: "That's \(delta) minutes more than last week — great improvement!"))
            } else if delta < 0 {
                parts.append(String(localized: "That's \(abs(delta)) minutes less than last week."))
            } else {
                parts.append(String(localized: "Same as last week — steady consistency."))
            }
        }

        // Completion rate
        let rate = Int(report.completionRate * 100)
        parts.append(String(localized: "Your completion rate is \(rate)%."))

        // Best day
        if let bestDay = report.bestDayName {
            parts.append(String(localized: "\(bestDay) was your most productive day with \(report.bestDayMinutes) minutes."))
        }

        // Dominant mode
        if let mode = report.dominantMode {
            parts.append(String(localized: "Your most used mode was \(mode.displayName)."))
        }

        // Streak
        if report.currentStreakDays > 0 {
            parts.append(String(localized: "Current streak: \(report.currentStreakDays) days."))
        }

        return parts.joined(separator: " ")
    }
}
