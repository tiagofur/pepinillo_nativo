// GetInsightsIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// Siri / Apple Intelligence intent: "Give me focus insights in Pepinillo"
// Uses InsightsService to generate personalized productivity insights
// and returns the top 3 as spoken dialog.

import AppIntents
import Foundation
import SwiftData

struct GetInsightsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Focus Insights"
    static let description = IntentDescription(
        "Get personalized insights about your focus habits and productivity patterns.",
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

        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: today) else {
            return .result(dialog: "I couldn't compute the date range.")
        }

        // Fetch last 7 days of sessions (include all of today — #219)
        let predicate = #Predicate<FocusSessionRecord> {
            $0.startedAt >= weekStart && $0.startedAt < endOfToday
        }
        let records = (try? context.fetch(FetchDescriptor(predicate: predicate))) ?? []
        let sessions = records.map { $0.toDTO() }

        if sessions.isEmpty {
            return .result(dialog: "No focus sessions in the last 7 days. Start a session to begin tracking your patterns!")
        }

        // Build daily stats from sessions
        var dailyMap: [Date: (Int, Int)] = [:] // (seconds, sessions)
        for record in sessions {
            let day = calendar.startOfDay(for: record.startedAt)
            let (prevSecs, prevSes) = dailyMap[day] ?? (0, 0)
            dailyMap[day] = (prevSecs + Int(record.actualDuration), prevSes + (record.wasCompleted ? 1 : 0))
        }

        let dailyStats = dailyMap.map { date, data in
            DailyStatsDTO(
                date: date,
                totalFocusMinutes: data.0 / 60,
                sessionsCompleted: data.1,
                tasksCompleted: 0
            )
        }

        let service = InsightsService()
        let insights = service.generateWeeklyInsights(sessions: sessions, dailyStats: dailyStats)

        if insights.isEmpty {
            return .result(dialog: "Not enough data yet for insights. Keep focusing!")
        }

        // Return top 3 insights as spoken dialog
        let top = insights.prefix(3)
        let formatted = top.map { "\($0.emoji) \($0.title): \($0.body)" }.joined(separator: " ")
        return .result(dialog: "\(formatted)")
    }
}
