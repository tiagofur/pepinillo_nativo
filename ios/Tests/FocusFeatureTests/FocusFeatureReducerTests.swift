// FocusFeatureReducerTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA reducer tests for the FocusFeature.
// Tests state transitions for all 4 modes.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("FocusFeatureReducer", .serialized, .appGroupDefaultsSerialized)
@MainActor
struct FocusFeatureReducerTests {

    // MARK: - Mode Selection

    @Test func selectingModeUpdatesState() async {
        var state = FocusFeature.State()
        state.isProUser = true

        let store = TestStore(initialState: state) {
            FocusFeature()
        }

        await store.send(.modeSelected(.flowtime)) {
            $0.selectedMode = .flowtime
            $0.modeIcon = "🌊"
            $0.displayTime = "0:00"
            $0.remainingSeconds = nil
            $0.phase = .flow
            $0.phaseLabel = FocusPhase.idle.displayName
        }
    }

    @Test func selectingProModeWithoutSubscriptionShowsPaywall() async {
        var state = FocusFeature.State()
        state.isProUser = false

        let store = TestStore(initialState: state) {
            FocusFeature()
        }

        // Flowtime is pro-only — mode must not change but paywall must be shown
        await store.send(.modeSelected(.flowtime)) {
            $0.showPaywall = true
            // selectedMode stays .pomodoro (unchanged)
        }
    }

    @Test func selectingProModeWithSubscriptionWorks() async {
        var state = FocusFeature.State()
        state.isProUser = true

        let store = TestStore(initialState: state) {
            FocusFeature()
        }

        await store.send(.modeSelected(.flowtime)) {
            $0.selectedMode = .flowtime
            $0.modeIcon = "🌊"
            $0.displayTime = "0:00"
            $0.remainingSeconds = nil
            $0.phase = .flow
            $0.phaseLabel = FocusPhase.idle.displayName
        }
    }

    // MARK: - Starting Sessions

    @Test func startPomodoroSetsCorrectState() async {
        let store = TestStore(
            initialState: FocusFeature.State(selectedMode: .pomodoro)
        ) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.notificationClient.requestAuthorization = { false }
        }

        store.exhaustivity = .off

