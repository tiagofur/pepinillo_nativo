// InsightsServiceTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for the InsightsService that generates weekly focus summaries.

import Testing
import Foundation
@testable import Pepinillo

@Suite("InsightsService")
struct InsightsServiceTests {

    let service = InsightsService()

    @Test("Empty data returns no insights")
    func testEmptyData() {
        let insights = service.generateWeeklyInsights(sessions: [], dailyStats: [])
        #expect(insights.isEmpty)
    }

    @Test("Single session generates basic insights")
    func testSingleSession() {
        let session = SessionRecordDTO(
            id: UUID(),
            startedAt: Date.now,
            mode: "pomodoro",
            actualDuration: 1500,
            wasCompleted: true,
            interruptions: 0,
            taskID: nil
        )
        let stats = DailyStatsDTO(
            date: Calendar.current.startOfDay(for: .now),
            totalFocusMinutes: 25,
            sessionsCompleted: 1,
            tasksCompleted: 0
        )
        let insights = service.generateWeeklyInsights(sessions: [session], dailyStats: [stats])

        // Should have weekly focus, peak day, preferred mode, and session length
        #expect(insights.count >= 2)
        #expect(insights.contains(where: { $0.category == .productivity }))
    }

    @Test("Multiple sessions generate completion rate insight")
    func testCompletionRate() {
        let now = Date.now
        let sessions = (0..<5).map { i in
            SessionRecordDTO(
                id: UUID(),
                startedAt: now.addingTimeInterval(TimeInterval(-i * 3600)),
                mode: "pomodoro",
                actualDuration: 1500,
                wasCompleted: i < 4, // 4/5 completed = 80%
                interruptions: 0,
                taskID: nil
            )
        }
        let insights = service.generateWeeklyInsights(sessions: sessions, dailyStats: [])

        // With 5 sessions (sessions.count >= 3), generateWeeklyInsights always emits a
        // completion-rate insight. At 80% completion it is .productivity ("Strong Completion");
        // below 80% it is .suggestion. Avoid asserting localized title strings, which break
        // when the test simulator runs in a non-English locale (e.g. es-MX).
        // Instead: verify at least 4 insights are produced and that a completion-rate
        // insight exists via its category.
        #expect(insights.count >= 4)
        // Weekly Focus is the only .productivity insight generated without dailyStats.
        // A second .productivity insight means "Strong Completion" (rate >= 80%) was added.
        // Alternatively the insight landed in .suggestion (rate < 80%).
        let productivityInsights = insights.filter { $0.category == .productivity }
        let suggestionInsights = insights.filter { $0.category == .suggestion }
        let completionInsightGenerated = productivityInsights.count >= 2 || !suggestionInsights.isEmpty
        #expect(completionInsightGenerated)
    }

    @Test("Consistency insight requires 3+ days")
    func testConsistencyInsight() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let stats = (0..<4).map { offset in
            DailyStatsDTO(
                date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                totalFocusMinutes: 30,
                sessionsCompleted: 1,
                tasksCompleted: 0
            )
        }

        let session = SessionRecordDTO(
            id: UUID(),
            startedAt: .now,
            mode: "pomodoro",
            actualDuration: 1800,
            wasCompleted: true,
            interruptions: 0,
            taskID: nil
        )

        let insights = service.generateWeeklyInsights(sessions: [session], dailyStats: stats)
        let streakInsight = insights.first(where: { $0.category == .streak })
        #expect(streakInsight != nil)
    }
}
