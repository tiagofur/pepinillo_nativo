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

    @Test func todayStatsIgnoreEarlierChartPoints() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        var state = AnalyticsFeature.State()
        state.chartData = [
            .init(
                id: yesterday,
                date: yesterday,
                totalMinutes: 90,
                pomodoroMinutes: 90,
                flowtimeMinutes: 0,
                timeBlockMinutes: 0,
                stopwatchMinutes: 0,
                sessionsCompleted: 3
            ),
            .init(
                id: today,
                date: today,
                totalMinutes: 25,
                pomodoroMinutes: 25,
                flowtimeMinutes: 0,
                timeBlockMinutes: 0,
                stopwatchMinutes: 0,
                sessionsCompleted: 1
            )
        ]

        #expect(state.todayFocusMinutes == 25)
        #expect(state.todaySessions == 1)
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
            $0.persistenceClient.fetchDailyStatsRange = { _, _ in [] }
            $0.persistenceClient.fetchSessionCount = { _ in 0 }
            $0.persistenceClient.fetchEarlyBirdSessionCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedPomodoroCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedFlowtimeCount = { _ in 0 }
            $0.persistenceClient.resolveAchievements = { $0 }
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
            $0.persistenceClient.fetchDailyStatsRange = { _, _ in [] }
            $0.persistenceClient.fetchSessionCount = { _ in 0 }
            $0.persistenceClient.fetchEarlyBirdSessionCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedPomodoroCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedFlowtimeCount = { _ in 0 }
            $0.persistenceClient.resolveAchievements = { $0 }
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
            $0.persistenceClient.fetchDailyStatsRange = { _, _ in [] }
            $0.persistenceClient.fetchSessionCount = { _ in 0 }
            $0.persistenceClient.fetchEarlyBirdSessionCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedPomodoroCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedFlowtimeCount = { _ in 0 }
            $0.persistenceClient.resolveAchievements = { $0 }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()

        // Chart data should have 7 points for week period (all zeros)
        #expect(store.state.chartData.count == 7)
    }

    @Test("load overlays stored unlock dates over recomputed ones")
    func loadOverlaysStoredUnlockDates() async {
        // Proves the load effect routes through resolveAchievements: the stub
        // stamps a fixed date and the state must reflect it (not recomputed now).
        let storedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let prefs = emptyPrefs()
        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { prefs }
            $0.persistenceClient.fetchDailyStatsRange = { _, _ in [] }
            $0.persistenceClient.fetchSessionCount = { _ in 0 }
            $0.persistenceClient.fetchEarlyBirdSessionCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedPomodoroCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedFlowtimeCount = { _ in 0 }
            $0.persistenceClient.resolveAchievements = { derived in
                derived.map { UserAchievement(achievement: $0.achievement, unlockedAt: storedDate, progress: $0.progress) }
            }
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.skipReceivedActions()

        #expect(!store.state.achievements.isEmpty)
        #expect(store.state.achievements.allSatisfy { $0.unlockedAt == storedDate })
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
            streakProtectionApplied: false,
            achievements: [],
            weeklyInsights: []
        ))

        #expect(store.state.totalFocusMinutes == 60)
        #expect(store.state.sessionsCompleted == 3)
        #expect(store.state.dominantMode == .pomodoro)
    }

    // MARK: - chartData <-> totals invariant
    //
    // The compact stats row and weekly preview line both read from the 7-day chart window.
    // When period == .week, chartData.reduce(totalMinutes) MUST equal totalFocusMinutes and
    // chartData.reduce(sessionsCompleted) MUST equal sessionsCompleted — otherwise the
    // numbers shown in the UI would be inconsistent with the bars displayed in the chart.

    @Test func weekPeriodChartSumMatchesTotals() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)

        // Build 7 snapshots with known values
        let snapshots: [AnalyticsFeature.DayDataSnapshot] = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            return AnalyticsFeature.DayDataSnapshot(
                date: date,
                totalFocusSeconds: (offset + 1) * 600,  // 10, 20, 30, ... 70 minutes
                sessionsCompleted: offset + 1,
                pomodoroSeconds:   (offset + 1) * 600,
                flowtimeSeconds:   0,
                timeBlockSeconds:  0,
                stopwatchSeconds:  0,
                hadFocusSession:   true
            )
        }

        let expectedTotalMinutes = snapshots.reduce(0) { $0 + $1.totalFocusSeconds } / 60
        let expectedSessions = snapshots.reduce(0) { $0 + $1.sessionsCompleted }

        let store = TestStore(initialState: AnalyticsFeature.State()) {
            AnalyticsFeature()
        }
        store.exhaustivity = .off

        await store.send(.allDataLoaded(
            snapshots: snapshots,
            insights: .empty,
            streakDays: 0,
            longestStreak: 0,
            streakProtectionApplied: false,
            achievements: [],
            weeklyInsights: []
        ))

        // chartData has one point per day in the 7-day period
        #expect(store.state.chartData.count == 7)

        // Sum of chart bar heights (in minutes) must equal the period totals
        let chartMinutesSum = store.state.chartData.reduce(0) { $0 + $1.totalMinutes }
        let chartSessionsSum = store.state.chartData.reduce(0) { $0 + $1.sessionsCompleted }

        #expect(chartMinutesSum == expectedTotalMinutes,
            "Chart bars sum (\(chartMinutesSum)m) must equal totalFocusMinutes (\(expectedTotalMinutes)m)")
        #expect(chartSessionsSum == expectedSessions,
            "Chart sessions sum (\(chartSessionsSum)) must equal sessionsCompleted (\(expectedSessions))")

        // The store-level totals must also match
        #expect(store.state.totalFocusMinutes == expectedTotalMinutes)
        #expect(store.state.sessionsCompleted == expectedSessions)
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
            streakProtectionApplied: false,
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
            $0.persistenceClient.fetchDailyStatsRange = { _, _ in [] }
            $0.persistenceClient.fetchSessionCount = { _ in 0 }
            $0.persistenceClient.fetchEarlyBirdSessionCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedPomodoroCount = { _ in 0 }
            $0.persistenceClient.fetchCompletedFlowtimeCount = { _ in 0 }
            $0.persistenceClient.resolveAchievements = { $0 }
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
            streakProtectionApplied: false,
            achievements: [],
            weeklyInsights: []
        ))

        #expect(store.state.peakHourRange == "9 AM–11 AM")
        #expect(store.state.bestDayOfWeek == "Tuesday")
        #expect(store.state.sessionCompletionRate == 0.8)
        #expect(store.state.focusQualityScore == 75)
    }
}

