// CheckStatsIntent.swift
// Pepinillo — Deep Work Companion for Apple
//
// App Intent for Siri: "How's my focus today in Pepinillo?"
// Returns today's stats (minutes, sessions, streak) as spoken dialog.

import AppIntents
import Foundation
import SwiftData

struct CheckStatsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Focus Stats"
    static let description = IntentDescription(
        "Check your focus stats for today in Pepinillo.",
        categoryName: "Focus"
    )
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = try? makeIntentsModelContainer() else {
            return .result(dialog: "I couldn't access your focus data right now.")
        }

        let context = ModelContext(container)
        let today = Calendar.current.startOfDay(for: .now)

        // Fetch today's stats
        let statsPredicate = #Predicate<DailyStats> { $0.date >= today }
        let statsDescriptor = FetchDescriptor<DailyStats>(predicate: statsPredicate)
        let stats = (try? context.fetch(statsDescriptor))?.first

        // Fetch streak from preferences
        let prefsDescriptor = FetchDescriptor<UserPreferences>()
        let prefs = (try? context.fetch(prefsDescriptor))?.first

        let minutes = stats?.totalFocusMinutes ?? 0
        let sessions = stats?.sessionsCompleted ?? 0
        let streak = prefs?.currentStreakDays ?? 0

        if minutes == 0 {
            if streak > 0 {
                return .result(dialog: "You haven't focused yet today. Your streak is \(streak) days — don't let it drop! 🔥")
            }
            return .result(dialog: "No focus sessions yet today. Ready to start one? 🎯")
        }

        var response = String(localized: "Today you've focused \(minutes) minutes across \(sessions) session\(sessions == 1 ? "" : "s").")

        if streak > 0 {
            response += " " + String(localized: "Your streak is \(streak) day\(streak == 1 ? "" : "s"). 🔥")
        }

        if let dominant = stats?.dominantMode {
            response += " " + String(localized: "Your most used mode: \(dominant.displayName).")
        }

        return .result(dialog: "\(response)")
    }
}
