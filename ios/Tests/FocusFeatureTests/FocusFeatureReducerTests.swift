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
            $0.focusClient.start = { _, _, _, _, _, _, _ in }
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
            $0.focusClient.start = { _, _, _, _, _, _, _ in }
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
            $0.focusClient.start = { _, _, _, _, _, _, _ in }
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

    @Test func startPomodoroPassesCompletedWorkCountToEngine() async {
        let completedSessions = (0..<3).map { _ in
            SessionRecordDTO(
                id: UUID(),
                startedAt: Date.now,
                endedAt: Date.now,
                mode: "pomodoro",
                phase: "work",
                targetDuration: 25 * 60,
                actualDuration: 25 * 60,
                wasCompleted: true,
                interruptions: 0,
                taskID: nil
            )
        }

        let receivedCompletedCount = LockIsolated<Int?>(nil)
        let store = TestStore(
            initialState: FocusFeature.State(selectedMode: .pomodoro)
        ) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.start = { _, _, _, _, _, _, completedCount in
                receivedCompletedCount.setValue(completedCount)
            }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in completedSessions }
            $0.notificationClient.requestAuthorization = { false }
        }

        store.exhaustivity = .off

        await store.send(.startTapped())
        #expect(receivedCompletedCount.value == 3)
    }

    // MARK: - Session Completion / Abandon (issue #170)

    private func makeSessionResult(
        mode: FocusMode,
        phase: FocusPhase,
        wasCompleted: Bool,
        actualDuration: TimeInterval = 600
    ) -> FocusSessionResult {
        FocusSessionResult(
            id: UUID(),
            mode: mode,
            phase: phase,
            startedAt: Date.now.addingTimeInterval(-actualDuration),
            endedAt: Date.now,
            targetDuration: nil,
            actualDuration: actualDuration,
            wasCompleted: wasCompleted,
            interruptions: 0,
            pomodoroNumber: mode == .pomodoro ? 1 : nil,
            linkedTaskID: nil
        )
    }

    @Test func abandonedFlowtimeSessionPersistsWithoutCompleteNotification() async {
        let savedSessions = LockIsolated<[FocusSessionResult]>([])
        let scheduledComplete = LockIsolated(false)
        let loggedMindfulMinutes = LockIsolated(false)
        let liveActivityEndCompleted = LockIsolated<Bool?>(nil)

        let store = TestStore(
            initialState: {
                var state = FocusFeature.State()
                state.isRunning = true
                state.activeMode = .flowtime
                state.phase = .flow
                return state
            }()
        ) {
            FocusFeature()
        } withDependencies: {
            $0.persistenceClient.saveSession = { result in
                savedSessions.withValue { $0.append(result) }
            }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.notificationClient.scheduleSessionComplete = { _, _ in
                scheduledComplete.setValue(true)
            }
            $0.healthClient.isAuthorized = { true }
            $0.healthClient.logMindfulMinutes = { _, _ in
                loggedMindfulMinutes.setValue(true)
            }
            $0.liveActivityClient.end = { completed in
                liveActivityEndCompleted.setValue(completed)
            }
            $0.soundscapeClient.fadeOut = { }
            $0.notificationClient.clearActiveSession = { }
        }

        store.exhaustivity = .off

        let result = makeSessionResult(mode: .flowtime, phase: .flow, wasCompleted: false)
        await store.send(.sessionCompleted(result)) {
            $0.isRunning = false
            $0.activeMode = nil
            $0.elapsedSeconds = 0
            $0.pomodoroNumber = nil
            $0.progress = nil
            $0.linkedTaskID = nil
            $0.linkedTaskTitle = nil
            $0.phase = .work(number: 1, total: 4)
            $0.displayTime = "25:00"
            $0.remainingSeconds = 25 * 60
            $0.phaseLabel = FocusPhase.idle.displayName
            $0.modeIcon = "🍅"
        }

        await store.receive(.delegate(.sessionPersisted))

        #expect(savedSessions.value.count == 1)
        #expect(savedSessions.value.first?.wasCompleted == false)
        #expect(scheduledComplete.value == false)
        #expect(loggedMindfulMinutes.value == false)
        #expect(liveActivityEndCompleted.value == false)
    }

    @Test func completedFlowtimeSessionSchedulesCompleteNotification() async {
        let scheduledComplete = LockIsolated<(String, String?)?>(nil)

        let store = TestStore(initialState: FocusFeature.State()) {
            FocusFeature()
        } withDependencies: {
            $0.persistenceClient.saveSession = { _ in }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.notificationClient.scheduleSessionComplete = { mode, taskTitle in
                scheduledComplete.setValue((mode, taskTitle))
            }
            $0.healthClient.isAuthorized = { false }
            $0.liveActivityClient.end = { _ in }
            $0.soundscapeClient.fadeOut = { }
            $0.notificationClient.clearActiveSession = { }
        }

        store.exhaustivity = .off

        let result = makeSessionResult(mode: .flowtime, phase: .flow, wasCompleted: true)
        await store.send(.sessionCompleted(result))
        await store.receive(.delegate(.sessionPersisted))

        #expect(scheduledComplete.value?.0 == "flowtime")
        #expect(scheduledComplete.value?.1 == nil)
    }

    @Test func stopTappedAllowsSessionCompletedToPersistAbandonedSession() async {
        let savedSessions = LockIsolated<[FocusSessionResult]>([])
        let eventContinuation = LockIsolated<AsyncStream<FocusEngineEvent>.Continuation?>(nil)
        let abandonedResult = makeSessionResult(mode: .flowtime, phase: .flow, wasCompleted: false, actualDuration: 900)

        var state = FocusFeature.State()
        state.selectedMode = .flowtime
        state.isProUser = true

        let store = TestStore(initialState: state) {
            FocusFeature()
        } withDependencies: {
            $0.focusClient.start = { _, _, _, _, _, _, _ in }
            $0.focusClient.stop = { completed in
                #expect(completed == false)
                eventContinuation.value?.yield(.sessionCompleted(abandonedResult))
            }
            $0.focusClient.events = {
                AsyncStream { continuation in
                    eventContinuation.setValue(continuation)
                }
            }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
            $0.soundscapeClient.play = { _, _ in }
            $0.persistenceClient.saveSession = { result in
                savedSessions.withValue { $0.append(result) }
            }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.notificationClient.requestAuthorization = { false }
            $0.liveActivityClient.end = { _ in }
            $0.soundscapeClient.fadeOut = { }
            $0.notificationClient.clearActiveSession = { }
            $0.healthClient.isAuthorized = { false }
        }

        store.exhaustivity = .off

        await store.send(.startTapped()) {
            $0.isRunning = true
            $0.activeMode = .flowtime
            $0.phase = .flow
        }

        await store.send(.stopTapped) {
            $0.isRunning = false
            $0.activeMode = nil
            $0.elapsedSeconds = 0
            $0.pomodoroNumber = nil
            $0.progress = nil
            $0.linkedTaskID = nil
            $0.linkedTaskTitle = nil
            $0.displayTime = "0:00"
            $0.remainingSeconds = nil
            $0.phaseLabel = FocusPhase.idle.displayName
            $0.modeIcon = "🌊"
        }

        await store.receive(.sessionCompleted(abandonedResult))
        await store.receive(.delegate(.sessionPersisted))

        #expect(savedSessions.value.count == 1)
        #expect(savedSessions.value.first?.mode == .flowtime)
        #expect(savedSessions.value.first?.wasCompleted == false)
    }

    @Test func abandonedPomodoroWorkPhasePersistsPartialProgress() async {
        let savedSessions = LockIsolated<[FocusSessionResult]>([])

        let store = TestStore(initialState: FocusFeature.State()) {
            FocusFeature()
        } withDependencies: {
            $0.persistenceClient.saveSession = { result in
                savedSessions.withValue { $0.append(result) }
            }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.notificationClient.scheduleSessionComplete = { _, _ in }
            $0.healthClient.isAuthorized = { false }
            $0.liveActivityClient.end = { _ in }
            $0.soundscapeClient.fadeOut = { }
            $0.notificationClient.clearActiveSession = { }
        }

        store.exhaustivity = .off

        let result = makeSessionResult(
            mode: .pomodoro,
            phase: .work(number: 2, total: 4),
            wasCompleted: false,
            actualDuration: 420
        )
        await store.send(.sessionCompleted(result))
        await store.receive(.delegate(.sessionPersisted))

        #expect(savedSessions.value.count == 1)
        #expect(savedSessions.value.first?.actualDuration == 420)
        #expect(savedSessions.value.first?.wasCompleted == false)
    }

    @Test func completedPomodoroCycleDoesNotDoublePersist() async {
        let savedSessions = LockIsolated<[FocusSessionResult]>([])

        let store = TestStore(initialState: FocusFeature.State()) {
            FocusFeature()
        } withDependencies: {
            $0.persistenceClient.saveSession = { result in
                savedSessions.withValue { $0.append(result) }
            }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.notificationClient.scheduleSessionComplete = { _, _ in }
            $0.healthClient.isAuthorized = { false }
            $0.liveActivityClient.end = { _ in }
            $0.soundscapeClient.fadeOut = { }
            $0.notificationClient.clearActiveSession = { }
        }

        store.exhaustivity = .off

        let result = makeSessionResult(
            mode: .pomodoro,
            phase: .shortBreak,
            wasCompleted: true
        )
        await store.send(.sessionCompleted(result))

        #expect(savedSessions.value.isEmpty)
    }

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