        await store.send(.startTapped()) {
            $0.isRunning = true
            $0.isPaused = false
            $0.activeMode = .pomodoro
            $0.phase = .work(number: 1, total: 4)
            $0.pomodoroNumber = 1
            $0.remainingSeconds = 25 * 60
            $0.progress = 0.0
            $0.elapsedSeconds = 0
            $0.displayTime = "25:00"
            $0.phaseLabel = FocusPhase.work(number: 1, total: 4).displayName
        }
    }

    @Test func startFlowtimeSetsOpenEndedState() async {
        var state = FocusFeature.State()
        state.selectedMode = .flowtime
        state.isProUser = true

        let store = TestStore(initialState: state) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.notificationClient.requestAuthorization = { false }
        }

        store.exhaustivity = .off

        await store.send(.startTapped()) {
            $0.isRunning = true
            $0.isPaused = false
            $0.activeMode = .flowtime
            $0.phase = .flow
            $0.remainingSeconds = nil
            $0.progress = nil
            $0.elapsedSeconds = 0
            $0.displayTime = "0:00"
            $0.phaseLabel = FocusPhase.flow.displayName
        }
    }

    @Test func startTimeBlockUsesCustomDuration() async {
        var state = FocusFeature.State()
        state.selectedMode = .timeBlock
        state.customDurationMinutes = 90
        state.isProUser = true
        state.config.defaultBlockDuration = 90 * 60

        let store = TestStore(initialState: state) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.start = { _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.notificationClient.requestAuthorization = { false }
        }

        store.exhaustivity = .off

        await store.send(.startTapped()) {
            $0.isRunning = true
            $0.activeMode = .timeBlock
            $0.phase = .block
            $0.remainingSeconds = 90 * 60
            $0.progress = 0.0
            $0.displayTime = "90:00"
            $0.isPaused = false
            $0.elapsedSeconds = 0
            $0.phaseLabel = FocusPhase.block.displayName
        }
    }

    // MARK: - Pause / Resume

    @Test func pauseAndResume() async {
        var state = FocusFeature.State()
        state.isRunning = true
        state.activeMode = .pomodoro
        state.phase = .work(number: 1, total: 4)

        let store = TestStore(initialState: state) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.pause = { }
            $0.focusClient.resume = { }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.update = { _, _ in }
        }

        store.exhaustivity = .off

        await store.send(.pauseTapped) {
            $0.isPaused = true
            $0.phaseLabel = FocusPhase.paused.displayName
        }

        await store.send(.resumeTapped) {
            $0.isPaused = false
            // phaseLabel is NOT updated here — the engine's next tick restores the correct phase.
            // This avoids a brief "Paused" flash since state.phase is still .paused from the last tick.
        }
    }

    // MARK: - Stop

    @Test func stopResetsToIdle() async {
        var state = FocusFeature.State()
        state.isRunning = true
        state.activeMode = .flowtime
        state.phase = .flow
        state.elapsedSeconds = 1800

        let store = TestStore(initialState: state) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.stop = { _ in }
            $0.liveActivityClient.end = { _ in }
            $0.soundscapeClient.fadeOut = { }
            $0.notificationClient.clearActiveSession = { }
        }

        store.exhaustivity = .off

        await store.send(.stopTapped) {
            $0.isRunning = false
            $0.isPaused = false
            $0.activeMode = nil
            // resetState calls updateIdleDisplay which sets phase to the
            // initial phase for selectedMode (pomodoro → work(1,4))
            $0.phase = .work(number: 1, total: 4)
            $0.elapsedSeconds = 0
            $0.pomodoroNumber = nil
            $0.progress = nil
            $0.linkedTaskID = nil
            $0.linkedTaskTitle = nil
            $0.displayTime = "25:00"
            $0.remainingSeconds = 25 * 60
            $0.phaseLabel = FocusPhase.idle.displayName
            $0.modeIcon = "🍅"
        }
    }

    // MARK: - Task Linking

    @Test func linkTaskUpdatesState() async {
        let store = TestStore(
            initialState: FocusFeature.State()
        ) {
            FocusFeature()
        } withDependencies: {
            $0.persistenceClient.fetchSessions = { _, _ in [] }
        }

        store.exhaustivity = .off

        let taskID = UUID()
        await store.send(.linkTask(taskID, "Write blog post", "🧠")) {
            $0.linkedTaskID = taskID
            $0.linkedTaskTitle = "Write blog post"
            $0.linkedTaskEmoji = "🧠"
            $0.modeSuggestion = nil
        }
    }

    // MARK: - Custom Duration

    @Test func customDurationIsClamped() async {
        let store = TestStore(
            initialState: FocusFeature.State(selectedMode: .timeBlock)
        ) {
            FocusFeature()
        }

        // Normal value
        await store.send(.customDurationChanged(120)) {
            $0.customDurationMinutes = 120
            $0.config.defaultBlockDuration = 7200
            $0.displayTime = "120:00"
            $0.remainingSeconds = 7200
            $0.phase = .block
            $0.modeIcon = "📦"
            $0.phaseLabel = FocusPhase.idle.displayName
        }

        // Below minimum → clamped to 1
        await store.send(.customDurationChanged(0)) {
            $0.customDurationMinutes = 1
            $0.config.defaultBlockDuration = 60
            $0.displayTime = "1:00"
            $0.remainingSeconds = 60
        }

        // Above maximum → clamped to 480
        await store.send(.customDurationChanged(999)) {
            $0.customDurationMinutes = 480
            $0.config.defaultBlockDuration = 28800
            $0.displayTime = "480:00"
            $0.remainingSeconds = 28800
        }
    }
}
