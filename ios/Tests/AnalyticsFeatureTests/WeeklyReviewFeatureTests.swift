// WeeklyReviewFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA TestStore tests for WeeklyReviewFeature: data loading,
// trend calculation, best day, mode distribution, streak display.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("WeeklyReviewFeature")
@MainActor
struct WeeklyReviewFeatureTests {

    // MARK: - Helpers

    private nonisolated func defaultPrefs() -> UserPreferencesDTO {
        UserPreferencesDTO(
            soundEnabled: true,
            hapticEnabled: true,
            defaultMode: "pomodoro",
            themeName: "default"
        )
    }

    private nonisolated func prefsWithStreak(_ days: Int) -> UserPreferencesDTO {
        var prefs = defaultPrefs()
        prefs.currentStreakDays = days
        return prefs
    }

    // MARK: - Default State

    @Test("Default state has zero values and neutral trends")
    func testDefaultState() {
        let state = WeeklyReviewFeature.State()
        #expect(state.isLoading == false)
        #expect(state.currentWeekMinutes == 0)
        #expect(state.currentWeekSessions == 0)
        #expect(state.previousWeekMinutes == 0)
        #expect(state.previousWeekSessions == 0)
        #expect(state.minutesDelta == 0)
        #expect(state.sessionsDelta == 0)
        #expect(state.minutesTrend == .neutral)
        #expect(state.sessionsTrend == .neutral)
        #expect(state.currentWeekDominantMode == nil)
        #expect(state.bestDayName == nil)
        #expect(state.bestDayMinutes == 0)
        #expect(state.dailyBreakdown.isEmpty)
        #expect(state.modeDistribution.isEmpty)
        #expect(state.currentStreakDays == 0)
    }

    // MARK: - onAppear

