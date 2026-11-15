// WatchSessionPushTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// #785 (watch desync with autoStart): the 1 Hz watch push throttled on
// elapsedSeconds, which resets to 0 at every phase/session boundary —
// after a boundary the throttle stayed silent for the PREVIOUS phase's
// full duration; and phase changes never published applicationContext,
// so a momentarily unreachable watch missed auto-started breaks entirely.

import Testing
import ComposableArchitecture
import Foundation
@testable import Pepinillo

@MainActor
@Suite
struct WatchSessionPushTests {

    private func makeSession(
        phase: FocusPhase,
        elapsed: TimeInterval,
        remaining: TimeInterval?
    ) -> FocusSessionState {
        FocusSessionState(
            id: UUID(),
            mode: .pomodoro,
            phase: phase,
            startedAt: .now,
            elapsedSeconds: elapsed,
            targetDuration: 25 * 60,
            remainingSeconds: remaining,
            progress: 0.5,
            pomodoroNumber: 1,
            totalPomodoros: 4
        )
    }

    @Test("tick after a phase boundary pushes despite the elapsed wrap")
    func phaseBoundaryTickPushes() async {
        let pushes = LockIsolated<[(isActive: Bool, publishContext: Bool)]>([])
        var state = AppFeature.State()
        // End of a 25-min work phase already pushed; the break restarts at 0.
        state.lastWatchSentElapsed = 1500

        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.watchConnectivityClient.sendSessionState = { s, publish in
                pushes.withValue { $0.append((s.isActive, publish)) }
            }
            $0.notificationClient.scheduleBreakEnd = { _ in }
            $0.notificationClient.requestAuthorization = { true }
        }
        store.exhaustivity = .off

        let breakTick = makeSession(
            phase: .shortBreak, elapsed: 2, remaining: 298
        )
        await store.send(.focus(.timerTicked(breakTick)))

        #expect(pushes.count == 1, "the wrap must not silence the first break ticks")
    }

    @Test("a phase the watch has not seen publishes applicationContext")
    func newPhasePublishesContext() async {
        let pushes = LockIsolated<[(isActive: Bool, publishContext: Bool)]>([])
        var state = AppFeature.State()
        state.lastWatchSentElapsed = 10
        state.lastWatchSentPhase = .work(number: 1, total: 4)

        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.watchConnectivityClient.sendSessionState = { s, publish in
                pushes.withValue { $0.append((s.isActive, publish)) }
            }
            $0.notificationClient.scheduleBreakEnd = { _ in }
            $0.notificationClient.requestAuthorization = { true }
        }
        store.exhaustivity = .off

        // Auto-advanced break tick — the watch must ALSO get it via context.
        let breakTick = makeSession(
            phase: .shortBreak, elapsed: 1, remaining: 299
        )
        await store.send(.focus(.timerTicked(breakTick)))
        #expect(pushes.last?.publishContext == true)

        // Same-phase tick — plain low-latency push only.
        pushes.withValue { $0.removeAll() }
        let nextBreakTick = makeSession(
            phase: .shortBreak, elapsed: 2, remaining: 298
        )
        await store.send(.focus(.timerTicked(nextBreakTick)))
        #expect(pushes.last?.publishContext == false)
    }

    @Test("phone-initiated start pushes a fresh snapshot with context")
    func startTappedPublishesSnapshot() async {
        let pushes = LockIsolated<[(isActive: Bool, publishContext: Bool)]>([])
        let engineSession = makeSession(
            phase: .work(number: 1, total: 4), elapsed: 0, remaining: 25 * 60
        )

        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.watchConnectivityClient.isSupported = { true }
            $0.watchConnectivityClient.sendSessionState = { s, publish in
                pushes.withValue { $0.append((s.isActive, publish)) }
            }
            $0.notificationClient.scheduleBreakEnd = { _ in }
            $0.notificationClient.requestAuthorization = { false }
            $0.soundscapeClient.play = { _, _ in }
            $0.persistenceClient.resolveAchievements = { derived in derived }
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.fetchSessions = { _, _ in [] }
            $0.focusClient.start = { _, _, _, _, _, _, _ in }
            $0.focusClient.events = { AsyncStream { $0.finish() } }
            $0.focusClient.currentState = { nil }
            $0.liveActivityClient.isAvailable = { false }
        }
        store.exhaustivity = .off

        await store.send(.focus(.startTapped()))

        #expect(pushes.withValue { $0.contains { $0.publishContext } })
    }
}
