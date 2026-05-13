// AnalyticsFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for AnalyticsFeature: period changes, data aggregation, streak display.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@MainActor
struct AnalyticsFeatureTests {

    // MARK: - Helpers

    private nonisolated func emptyPrefs() -> UserPreferencesDTO {
        UserPreferencesDTO(soundEnabled: true, hapticEnabled: true, defaultMode: "pomodoro", themeName: "default")
    }

    // MARK: - Default State

    @Test func defaultPeriodIsWeek() {
        let state = AnalyticsFeature.State()
        #expect(state.period == .week)
    }

    // MARK: - Period Changes

    @Test func periodChangeUpdatesState() async {
        let prefs = emptyPrefs()
        var state = AnalyticsFeature.State()
        state.isProUser = true
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
        }
        store.exhaustivity = .off

        await store.send(.periodChanged(.month)) {
            $0.period = .month
        }

        #expect(store.state.period == .month)
    }

    @Test func emptyStatsProducesZeroTotals() async {
        let prefs = emptyPrefs()
        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()

        #expect(store.state.totalFocusMinutes == 0)
        #expect(store.state.sessionsCompleted == 0)
        #expect(store.state.modeBreakdown.isEmpty)
        #expect(store.state.dominantMode == nil)
        #expect(store.state.currentStreakDays == 0)
        #expect(store.state.longestStreakDays == 0)
    }

    @Test func chartDataFilledForAllDaysInPeriod() async {
        let prefs = emptyPrefs()
        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()

        // Chart data should have 7 points for week period (all zeros)
        #expect(store.state.chartData.count == 7)
    }

    @Test func periodDays() {
        #expect(AnalyticsFeature.State.Period.week.days == 7)
        #expect(AnalyticsFeature.State.Period.month.days == 30)
        #expect(AnalyticsFeature.State.Period.year.days == 364)
    }

    // MARK: - Weekly Review

    @Test func weeklyReviewIsNilByDefault() {
        let state = AnalyticsFeature.State()
        #expect(state.weeklyReview == nil)
    }

    @Test func weeklyReviewTappedSetsShowFlag() async {
        var state = AnalyticsFeature.State()
        state.isProUser = true

        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        }

        await store.send(.weeklyReviewTapped) {
            $0.weeklyReview = WeeklyReviewFeature.State()
        }
    }

    @Test func weeklyReviewDismissedClearsShowFlag() async {
        var initialState = AnalyticsFeature.State()
        initialState.weeklyReview = WeeklyReviewFeature.State()

        let store = TestStore(initialState: initialState) {
            AnalyticsFeature()
        }

        await store.send(.weeklyReviewDismissed) {
            $0.weeklyReview = nil
        }
    }

    @Test func weeklyReviewTappedThenDismissedRestoresState() async {
        var state = AnalyticsFeature.State()
        state.isProUser = true

        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        }

        await store.send(.weeklyReviewTapped) { $0.weeklyReview = WeeklyReviewFeature.State() }
        await store.send(.weeklyReviewDismissed) { $0.weeklyReview = nil }
    }

    // MARK: - Period display names

    @Test func periodDisplayNames() {
        #expect(AnalyticsFeature.State.Period.week.displayName == "7D")
        #expect(AnalyticsFeature.State.Period.month.displayName == "30D")
        #expect(AnalyticsFeature.State.Period.year.displayName == "Year")
    }

    // MARK: - allDataLoaded — totals

    @Test func allDataLoadedSetsCorrectTotals() async {
        let now = Calendar.current.startOfDay(for: Date.now)
        let snapshot = AnalyticsFeature.DayDataSnapshot(
            date: now,
            totalFocusSeconds: 3600,   // 60 minutes
            sessionsCompleted: 3,
            pomodoroSeconds: 2700,     // 45 min — dominant
            flowtimeSeconds: 900,      // 15 min
            timeBlockSeconds: 0,
            stopwatchSeconds: 0,
            hadFocusSession: true
        )

        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.allDataLoaded(
            snapshots: [snapshot],
            insights: .empty,
            streakDays: 0,
            longestStreak: 0,
            achievements: [],
            weeklyInsights: []
        ))

        #expect(store.state.totalFocusMinutes == 60)
        #expect(store.state.sessionsCompleted == 3)
        #expect(store.state.dominantMode == .pomodoro)
    }

    // MARK: - allDataLoaded — streaks

    @Test func allDataLoadedUpdatesStreakValues() async {
        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.allDataLoaded(
            snapshots: [],
            insights: .empty,
            streakDays: 7,
            longestStreak: 30,
            achievements: [],
            weeklyInsights: []
        ))

        #expect(store.state.currentStreakDays == 7)
        #expect(store.state.longestStreakDays == 30)
    }

    // MARK: - Productivity Insights

    // MARK: - PRO Gating

    @Test func freeUserPeriodChangeToMonthRequestsPaywall() async {
        let prefs = emptyPrefs()
        var state = AnalyticsFeature.State()
        state.isProUser = false
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
        }
        store.exhaustivity = .off

        await store.send(.periodChanged(.month))
        await store.receive(.paywallRequested)
        #expect(store.state.period == .week)
    }

    @Test func freeUserPeriodChangeToYearRequestsPaywall() async {
        let prefs = emptyPrefs()
        var state = AnalyticsFeature.State()
        state.isProUser = false
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
        }
        store.exhaustivity = .off

        await store.send(.periodChanged(.year))
        await store.receive(.paywallRequested)
        #expect(store.state.period == .week)
    }

    @Test func proUserCanChangePeriodToMonth() async {
        let prefs = emptyPrefs()
        var state = AnalyticsFeature.State()
        state.isProUser = true
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
        }
        store.exhaustivity = .off

        await store.send(.periodChanged(.month)) {
            $0.period = .month
        }
    }

    @Test func freeUserWeeklyReviewTapRequestsPaywall() async {
        var state = AnalyticsFeature.State()
        state.isProUser = false
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.weeklyReviewTapped)
        await store.receive(.paywallRequested)
        #expect(store.state.weeklyReview == nil)
    }

    @Test func freeUserMonthlyReviewTapRequestsPaywall() async {
        var state = AnalyticsFeature.State()
        state.isProUser = false
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.monthlyReviewTapped)
        await store.receive(.paywallRequested)
        #expect(store.state.monthlyReview == nil)
    }

    @Test func freeUserAIReportTapRequestsPaywall() async {
        var state = AnalyticsFeature.State()
        state.isProUser = false
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.aiReportTapped(.week))
        await store.receive(.paywallRequested)
        #expect(store.state.aiReport == nil)
    }

    @Test func proUserAIReportTapPresentsSheet() async {
        var state = AnalyticsFeature.State()
        state.isProUser = true
        let store = TestStore(initialState: state) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.aiReportTapped(.week)) {
            $0.aiReport = AIReportFeature.State(period: .week)
        }
    }

    @Test func allDataLoadedSetsInsights() async {
        let insights = AnalyticsFeature.ProductivityInsights(
            peakHourRange: "9 AM–11 AM",
            bestDayOfWeek: "Tuesday",
            sessionCompletionRate: 0.8,
            avgInterruptions: 0.5,
            focusQualityScore: 75
        )

        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.allDataLoaded(
            snapshots: [],
            insights: insights,
            streakDays: 0,
            longestStreak: 0,
            achievements: [],
            weeklyInsights: []
        ))

        #expect(store.state.peakHourRange == "9 AM–11 AM")
        #expect(store.state.bestDayOfWeek == "Tuesday")
        #expect(store.state.sessionCompletionRate == 0.8)
        #expect(store.state.focusQualityScore == 75)
    }
}