    @Test("onAppear sets loading and fetches data")
    func testOnAppear() async {
        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { self.defaultPrefs() }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.dataLoaded) {
            $0.isLoading = false
        }
    }

    // MARK: - dataLoaded — Basic Population

    @Test("dataLoaded populates all state fields")
    func testDataLoadedPopulatesState() async {
        let breakdown = [
            WeeklyReviewFeature.State.DayBreakdown(
                id: Date.now,
                dayName: "Monday",
                minutes: 60,
                sessions: 3
            )
        ]
        let distribution = [
            WeeklyReviewFeature.State.ModeMinutes(
                id: "pomodoro",
                mode: .pomodoro,
                minutes: 45
            ),
            WeeklyReviewFeature.State.ModeMinutes(
                id: "flowtime",
                mode: .flowtime,
                minutes: 15
            )
        ]

        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 120,
            currentWeekSessions: 8,
            previousWeekMinutes: 90,
            previousWeekSessions: 6,
            currentWeekDominantMode: .pomodoro,
            bestDayName: "Wednesday",
            bestDayMinutes: 45,
            dailyBreakdown: breakdown,
            modeDistribution: distribution,
            currentStreakDays: 5
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }

        await store.send(.dataLoaded(data)) {
            $0.isLoading = false
            $0.currentWeekMinutes = 120
            $0.currentWeekSessions = 8
            $0.previousWeekMinutes = 90
            $0.previousWeekSessions = 6
            $0.currentWeekDominantMode = .pomodoro
            $0.bestDayName = "Wednesday"
            $0.bestDayMinutes = 45
            $0.dailyBreakdown = breakdown
            $0.modeDistribution = distribution
            $0.currentStreakDays = 5
            $0.minutesDelta = 30        // 120 - 90
            $0.sessionsDelta = 2        // 8 - 6
            $0.minutesTrend = .up
            $0.sessionsTrend = .up
        }
    }

    // MARK: - Trend Calculations

    @Test("Improvement over previous week yields .up trends")
    func testUpTrend() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 200,
            currentWeekSessions: 10,
            previousWeekMinutes: 100,
            previousWeekSessions: 5,
            currentWeekDominantMode: nil,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }

        await store.send(.dataLoaded(data)) {
            $0.isLoading = false
            $0.currentWeekMinutes = 200
            $0.currentWeekSessions = 10
            $0.previousWeekMinutes = 100
            $0.previousWeekSessions = 5
            $0.minutesDelta = 100
            $0.sessionsDelta = 5
            $0.minutesTrend = .up
            $0.sessionsTrend = .up
        }
    }

    @Test("Decline from previous week yields .down trends")
    func testDownTrend() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 50,
            currentWeekSessions: 3,
            previousWeekMinutes: 100,
            previousWeekSessions: 8,
            currentWeekDominantMode: nil,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }

        await store.send(.dataLoaded(data)) {
            $0.isLoading = false
            $0.currentWeekMinutes = 50
            $0.currentWeekSessions = 3
            $0.previousWeekMinutes = 100
            $0.previousWeekSessions = 8
            $0.minutesDelta = -50
            $0.sessionsDelta = -5
            $0.minutesTrend = .down
            $0.sessionsTrend = .down
        }
    }

    @Test("Equal weeks yield .neutral trends")
    func testNeutralTrend() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 60,
            currentWeekSessions: 4,
            previousWeekMinutes: 60,
            previousWeekSessions: 4,
            currentWeekDominantMode: nil,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }

        await store.send(.dataLoaded(data)) {
            $0.isLoading = false
            $0.currentWeekMinutes = 60
            $0.currentWeekSessions = 4
            $0.previousWeekMinutes = 60
            $0.previousWeekSessions = 4
            $0.minutesDelta = 0
            $0.sessionsDelta = 0
            $0.minutesTrend = .neutral
            $0.sessionsTrend = .neutral
        }
    }

    @Test("Mixed trends: minutes up but sessions down")
    func testMixedTrends() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 180,
            currentWeekSessions: 3,
            previousWeekMinutes: 100,
            previousWeekSessions: 8,
            currentWeekDominantMode: .timeBlock,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }

        await store.send(.dataLoaded(data)) {
            $0.isLoading = false
            $0.currentWeekMinutes = 180
            $0.currentWeekSessions = 3
            $0.previousWeekMinutes = 100
            $0.previousWeekSessions = 8
            $0.currentWeekDominantMode = .timeBlock
            $0.minutesDelta = 80
            $0.sessionsDelta = -5
            $0.minutesTrend = .up
            $0.sessionsTrend = .down
        }
    }

    // MARK: - Zero Activity Weeks

    @Test("Both weeks with zero activity yields neutral trends")
    func testBothWeeksEmpty() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 0,
            currentWeekSessions: 0,
            previousWeekMinutes: 0,
            previousWeekSessions: 0,
            currentWeekDominantMode: nil,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }

        await store.send(.dataLoaded(data)) {
            $0.isLoading = false
            $0.minutesDelta = 0
            $0.sessionsDelta = 0
            $0.minutesTrend = .neutral
            $0.sessionsTrend = .neutral
            $0.currentWeekDominantMode = nil
            $0.bestDayName == nil
        }
    }

    // MARK: - Streak

    @Test("dataLoaded sets streak from prefs")
    func testStreakFromData() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 60,
            currentWeekSessions: 4,
            previousWeekMinutes: 0,
            previousWeekSessions: 0,
            currentWeekDominantMode: nil,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 21
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }
        store.exhaustivity = .off

        await store.send(.dataLoaded(data)) {
            $0.currentStreakDays = 21
        }
    }

    // MARK: - Best Day

    @Test("dataLoaded sets best day info")
    func testBestDay() async {
        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 300,
            currentWeekSessions: 12,
            previousWeekMinutes: 0,
            previousWeekSessions: 0,
            currentWeekDominantMode: .pomodoro,
            bestDayName: "Friday",
            bestDayMinutes: 90,
            dailyBreakdown: [],
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }
        store.exhaustivity = .off

        await store.send(.dataLoaded(data)) {
            $0.bestDayName = "Friday"
            $0.bestDayMinutes = 90
        }
    }

    // MARK: - Mode Distribution

    @Test("dataLoaded sets mode distribution")
    func testModeDistribution() async {
        let distribution = [
            WeeklyReviewFeature.State.ModeMinutes(id: "pomodoro", mode: .pomodoro, minutes: 120),
            WeeklyReviewFeature.State.ModeMinutes(id: "flowtime", mode: .flowtime, minutes: 60),
            WeeklyReviewFeature.State.ModeMinutes(id: "timeBlock", mode: .timeBlock, minutes: 30),
        ]

        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 210,
            currentWeekSessions: 10,
            previousWeekMinutes: 0,
            previousWeekSessions: 0,
            currentWeekDominantMode: .pomodoro,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: [],
            modeDistribution: distribution,
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }
        store.exhaustivity = .off

        await store.send(.dataLoaded(data)) {
            $0.modeDistribution = distribution
            $0.currentWeekDominantMode = .pomodoro
        }
    }

    // MARK: - Daily Breakdown

    @Test("dataLoaded sets daily breakdown")
    func testDailyBreakdown() async {
        let today = Calendar.current.startOfDay(for: Date.now)
        let breakdown = (0..<7).map { offset -> WeeklyReviewFeature.State.DayBreakdown in
            let day = Calendar.current.date(byAdding: .day, value: -(6 - offset), to: today)!
            return WeeklyReviewFeature.State.DayBreakdown(
                id: day,
                dayName: "Day\(offset)",
                minutes: offset * 10,
                sessions: offset
            )
        }

        let data = WeeklyReviewFeature.WeeklyData(
            currentWeekMinutes: 210,
            currentWeekSessions: 21,
            previousWeekMinutes: 0,
            previousWeekSessions: 0,
            currentWeekDominantMode: nil,
            bestDayName: nil,
            bestDayMinutes: 0,
            dailyBreakdown: breakdown,
            modeDistribution: [],
            currentStreakDays: 0
        )

        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        }
        store.exhaustivity = .off

        await store.send(.dataLoaded(data)) {
            $0.dailyBreakdown = breakdown
        }

        #expect(store.state.dailyBreakdown.count == 7)
    }

    // MARK: - Dismiss

    @Test("Dismiss does not mutate state")
    func testDismiss() async {
        var state = WeeklyReviewFeature.State()
        state.currentWeekMinutes = 100
        state.currentStreakDays = 5

        let store = TestStore(initialState: state) {
            WeeklyReviewFeature()
        }

        await store.send(.dismiss)
        // No state mutation — handled by parent
    }

    // MARK: - Trend Enum

    @Test("Trend enum equatability")
    func testTrendEquatable() {
        #expect(WeeklyReviewFeature.State.Trend.up == .up)
        #expect(WeeklyReviewFeature.State.Trend.down == .down)
        #expect(WeeklyReviewFeature.State.Trend.neutral == .neutral)
        #expect(WeeklyReviewFeature.State.Trend.up != .down)
        #expect(WeeklyReviewFeature.State.Trend.up != .neutral)
    }

    // MARK: - Full Load Integration

    @Test("onAppear with empty sessions produces zero totals and neutral trends")
    func testOnAppearEmptySessions() async {
        let store = TestStore(initialState: WeeklyReviewFeature.State()) {
            WeeklyReviewFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.persistenceClient.fetchPreferences = { self.defaultPrefs() }
        }
        store.exhaustivity = .off

        await store.send(.onAppear) {
            $0.isLoading = true
        }

        await store.receive(\.dataLoaded) {
            $0.isLoading = false
            $0.currentWeekMinutes = 0
            $0.currentWeekSessions = 0
            $0.previousWeekMinutes = 0
            $0.previousWeekSessions = 0
            $0.minutesDelta = 0
            $0.sessionsDelta = 0
            $0.minutesTrend = .neutral
            $0.sessionsTrend = .neutral
            $0.currentWeekDominantMode = nil
            $0.bestDayMinutes = 0
            $0.dailyBreakdown.count == 7
            $0.modeDistribution.isEmpty
        }
    }
}
