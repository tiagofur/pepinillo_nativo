// WatchTimerFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for the WatchTimerFeature.
// Covers: start/pause/resume/stop/skip guards, mode selection,
// session state reception, stats updates, and connectivity changes.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

// MARK: - WatchTimerFeature Tests

@MainActor
@Suite("WatchTimerFeature Reducer")
struct WatchTimerFeatureTests {

    // MARK: - Helpers

    /// A session state representing an active pomodoro session.
    private static func activeSession(
        isPaused: Bool = false,
        modeID: String = "pomodoro",
        displayTime: String = "23:45",
        phaseLabel: String = "Focus 1/4",
        progress: Double? = 0.05,
        pomodoroNumber: Int? = 1,
        linkedTaskTitle: String? = nil,
        linkedTaskID: String? = nil,
        isPhaseTransition: Bool = false,
        sentAt: TimeInterval = Date().timeIntervalSince1970
    ) -> WatchSessionState {
        WatchSessionState(
            isActive: true,
            isPaused: isPaused,
            modeID: modeID,
            displayTime: displayTime,
            phaseLabel: phaseLabel,
            progress: progress,
            pomodoroNumber: pomodoroNumber,
            linkedTaskTitle: linkedTaskTitle,
            linkedTaskID: linkedTaskID,
            isPhaseTransition: isPhaseTransition,
            sentAt: sentAt
        )
    }

    private static let idleSession = WatchSessionState.idle

    // MARK: - onAppear