@Suite("TaskAnalyticsFeature")
struct TaskAnalyticsFeatureFailureTests {

    @Test("load failure releases spinner instead of wedging on")
    @MainActor
    func loadFailureReleasesSpinner() async {
        struct AnalyticsError: Error {}
        let store = TestStore(
            initialState: TaskAnalyticsFeature.State(taskID: UUID(), taskTitle: "T")
        ) {
            TaskAnalyticsFeature()
        } withDependencies: {
            $0.persistenceClient.fetchTaskAnalytics = { _ in throw AnalyticsError() }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        // S1 RED pre-fix: the effect dies unhandled, nothing is ever received.
        // The sheet falls back to its existing empty state (no error UI there).
        await store.receive(.analyticsFailed) {
            $0.isLoading = false
            #expect($0.analytics == nil)
        }
    }
}

@Suite("InsightsService period text")
struct InsightsPeriodTextTests {

    @Test("streak insight uses the selected period length, not hardcoded 7 days")
    func streakInsightUsesPeriodDays() {
        let service = InsightsService()
        let stats = (0..<5).map { i in
            DailyStatsDTO(
                date: Date(timeIntervalSince1970: 1_800_000_000 + Double(i * 86400)),
                totalFocusMinutes: 25,
                sessionsCompleted: 1,
                tasksCompleted: 0
            )
        }

        let insights30 = service.generateWeeklyInsights(sessions: [], dailyStats: stats, periodDays: 30)
        let streak30 = insights30.first(where: { $0.category == .streak })
        // S4 RED pre-fix: no periodDays parameter exists (compile error).
        #expect(streak30?.body.contains("out of 30 days") == true)

        // Default stays weekly (existing callers unchanged).
        let insights7 = service.generateWeeklyInsights(sessions: [], dailyStats: stats)
        let streak7 = insights7.first(where: { $0.category == .streak })
        #expect(streak7?.body.contains("out of 7 days") == true)
    }
}

@Suite("MonthlyReview day-equivalent window")
struct MonthlyReviewWindowTests {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("mid-month compares first N days of previous month")
    func midMonthComparesFirstNDays() {
        // 2026-03-15 → previous window Feb 1 .. Feb 16.
        let today = Date(timeIntervalSince1970: 1_773_576_000)
        let window = MonthlyReviewFeature.previousComparisonWindow(today: today, calendar: utcCalendar)
        #expect(window.start == Date(timeIntervalSince1970: 1_769_904_000))
        #expect(window.end == Date(timeIntervalSince1970: 1_771_200_000))
    }

    @Test("clamps to previous month length so windows never overlap")
    func clampsToPreviousMonthLength() {
        // 2026-03-31 → February has 28 days → window Feb 1 .. Mar 1.
        let today = Date(timeIntervalSince1970: 1_774_958_400)
        let window = MonthlyReviewFeature.previousComparisonWindow(today: today, calendar: utcCalendar)
        #expect(window.start == Date(timeIntervalSince1970: 1_769_904_000))
        #expect(window.end == Date(timeIntervalSince1970: 1_772_323_200))
    }

    @Test("first of month compares a single day")
    func firstOfMonthComparesSingleDay() {
        // 2026-04-01 → window Mar 1 .. Mar 2.
        let today = Date(timeIntervalSince1970: 1_775_044_800)
        let window = MonthlyReviewFeature.previousComparisonWindow(today: today, calendar: utcCalendar)
        #expect(window.start == Date(timeIntervalSince1970: 1_772_323_200))
        #expect(window.end == Date(timeIntervalSince1970: 1_772_409_600))
    }
}
