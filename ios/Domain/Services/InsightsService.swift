// InsightsService.swift
// Pepinillo — Deep Work Companion for Apple
//
// Generates weekly focus insights from session history.
// Analyzes patterns (best focus time, mode preferences, streak trends)
// and produces human-readable summaries for the analytics dashboard.

import Foundation

struct FocusInsight: Equatable, Sendable {
    let title: String
    let body: String
    let emoji: String
    let category: Category

    enum Category: String, Sendable {
        case productivity
        case pattern
        case streak
        case suggestion
    }
}

struct InsightsService {

    /// Generate insights from the last 7 days of session data.
    func generateWeeklyInsights(
        sessions: [SessionRecordDTO],
        dailyStats: [DailyStatsDTO]
    ) -> [FocusInsight] {
        var insights: [FocusInsight] = []

        // 1. Total focus time
        let totalMinutes = sessions.reduce(0) { $0 + Int($1.actualDuration) } / 60
        if totalMinutes > 0 {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            insights.append(FocusInsight(
                title: String(localized: "Weekly Focus"),
                body: String(localized: "You focused for \(hours)h \(mins)m this week across \(sessions.count) sessions."),
                emoji: "📊",
                category: .productivity
            ))
        }

        // 2. Best focus day
        if let bestDay = dailyStats.max(by: { $0.totalFocusMinutes < $1.totalFocusMinutes }),
           bestDay.totalFocusMinutes > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: bestDay.date)
            insights.append(FocusInsight(
                title: String(localized: "Peak Day"),
                body: String(localized: "\(dayName) was your most productive day with \(bestDay.totalFocusMinutes) minutes of focus."),
                emoji: "🏆",
                category: .pattern
            ))
        }

        // 3. Mode preference
        let modeCounts = Dictionary(grouping: sessions, by: { $0.mode })
        if let topMode = modeCounts.max(by: { $0.value.count < $1.value.count }) {
            let modeName = FocusMode(rawValue: topMode.key)?.displayName ?? topMode.key
            insights.append(FocusInsight(
                title: String(localized: "Preferred Mode"),
                body: String(localized: "You used \(modeName) the most (\(topMode.value.count) sessions). It seems to work well for you."),
                emoji: "🎯",
                category: .pattern
            ))
        }

        // 4. Completion rate
        let completed = sessions.filter(\.wasCompleted).count
        if sessions.count >= 3 {
            let rate = Int(Double(completed) / Double(sessions.count) * 100)
            let insight: FocusInsight
            if rate >= 80 {
                insight = FocusInsight(
                    title: String(localized: "Strong Completion"),
                    body: String(localized: "You completed \(rate)% of sessions. Excellent follow-through!"),
                    emoji: "💪",
                    category: .productivity
                )
            } else if rate >= 50 {
                insight = FocusInsight(
                    title: String(localized: "Completion Rate"),
                    body: String(localized: "You completed \(rate)% of sessions. Try shorter sessions to boost this."),
                    emoji: "📈",
                    category: .suggestion
                )
            } else {
                insight = FocusInsight(
                    title: String(localized: "Room to Grow"),
                    body: String(localized: "Only \(rate)% of sessions completed. Consider starting with 15-minute Pomodoros."),
                    emoji: "🌱",
                    category: .suggestion
                )
            }
            insights.append(insight)
        }

        // 5. Streak
        let daysWithSessions = dailyStats.filter { $0.sessionsCompleted > 0 }.count
        if daysWithSessions >= 3 {
            insights.append(FocusInsight(
                title: String(localized: "Consistency"),
                body: String(localized: "You focused on \(daysWithSessions) out of 7 days. Keep the momentum going!"),
                emoji: "🔥",
                category: .streak
            ))
        }

        // 6. Average session length
        if !sessions.isEmpty {
            let avgMinutes = totalMinutes / sessions.count
            if avgMinutes > 0 {
                insights.append(FocusInsight(
                    title: String(localized: "Session Length"),
                    body: String(localized: "Your average session lasts \(avgMinutes) minutes."),
                    emoji: "⏱️",
                    category: .pattern
                ))
            }
        }

        return insights
    }
}