    @Test("onAppear returns no effect")
    func onAppearReturnsNone() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.onAppear)
    }

    // MARK: - startTapped

    @Test("startTapped sends command when idle")
    func startTappedWhenIdle() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in true }
        }

        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(.commandSent(.startSession(mode: "pomodoro")))
    }

    @Test("startTapped with flowtime sends correct mode")
    func startTappedWithFlowtime() async {
        var state = WatchTimerFeature.State()
        state.selectedMode = .flowtime

        let commandsSent = LockIsolated<[WatchCommand]>([])

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { command in
                commandsSent.withValue { $0.append(command) }
                return true
            }
        }

        store.exhaustivity = .off

        await store.send(.startTapped)
        await store.receive(.commandSent(.startSession(mode: "flowtime")))

        commandsSent.withValue {
            #expect($0.contains(.startSession(mode: "flowtime")))
        }
    }

    @Test("startTapped does nothing when session is already active")
    func startTappedGuardActive() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        // Guard should prevent any effect — no state change, no actions received
        await store.send(.startTapped)
    }

    @Test("startTapped with each mode sends correct rawValue")
    func startTappedAllModes() async {
        for mode in FocusMode.allCases {
            var state = WatchTimerFeature.State()
            state.selectedMode = mode

            let store = TestStore(initialState: state) {
                WatchTimerFeature()
            } withDependencies: {
                $0.watchConnectivityClient.sendCommand = { _ in true }
            }

            store.exhaustivity = .off

            await store.send(.startTapped)
            await store.receive(.commandSent(.startSession(mode: mode.rawValue)))
        }
    }

    // MARK: - pauseResumeTapped

    @Test("pauseResumeTapped sends pause when active and not paused")
    func pauseResumeTappedSendsPause() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true
        state.isPaused = false

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in true }
        }

        store.exhaustivity = .off

        await store.send(.pauseResumeTapped)
        await store.receive(.commandSent(.pauseSession))
    }

    @Test("pauseResumeTapped sends resume when active and paused")
    func pauseResumeTappedSendsResume() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true
        state.isPaused = true

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in true }
        }

        store.exhaustivity = .off

        await store.send(.pauseResumeTapped)
        await store.receive(.commandSent(.resumeSession))
    }

    @Test("pauseResumeTapped does nothing when not active")
    func pauseResumeTappedGuardNotActive() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = false

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        await store.send(.pauseResumeTapped)
    }

    // MARK: - stopTapped

    @Test("stopTapped sends stop command when active")
    func stopTappedWhenActive() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in true }
        }

        store.exhaustivity = .off

        await store.send(.stopTapped)
        await store.receive(.commandSent(.stopSession))
    }

    @Test("stopTapped does nothing when not active")
    func stopTappedGuardNotActive() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.stopTapped)
    }

    // MARK: - skipTapped

    @Test("skipTapped sends skipPhase command when active")
    func skipTappedWhenActive() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in true }
        }

        store.exhaustivity = .off

        await store.send(.skipTapped)
        await store.receive(.commandSent(.skipPhase))
    }

    @Test("skipTapped does nothing when not active")
    func skipTappedGuardNotActive() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.skipTapped)
    }

    // MARK: - modeSelected

    @Test("modeSelected updates mode when idle")
    func modeSelectedWhenIdle() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.modeSelected(.flowtime)) {
            $0.selectedMode = .flowtime
        }

        await store.send(.modeSelected(.timeBlock)) {
            $0.selectedMode = .timeBlock
        }

        await store.send(.modeSelected(.stopwatch)) {
            $0.selectedMode = .stopwatch
        }

        await store.send(.modeSelected(.pomodoro)) {
            $0.selectedMode = .pomodoro
        }
    }

    @Test("modeSelected is ignored when session is active")
    func modeSelectedGuardActive() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true
        state.selectedMode = .pomodoro

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        // Should not change mode
        await store.send(.modeSelected(.flowtime))
    }

    @Test("modeSelected cycles through all modes when idle")
    func modeSelectedAllModes() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        for mode in FocusMode.allCases {
            if store.state.selectedMode == mode {
                await store.send(.modeSelected(mode))
            } else {
                await store.send(.modeSelected(mode)) {
                    $0.selectedMode = mode
                }
            }
        }
    }

    // MARK: - sessionStateReceived

    @Test("sessionStateReceived updates all fields for active session")
    func sessionStateReceivedActive() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        let session = Self.activeSession(
            displayTime: "22:30",
            phaseLabel: "Focus 2/4",
            progress: 0.10,
            pomodoroNumber: 2,
            linkedTaskTitle: "Write tests",
            linkedTaskID: "ABC-123"
        )

        await store.send(.sessionStateReceived(session)) {
            $0.isSessionActive = true
            $0.isPaused = false
            $0.displayTime = "22:30"
            $0.phaseLabel = "Focus 2/4"
            $0.progress = 0.10
            $0.pomodoroNumber = 2
            $0.linkedTaskTitle = "Write tests"
            $0.linkedTaskID = "ABC-123"
            $0.selectedMode = .pomodoro
        }
    }

    @Test("sessionStateReceived updates mode from modeID")
    func sessionStateReceivedUpdatesMode() async {
        var state = WatchTimerFeature.State()
        state.selectedMode = .pomodoro

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        let session = WatchSessionState(
            isActive: true,
            isPaused: false,
            modeID: "flowtime",
            displayTime: "5:30",
            phaseLabel: "Flow",
            progress: nil,
            pomodoroNumber: nil,
            linkedTaskTitle: nil,
            linkedTaskID: nil,
            isPhaseTransition: false
        )

        await store.send(.sessionStateReceived(session)) {
            $0.isSessionActive = true
            $0.isPaused = false
            $0.selectedMode = .flowtime
            $0.displayTime = "5:30"
            $0.phaseLabel = "Flow"
            $0.progress = nil
            $0.pomodoroNumber = nil
            $0.linkedTaskTitle = nil
            $0.linkedTaskID = nil
        }
    }

    @Test("sessionStateReceived handles paused state")
    func sessionStateReceivedPaused() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        let session = Self.activeSession(isPaused: true, phaseLabel: "Paused")

        await store.send(.sessionStateReceived(session)) {
            $0.isSessionActive = true
            $0.isPaused = true
            $0.phaseLabel = "Paused"
        }
    }

    @Test("sessionStateReceived handles idle session (session ended)")
    func sessionStateReceivedIdle() async {
        var state = WatchTimerFeature.State()
        state.isSessionActive = true
        state.isPaused = false
        state.displayTime = "10:00"

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        await store.send(.sessionStateReceived(Self.idleSession)) {
            $0.isSessionActive = false
            $0.isPaused = false
            $0.displayTime = "25:00"
            $0.phaseLabel = "Ready"
            $0.progress = nil
            $0.pomodoroNumber = nil
            $0.selectedMode = .pomodoro
        }
    }

    @Test("sessionStateReceived ignores unknown modeID gracefully")
    func sessionStateReceivedUnknownMode() async {
        var state = WatchTimerFeature.State()
        state.selectedMode = .pomodoro

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        let session = WatchSessionState(
            isActive: true,
            isPaused: false,
            modeID: "unknownMode",
            displayTime: "10:00",
            phaseLabel: "Mystery",
            progress: nil,
            pomodoroNumber: nil
        )

        // Mode should remain pomodoro since "unknownMode" doesn't match any FocusMode
        await store.send(.sessionStateReceived(session)) {
            $0.isSessionActive = true
            $0.isPaused = false
            $0.displayTime = "10:00"
            $0.phaseLabel = "Mystery"
            $0.progress = nil
            $0.pomodoroNumber = nil
            // selectedMode stays .pomodoro — no valid FocusMode(rawValue:)
        }
    }

    @Test("sessionStateReceived clears optional fields when nil")
    func sessionStateReceivedClearsOptionals() async {
        var state = WatchTimerFeature.State()
        state.progress = 0.5
        state.pomodoroNumber = 3
        state.linkedTaskTitle = "Old task"
        state.linkedTaskID = "OLD-ID"

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        let session = WatchSessionState(
            isActive: true,
            isPaused: false,
            modeID: "flowtime",
            displayTime: "12:00",
            phaseLabel: "Flow",
            progress: nil,
            pomodoroNumber: nil,
            linkedTaskTitle: nil,
            linkedTaskID: nil
        )

        await store.send(.sessionStateReceived(session)) {
            $0.isSessionActive = true
            $0.selectedMode = .flowtime
            $0.displayTime = "12:00"
            $0.phaseLabel = "Flow"
            $0.progress = nil
            $0.pomodoroNumber = nil
            $0.linkedTaskTitle = nil
            $0.linkedTaskID = nil
        }
    }

    @Test("sessionStateReceived with linked task populates task fields")
    func sessionStateReceivedWithLinkedTask() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        let taskID = UUID().uuidString
        let session = Self.activeSession(
            linkedTaskTitle: "Deploy feature",
            linkedTaskID: taskID
        )

        await store.send(.sessionStateReceived(session)) {
            $0.isSessionActive = true
            $0.linkedTaskTitle = "Deploy feature"
            $0.linkedTaskID = taskID
        }
    }

    // MARK: - statsReceived

    @Test("statsReceived updates all stat fields")
    func statsReceivedUpdatesFields() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        await store.send(.statsReceived(todayMinutes: 120, sessions: 5, streak: 7)) {
            $0.todayFocusMinutes = 120
            $0.todaySessionsCompleted = 5
            $0.currentStreakDays = 7
        }
    }

    @Test("statsReceived overwrites previous values")
    func statsReceivedOverwritesPrevious() async {
        var state = WatchTimerFeature.State()
        state.todayFocusMinutes = 60
        state.todaySessionsCompleted = 2
        state.currentStreakDays = 3

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        await store.send(.statsReceived(todayMinutes: 90, sessions: 4, streak: 5)) {
            $0.todayFocusMinutes = 90
            $0.todaySessionsCompleted = 4
            $0.currentStreakDays = 5
        }
    }

    @Test("statsReceived handles zero values")
    func statsReceivedZeroValues() async {
        var state = WatchTimerFeature.State()
        state.todayFocusMinutes = 100
        state.todaySessionsCompleted = 10

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        store.exhaustivity = .off

        await store.send(.statsReceived(todayMinutes: 0, sessions: 0, streak: 0)) {
            $0.todayFocusMinutes = 0
            $0.todaySessionsCompleted = 0
            $0.currentStreakDays = 0
        }
    }

    // MARK: - connectivityChanged

    @Test("connectivityChanged updates isConnected to true")
    func connectivityChangedTrue() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.connectivityChanged(true)) {
            $0.isConnected = true
        }
    }

    @Test("connectivityChanged updates isConnected to false")
    func connectivityChangedFalse() async {
        var state = WatchTimerFeature.State()
        state.isConnected = true

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        await store.send(.connectivityChanged(false)) {
            $0.isConnected = false
        }
    }

    @Test("connectivityChanged is idempotent")
    func connectivityChangedIdempotent() async {
        var state = WatchTimerFeature.State()
        state.isConnected = true

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        // Sending same value should not cause state change assertion failure
        await store.send(.connectivityChanged(true))
    }

    // MARK: - commandSent

    @Test("commandSent is a no-op (returns none)")
    func commandSentNoOp() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.commandSent(.pauseSession))
    }

    // MARK: - Initial State

    @Test("default state has correct initial values")
    func defaultState() {
        let state = WatchTimerFeature.State()
        #expect(state.isConnected == false)
        #expect(state.isSessionActive == false)
        #expect(state.isPaused == false)
        #expect(state.selectedMode == .pomodoro)
        #expect(state.displayTime == "25:00")
        #expect(state.phaseLabel == "Ready")
        #expect(state.progress == nil)
        #expect(state.pomodoroNumber == nil)
        #expect(state.linkedTaskTitle == nil)
        #expect(state.linkedTaskID == nil)
        #expect(state.todayFocusMinutes == 0)
        #expect(state.todaySessionsCompleted == 0)
        #expect(state.currentStreakDays == 0)
    }

    // MARK: - Full Session Lifecycle

    @Test("full lifecycle: start, receive active state, pause, resume, stop")
    func fullSessionLifecycle() async {
        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in true }
        }

        store.exhaustivity = .off

        // 1. Start session
        await store.send(.startTapped)
        await store.receive(.commandSent(.startSession(mode: "pomodoro")))

        // 2. Receive active state from phone
        let activeState = Self.activeSession(displayTime: "24:50", progress: 0.007, sentAt: 100)
        await store.send(.sessionStateReceived(activeState)) {
            $0.lastAppliedSentAt = 100
            $0.hadActiveSession = true
            $0.isSessionActive = true
            $0.isPaused = false
            $0.displayTime = "24:50"
            $0.progress = 0.007
            $0.pomodoroNumber = 1
            $0.selectedMode = .pomodoro
            $0.phaseLabel = "Focus 1/4"
        }

        // 3. Pause
        await store.send(.pauseResumeTapped)
        await store.receive(.commandSent(.pauseSession))

        // 4. Receive paused state
        let pausedState = Self.activeSession(isPaused: true, displayTime: "24:50", phaseLabel: "Paused", progress: 0.007, sentAt: 200)
        await store.send(.sessionStateReceived(pausedState)) {
            $0.lastAppliedSentAt = 200
            $0.isPaused = true
            $0.phaseLabel = "Paused"
        }

        // 5. Resume
        await store.send(.pauseResumeTapped)
        await store.receive(.commandSent(.resumeSession))

        // 6. Stop
        await store.send(.stopTapped)
        await store.receive(.commandSent(.stopSession))

        // 7. Receive idle state
        var idle = Self.idleSession
        idle.sentAt = 300
        await store.send(.sessionStateReceived(idle)) {
            $0.isSessionActive = false
            $0.isPaused = false
            $0.displayTime = "25:00"
            $0.phaseLabel = "Ready"
            $0.progress = nil
            $0.pomodoroNumber = nil
            $0.lastAppliedSentAt = 300
            $0.hadActiveSession = false
        }
    }

    @Test("startTapped blocks Pro mode for free users (#235)")
    func startTappedBlocksProModeForFreeUser() async {
        var state = WatchTimerFeature.State()
        state.selectedMode = .flowtime
        state.isProUser = false

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        } withDependencies: {
            $0.watchConnectivityClient.sendCommand = { _ in
                Issue.record("sendCommand should not be called for locked Pro mode")
                return true
            }
        }

        await store.send(.startTapped)
    }

    @Test("modeSelected ignores Pro mode for free users (#235)")
    func modeSelectedIgnoresProModeForFreeUser() async {
        var state = WatchTimerFeature.State()
        state.selectedMode = .pomodoro
        state.isProUser = false

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        await store.send(.modeSelected(.flowtime))
        #expect(store.state.selectedMode == .pomodoro)
    }

    @Test("onAppear loads isProUser from app group (#235)")
    func onAppearLoadsIsProUser() async {
        let saved = AppGroupDefaults.isProUser
        defer { AppGroupDefaults.isProUser = saved }
        AppGroupDefaults.isProUser = true

        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }

        await store.send(.onAppear) {
            $0.isProUser = true
        }
    }

    @Test("sessionStateReceived ignores stale sentAt updates (#240)")
    func sessionStateReceivedIgnoresStaleSentAt() async {
        var state = WatchTimerFeature.State()
        state.lastAppliedSentAt = 500
        state.displayTime = "10:00"

        let store = TestStore(initialState: state) {
            WatchTimerFeature()
        }

        var stale = Self.activeSession(displayTime: "99:99", sentAt: 400)
        await store.send(.sessionStateReceived(stale))
        #expect(store.state.displayTime == "10:00")
        #expect(store.state.lastAppliedSentAt == 500)
    }

    @Test("session sync persists pause state for complications")
    func sessionStateSyncPersistsPause() async {
        // persistSessionState writes raw group defaults: save + restore them.
        let suite = UserDefaults(suiteName: "group.com.pepinillo.app")
        let keys = [
            WatchStatsKeys.isSessionActive, WatchStatsKeys.displayTime,
            WatchStatsKeys.modeEmoji, WatchStatsKeys.linkedTaskTitle,
            WatchStatsKeys.phaseName, WatchStatsKeys.progress,
            WatchStatsKeys.pomodoroNumber, WatchStatsKeys.phaseStartDate,
            WatchStatsKeys.phaseEndDate, WatchStatsKeys.isPaused,
        ]
        let saved: [String: Any?] = Dictionary(
            uniqueKeysWithValues: keys.map { ($0, suite?.object(forKey: $0)) }
        )
        defer {
            for (key, value) in saved {
                if let value { suite?.set(value, forKey: key) }
                else { suite?.removeObject(forKey: key) }
            }
        }
        suite?.removeObject(forKey: WatchStatsKeys.isPaused)

        let store = TestStore(initialState: WatchTimerFeature.State()) {
            WatchTimerFeature()
        }
        store.exhaustivity = .off

        let paused = WatchSessionState(
            isActive: true,
            isPaused: true,
            modeID: "pomodoro",
            displayTime: "20:00",
            phaseLabel: "Focus"
        )
        await store.send(.sessionStateReceived(paused))

        // S6 RED pre-fix: pause never reaches the complication data.
        #expect(suite?.bool(forKey: WatchStatsKeys.isPaused) == true)
    }
}
