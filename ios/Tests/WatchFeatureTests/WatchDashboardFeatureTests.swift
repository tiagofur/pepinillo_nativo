// WatchDashboardFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for the WatchDashboardFeature.
// Covers: onAppear requesting dashboard, stats reception,
// dashboard stats reception with full field mapping.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

// MARK: - WatchDashboardFeature Tests

@MainActor
@Suite("WatchDashboardFeature Reducer")
struct WatchDashboardFeatureTests {

    // MARK: - Helpers

    private static let sampleDashboardStats = WatchDashboardStats(
        todayMinutes: 180,
        sessionsCompleted: 6,
        tasksCompleted: 4,
        tasksTotal: 10,
        streakDays: 14,
        pomodoroMinutes: 100,
        flowtimeMinutes: 50,
        timeBlockMinutes: 20,
        stopwatchMinutes: 10,
        longestSessionMinutes: 45
    )

    // MARK: - onAppear

    @Test("onAppear sends requestDashboard command")
    func onAppearRequestsDashboard() async {
        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
            }
        }

        store.exhaustivity = .off

        await store.send(.onAppear)

        commandsSent.withValue {
            #expect($0 == [.requestDashboard])
        }
    }

    // MARK: - statsReceived

    @Test("statsReceived updates todayFocusMinutes, sessionsCompleted, streakDays")
    func statsReceivedUpdatesFields() async {
        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        }

        await store.send(.statsReceived(todayMinutes: 90, sessions: 3, streak: 5)) {
            $0.todayFocusMinutes = 90
            $0.sessionsCompleted = 3
            $0.streakDays = 5
        }
    }

    @Test("statsReceived overwrites previous values")
    func statsReceivedOverwrites() async {
        var state = WatchDashboardFeature.State()
        state.todayFocusMinutes = 60
        state.sessionsCompleted = 2
        state.streakDays = 10

        let store = TestStore(initialState: state) {
            WatchDashboardFeature()
        }

        await store.send(.statsReceived(todayMinutes: 120, sessions: 5, streak: 12)) {
            $0.todayFocusMinutes = 120
            $0.sessionsCompleted = 5
            $0.streakDays = 12
        }
    }

    @Test("statsReceived with zero values resets fields")
    func statsReceivedZero() async {
        var state = WatchDashboardFeature.State()
        state.todayFocusMinutes = 100
        state.sessionsCompleted = 8
        state.streakDays = 5

        let store = TestStore(initialState: state) {
            WatchDashboardFeature()
        }

        await store.send(.statsReceived(todayMinutes: 0, sessions: 0, streak: 0)) {
            $0.todayFocusMinutes = 0
            $0.sessionsCompleted = 0
            $0.streakDays = 0
        }
    }

    @Test("statsReceived does not affect per-mode breakdowns or task counts")
    func statsReceivedDoesNotAffectBreakdowns() async {
        var state = WatchDashboardFeature.State()
        state.pomodoroMinutes = 50
        state.flowtimeMinutes = 30
        state.tasksCompleted = 3
        state.tasksTotal = 8

        let store = TestStore(initialState: state) {
            WatchDashboardFeature()
        }

        await store.send(.statsReceived(todayMinutes: 200, sessions: 10, streak: 20)) {
            $0.todayFocusMinutes = 200
            $0.sessionsCompleted = 10
            $0.streakDays = 20
            // These should remain unchanged
        }

        #expect(store.state.pomodoroMinutes == 50)
        #expect(store.state.flowtimeMinutes == 30)
        #expect(store.state.tasksCompleted == 3)
        #expect(store.state.tasksTotal == 8)
    }

    // MARK: - dashboardStatsReceived

    @Test("dashboardStatsReceived populates all fields")
    func dashboardStatsReceivedAllFields() async {
        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        }

        await store.send(.dashboardStatsReceived(Self.sampleDashboardStats)) {
            $0.todayFocusMinutes = 180
            $0.sessionsCompleted = 6
            $0.tasksCompleted = 4
            $0.tasksTotal = 10
            $0.streakDays = 14
            $0.pomodoroMinutes = 100
            $0.flowtimeMinutes = 50
            $0.timeBlockMinutes = 20
            $0.stopwatchMinutes = 10
            $0.longestSessionMinutes = 45
        }
    }

    @Test("dashboardStatsReceived overwrites all previous values")
    func dashboardStatsReceivedOverwrites() async {
        var state = WatchDashboardFeature.State()
        state.todayFocusMinutes = 999
        state.sessionsCompleted = 999
        state.tasksCompleted = 999
        state.tasksTotal = 999
        state.streakDays = 999
        state.pomodoroMinutes = 999
        state.flowtimeMinutes = 999
        state.timeBlockMinutes = 999
        state.stopwatchMinutes = 999
        state.longestSessionMinutes = 999

        let store = TestStore(initialState: state) {
            WatchDashboardFeature()
        }

        let freshStats = WatchDashboardStats(
            todayMinutes: 10,
            sessionsCompleted: 1,
            tasksCompleted: 0,
            tasksTotal: 5,
            streakDays: 1,
            pomodoroMinutes: 10,
            flowtimeMinutes: 0,
            timeBlockMinutes: 0,
            stopwatchMinutes: 0,
            longestSessionMinutes: 10
        )

        await store.send(.dashboardStatsReceived(freshStats)) {
            $0.todayFocusMinutes = 10
            $0.sessionsCompleted = 1
            $0.tasksCompleted = 0
            $0.tasksTotal = 5
            $0.streakDays = 1
            $0.pomodoroMinutes = 10
            $0.flowtimeMinutes = 0
            $0.timeBlockMinutes = 0
            $0.stopwatchMinutes = 0
            $0.longestSessionMinutes = 10
        }
    }

    @Test("dashboardStatsReceived with all zeros")
    func dashboardStatsReceivedAllZeros() async {
        var state = WatchDashboardFeature.State()
        state.todayFocusMinutes = 50
        state.pomodoroMinutes = 30

        let store = TestStore(initialState: state) {
            WatchDashboardFeature()
        }

        let zeroStats = WatchDashboardStats(
            todayMinutes: 0,
            sessionsCompleted: 0,
            tasksCompleted: 0,
            tasksTotal: 0,
            streakDays: 0,
            pomodoroMinutes: 0,
            flowtimeMinutes: 0,
            timeBlockMinutes: 0,
            stopwatchMinutes: 0,
            longestSessionMinutes: 0
        )

        await store.send(.dashboardStatsReceived(zeroStats)) {
            $0.todayFocusMinutes = 0
            $0.sessionsCompleted = 0
            $0.tasksCompleted = 0
            $0.tasksTotal = 0
            $0.streakDays = 0
            $0.pomodoroMinutes = 0
            $0.flowtimeMinutes = 0
            $0.timeBlockMinutes = 0
            $0.stopwatchMinutes = 0
            $0.longestSessionMinutes = 0
        }
    }

    @Test("dashboardStatsReceived also updates todayFocusMinutes matching statsReceived")
    func dashboardStatsAndStatsConsistency() async {
        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        }

        // First get basic stats
        await store.send(.statsReceived(todayMinutes: 90, sessions: 3, streak: 5)) {
            $0.todayFocusMinutes = 90
            $0.sessionsCompleted = 3
            $0.streakDays = 5
        }

        // Then get full dashboard (overwrites the same fields)
        await store.send(.dashboardStatsReceived(Self.sampleDashboardStats)) {
            $0.todayFocusMinutes = 180
            $0.sessionsCompleted = 6
            $0.tasksCompleted = 4
            $0.tasksTotal = 10
            $0.streakDays = 14
            $0.pomodoroMinutes = 100
            $0.flowtimeMinutes = 50
            $0.timeBlockMinutes = 20
            $0.stopwatchMinutes = 10
            $0.longestSessionMinutes = 45
        }
    }

    @Test("dashboardStatsReceived with high values")
    func dashboardStatsReceivedHighValues() async {
        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        }

        let highStats = WatchDashboardStats(
            todayMinutes: 1440,       // 24 hours
            sessionsCompleted: 100,
            tasksCompleted: 50,
            tasksTotal: 50,
            streakDays: 365,
            pomodoroMinutes: 600,
            flowtimeMinutes: 400,
            timeBlockMinutes: 300,
            stopwatchMinutes: 140,
            longestSessionMinutes: 240
        )

        await store.send(.dashboardStatsReceived(highStats)) {
            $0.todayFocusMinutes = 1440
            $0.sessionsCompleted = 100
            $0.tasksCompleted = 50
            $0.tasksTotal = 50
            $0.streakDays = 365
            $0.pomodoroMinutes = 600
            $0.flowtimeMinutes = 400
            $0.timeBlockMinutes = 300
            $0.stopwatchMinutes = 140
            $0.longestSessionMinutes = 240
        }
    }

    // MARK: - Initial State

    @Test("default state has all zeros")
    func defaultState() {
        let state = WatchDashboardFeature.State()
        #expect(state.todayFocusMinutes == 0)
        #expect(state.sessionsCompleted == 0)
        #expect(state.tasksCompleted == 0)
        #expect(state.tasksTotal == 0)
        #expect(state.streakDays == 0)
        #expect(state.pomodoroMinutes == 0)
        #expect(state.flowtimeMinutes == 0)
        #expect(state.timeBlockMinutes == 0)
        #expect(state.stopwatchMinutes == 0)
        #expect(state.longestSessionMinutes == 0)
    }

    // MARK: - Ordering / Multiple Updates

    @Test("multiple statsReceived calls keep only latest values")
    func multipleStatsReceived() async {
        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        }

        await store.send(.statsReceived(todayMinutes: 10, sessions: 1, streak: 1)) {
            $0.todayFocusMinutes = 10
            $0.sessionsCompleted = 1
            $0.streakDays = 1
        }

        await store.send(.statsReceived(todayMinutes: 35, sessions: 2, streak: 1)) {
            $0.todayFocusMinutes = 35
            $0.sessionsCompleted = 2
        }

        await store.send(.statsReceived(todayMinutes: 60, sessions: 3, streak: 2)) {
            $0.todayFocusMinutes = 60
            $0.sessionsCompleted = 3
            $0.streakDays = 2
        }
    }

    @Test("statsReceived followed by dashboardStatsReceived updates correctly")
    func statsFollowedByDashboard() async {
        let store = TestStore(initialState: WatchDashboardFeature.State()) {
            WatchDashboardFeature()
        }

        // Partial stats first
        await store.send(.statsReceived(todayMinutes: 45, sessions: 2, streak: 3)) {
            $0.todayFocusMinutes = 45
            $0.sessionsCompleted = 2
            $0.streakDays = 3
        }

        // Full dashboard follows — should overwrite overlapping fields
        let dashStats = WatchDashboardStats(
            todayMinutes: 60,
            sessionsCompleted: 3,
            tasksCompleted: 2,
            tasksTotal: 5,
            streakDays: 3,
            pomodoroMinutes: 40,
            flowtimeMinutes: 20,
            timeBlockMinutes: 0,
            stopwatchMinutes: 0,
            longestSessionMinutes: 25
        )

        await store.send(.dashboardStatsReceived(dashStats)) {
            $0.todayFocusMinutes = 60
            $0.sessionsCompleted = 3
            $0.tasksCompleted = 2
            $0.tasksTotal = 5
            $0.streakDays = 3
            $0.pomodoroMinutes = 40
            $0.flowtimeMinutes = 20
            $0.timeBlockMinutes = 0
            $0.stopwatchMinutes = 0
            $0.longestSessionMinutes = 25
        }
    }
}
