// FocusEngineTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Direct actor-based tests for the FocusEngine.
// Validates session lifecycle, pause/resume, interruptions, and phase management.
//
// The engine uses a 250ms tick loop (4Hz). Tests use brief sleeps (≥250ms)
// to let at least one tick occur where needed.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

// MARK: - Fresh Engine State

@Suite("FocusEngine — Initial State")
struct FocusEngineInitialStateTests {

    @Test func freshEngineHasNilState() async {
        let engine = FocusEngine()
        let state = await engine.currentState()
        #expect(state == nil)
    }

    @Test func freshEngineHasEventStream() async {
        let engine = FocusEngine()
        let events = await engine.events
        #expect(events != nil)
    }
}

// MARK: - Starting Sessions

@Suite("FocusEngine — Start")
struct FocusEngineStartTests {

    @Test func startPomodoroCreatesActiveState() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state != nil)
        #expect(state?.mode == .pomodoro)
        #expect(state?.isPaused == false)

        if case .work(let number, let total) = state?.phase {
            #expect(number == 1)
            #expect(total == 4)
        } else {
            Issue.record("Expected .work(1, 4) phase, got \(String(describing: state?.phase))")
        }
    }

    @Test func startFlowtimeCreatesActiveState() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state != nil)
        #expect(state?.mode == .flowtime)
        #expect(state?.phase == .flow)
        #expect(state?.isPaused == false)
        #expect(state?.targetDuration == nil)
        #expect(state?.progress == nil)
    }

    @Test func startTimeBlockCreatesActiveState() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .timeBlock)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state != nil)
        #expect(state?.mode == .timeBlock)
        #expect(state?.phase == .block)
        #expect(state?.isPaused == false)
        #expect(state?.targetDuration == TimeInterval(60 * 60)) // default 1 hour
    }

    @Test func startStopwatchCreatesActiveState() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state != nil)
        #expect(state?.mode == .stopwatch)
        #expect(state?.phase == .freeform)
        #expect(state?.isPaused == false)
        #expect(state?.targetDuration == nil)
        #expect(state?.progress == nil)
    }

    @Test func startPomodoroSetsPomodoroCounts() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.pomodoroNumber == 1)
        #expect(state?.totalPomodoros == 4)
    }

    @Test func nonPomodoroModesHaveNilPomodoroCounts() async throws {
        let engine = FocusEngine()

        for mode in [FocusMode.flowtime, .timeBlock, .stopwatch] {
            await engine.start(mode: mode)
            try await Task.sleep(for: .milliseconds(300))

            let state = await engine.currentState()
            #expect(state?.pomodoroNumber == nil, "Expected nil pomodoroNumber for \(mode)")
            #expect(state?.totalPomodoros == nil, "Expected nil totalPomodoros for \(mode)")
        }
    }

    @Test func startAssignsUniqueSessionID() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))
        let firstID = await engine.currentState()?.id

        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))
        let secondID = await engine.currentState()?.id

        #expect(firstID != nil)
        #expect(secondID != nil)
        #expect(firstID != secondID)
    }
}

// MARK: - Pause / Resume

@Suite("FocusEngine — Pause and Resume")
struct FocusEnginePauseResumeTests {

    @Test func pauseSetsStateCorrectly() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        let state = await engine.currentState()

        #expect(state?.isPaused == true)
        #expect(state?.phase == .paused)
        #expect(state?.pausedAt != nil)
    }

    @Test func resumeRestoresWorkPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        let pausedState = await engine.currentState()
        #expect(pausedState?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))
        let resumedState = await engine.currentState()

        #expect(resumedState?.isPaused == false)
        #expect(resumedState?.pausedAt == nil)

        // Phase should be restored to work, not stay on .paused
        if case .work(let number, let total) = resumedState?.phase {
            #expect(number == 1)
            #expect(total == 4)
        } else {
            Issue.record("Expected .work phase after resume, got \(String(describing: resumedState?.phase))")
        }
    }

    @Test func resumeRestoresFlowPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.isPaused == false)
        #expect(state?.phase == .flow)
    }

    @Test func resumeRestoresBlockPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .timeBlock)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        #expect(await engine.currentState()?.phase == .block)
    }

    @Test func resumeRestoresFreeformPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        #expect(await engine.currentState()?.phase == .freeform)
    }

    // REGRESSION: Pausing during a break phase and resuming must restore
    // the break phase, not the default work phase.
    @Test func pauseDuringBreakResumesBreakPhase() async throws {
        let engine = FocusEngine()

        // Start Pomodoro and skip to trigger a break phase.
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        // Skip the work phase to advance to short break
        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let preBreakState = await engine.currentState()
        #expect(preBreakState?.phase == .shortBreak,
                "Expected shortBreak after skipping work, got \(String(describing: preBreakState?.phase))")

        // Pause during the break
        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        // Resume — the break phase must be restored, NOT work
        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        let resumedState = await engine.currentState()
        #expect(resumedState?.isPaused == false)
        #expect(resumedState?.phase == .shortBreak,
                "Regression: resume during break should restore .shortBreak, got \(String(describing: resumedState?.phase))")
    }

    @Test func pauseWhenAlreadyPausedIsNoOp() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        let firstPausedAt = await engine.currentState()?.pausedAt

        // Pause again — should not change anything
        await engine.pause()
        let secondPausedAt = await engine.currentState()?.pausedAt

        #expect(firstPausedAt == secondPausedAt)
    }

    @Test func resumeWhenNotPausedIsNoOp() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        // Not paused — resume should be a no-op
        let stateBefore = await engine.currentState()
        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))
        let stateAfter = await engine.currentState()

        #expect(stateBefore?.isPaused == false)
        #expect(stateAfter?.isPaused == false)
    }

    @Test func resumeTracksPausedDuration() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        try await Task.sleep(for: .milliseconds(300))
        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.totalPausedDuration ?? 0 > 0)
    }

    @Test func externalPauseUsesWidgetTapTimestampWhenAppWakesLater() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        let pauseTapState = try #require(await engine.currentState())
        let elapsedAtTap = pauseTapState.elapsedSeconds
        let remainingAtTap = pauseTapState.remainingSeconds
        let pausedAt = Date.now

        // Simulates tapping pause in the widget while the app is suspended,
        // then opening the app later. The pause must apply at pausedAt.
        try await Task.sleep(for: .milliseconds(300))
        await engine.applyExternalPause(
            elapsed: elapsedAtTap,
            remaining: remainingAtTap,
            pausedAt: pausedAt
        )
        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        let resumedState = try #require(await engine.currentState())
        #expect(resumedState.isPaused == false)
        #expect(resumedState.totalPausedDuration >= 0.25)
        #expect(
            resumedState.elapsedSeconds < elapsedAtTap + 0.45,
            "Elapsed time should not include the suspended wait after the widget pause tap"
        )
    }
}

// MARK: - Stop

@Suite("FocusEngine — Stop")
struct FocusEngineStopTests {

    @Test func stopResetsStateToNil() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        #expect(await engine.currentState() != nil)

        await engine.stop()
        let state = await engine.currentState()
        #expect(state == nil)
    }

    @Test func stopWhenNoSessionIsNoOp() async {
        let engine = FocusEngine()
        // Should not crash
        await engine.stop()
        #expect(await engine.currentState() == nil)
    }

    @Test func stopWhilePausedResetsState() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        #expect(await engine.currentState()?.isPaused == true)

        await engine.stop()
        #expect(await engine.currentState() == nil)
    }

    @Test func stopWithCompletedFalseEmitsAbandonedSessionCompleted() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        let result = await withTaskGroup(of: FocusSessionResult?.self) { group in
            group.addTask {
                guard let events = await engine.events else { return nil }
                for await event in events {
                    if case .sessionCompleted(let result) = event {
                        return result
                    }
                }
                return nil
            }
            group.addTask {
                await engine.stop(completed: false)
                return nil
            }

            // Skip the stop-task's immediate nil: the sessionCompleted event
            // arrives via the stream a moment later.
            var found: FocusSessionResult?
            while found == nil, let value = await group.next() {
                found = value
            }
            group.cancelAll()
            return found
        }

        #expect(result?.mode == .flowtime)
        #expect(result?.wasCompleted == false)
        #expect(await engine.currentState() == nil)
    }
}

// MARK: - Interruptions

@Suite("FocusEngine — Interruptions")
struct FocusEngineInterruptionTests {

    @Test func recordInterruptionIncrementsCount() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        #expect(await engine.currentState()?.interruptions == 0)

        await engine.recordInterruption()
        #expect(await engine.currentState()?.interruptions == 1)

        await engine.recordInterruption()
        #expect(await engine.currentState()?.interruptions == 2)

        await engine.recordInterruption()
        #expect(await engine.currentState()?.interruptions == 3)
    }

    @Test func recordInterruptionWithNoSessionIsNoOp() async {
        let engine = FocusEngine()
        // Should not crash
        await engine.recordInterruption()
        #expect(await engine.currentState() == nil)
    }
}

// MARK: - Session Replacement

@Suite("FocusEngine — Session Replacement")
struct FocusEngineSessionReplacementTests {

    @Test func startingNewSessionCancelsPrevious() async throws {
        let engine = FocusEngine()

        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))
        let firstState = await engine.currentState()
        #expect(firstState?.mode == .pomodoro)

        // Start a different mode — should cancel the pomodoro
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))
        let secondState = await engine.currentState()

        #expect(secondState?.mode == .flowtime)
        #expect(secondState?.id != firstState?.id)
    }

    @Test func startingNewSessionResetsInterruptions() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        await engine.recordInterruption()
        await engine.recordInterruption()
        #expect(await engine.currentState()?.interruptions == 2)

        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))
        #expect(await engine.currentState()?.interruptions == 0)
    }
}

// MARK: - Custom Duration

@Suite("FocusEngine — Custom Duration")
struct FocusEngineCustomDurationTests {

    @Test func customDurationForTimeBlock() async throws {
        let engine = FocusEngine()
        let customDuration: TimeInterval = 45 * 60 // 45 minutes

        await engine.start(mode: .timeBlock, customDuration: customDuration)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.targetDuration == customDuration)
    }

    @Test func customDurationIsIgnoredForNonTimeBlock() async throws {
        let engine = FocusEngine()
        let customDuration: TimeInterval = 45 * 60

        // Custom duration should only apply to timeBlock
        await engine.start(mode: .pomodoro, customDuration: customDuration)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        // Pomodoro should use its default 25-minute duration, not the custom one
        #expect(state?.targetDuration == TimeInterval(25 * 60))
    }
}

// MARK: - Linked Task

@Suite("FocusEngine — Linked Task")
struct FocusEngineLinkedTaskTests {

    @Test func linkedTaskIDIsPreserved() async throws {
        let engine = FocusEngine()
        let taskID = UUID()

        await engine.start(mode: .pomodoro, linkedTaskID: taskID)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.linkedTaskID == taskID)
    }

    @Test func linkedTaskIDIsNilByDefault() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.linkedTaskID == nil)
    }

    @Test func linkedTaskIDSurvivesPauseResume() async throws {
        let engine = FocusEngine()
        let taskID = UUID()

        await engine.start(mode: .flowtime, linkedTaskID: taskID)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.linkedTaskID == taskID)
    }
}

// MARK: - Timer Ticking

@Suite("FocusEngine — Timer", .serialized, .appGroupDefaultsSerialized)
struct FocusEngineTimerTests {

    @Test func elapsedTimeIncreasesAfterTick() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)

        let state = try await waitForPositiveElapsed(engine)
        #expect(state != nil)
        #expect((state?.elapsedSeconds ?? 0) > 0)
    }

    @Test func staleExternalPauseCommandDoesNotFreezeNewSession() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.externalCommandID = UUID().uuidString
        AppGroupDefaults.externalCommandIssuedAt = Date(timeIntervalSince1970: 1)
        AppGroupDefaults.activeSessionPausedAt = Date(timeIntervalSince1970: 1)
        AppGroupDefaults.activeSessionElapsed = 0
        AppGroupDefaults.externalPauseRequested = true

        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)

        let state = try await waitForPositiveElapsed(engine)
        #expect(state?.isPaused == false)
        #expect((state?.elapsedSeconds ?? 0) > 0)
        #expect(AppGroupDefaults.externalPauseRequested == false)
    }

    @Test func externalPauseWithCommandTimestampsFreezesSessionInBackground() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        let runningState = try #require(await waitForPositiveElapsed(engine))
        let elapsedAtPause = runningState.elapsedSeconds
        let pauseAt = Date.now

        AppGroupDefaults.isSessionActive = true
        AppGroupDefaults.activeSessionTimerStart = runningState.startedAt
        AppGroupDefaults.requestExternalPause(at: pauseAt)

        var pausedState: FocusSessionState?
        for _ in 0..<40 {
            pausedState = await engine.currentState()
            if pausedState?.isPaused == true { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        let paused = try #require(pausedState)
        #expect(paused.isPaused == true)
        // Frozen at the pause instant, but the live clock advances between the
        // tap and this read: compare with tolerance, never exact.
        #expect(abs(paused.elapsedSeconds - elapsedAtPause) < 0.5)
        #expect(AppGroupDefaults.externalPauseRequested == false)
    }

    @Test func countdownModeHasProgress() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.progress != nil)
        #expect((state?.progress ?? 0) >= 0)
    }

    @Test func countUpModeHasNilProgress() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.progress == nil)
    }

    @Test func pauseStopsElapsedFromGrowing() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        let elapsedAtPause = await engine.currentState()?.elapsedSeconds ?? 0

        try await Task.sleep(for: .milliseconds(300))
        let elapsedAfterWait = await engine.currentState()?.elapsedSeconds ?? 0

        // Elapsed should not have grown while paused
        #expect(elapsedAfterWait == elapsedAtPause)
    }

    private func waitForPositiveElapsed(_ engine: FocusEngine) async throws -> FocusSessionState? {
        var state = await engine.currentState()
        for _ in 0..<40 {
            if (state?.elapsedSeconds ?? 0) > 0 {
                return state
            }
            try await Task.sleep(for: .milliseconds(50))
            state = await engine.currentState()
        }
        return state
    }
}

// MARK: - Skip Phase

@Suite("FocusEngine — Skip Phase")
struct FocusEngineSkipPhaseTests {

    @Test func skipWorkPhaseAdvancesToBreak() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.phase == .shortBreak)
    }

    @Test func skipWithNoSessionIsNoOp() async {
        let engine = FocusEngine()
        // Should not crash
        await engine.skipToNextPhase()
        #expect(await engine.currentState() == nil)
    }
}

// MARK: - FocusConfig Interaction

@Suite("FocusEngine — Config")
struct FocusEngineConfigTests {

    @Test func customPomodoroConfig() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.pomodoroDuration = 50 * 60 // 50 minutes
        config.pomodorosPerCycle = 2

        await engine.start(mode: .pomodoro, config: config)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.targetDuration == TimeInterval(50 * 60))
        #expect(state?.totalPomodoros == 2)

        if case .work(let number, let total) = state?.phase {
            #expect(number == 1)
            #expect(total == 2)
        } else {
            Issue.record("Expected .work(1, 2) with custom config")
        }
    }

    @Test func defaultConfigUsesStandardDurations() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.targetDuration == TimeInterval(25 * 60))
        #expect(state?.totalPomodoros == 4)
    }
}

// MARK: - Flowtime Break Lifecycle

@Suite("FocusEngine — Flowtime Breaks", .serialized)
struct FocusEngineFlowtimeBreakTests {

    @Test func takeBreakAdvancesToFlowBreak() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.phase.isBreak == true)
        if case .flowBreak(let duration) = state?.phase {
            #expect(duration == 5 * 60) // < 25 min focus → 5 min break
        } else {
            Issue.record("Expected .flowBreak after take break, got \(String(describing: state?.phase))")
        }
        // Wall-clock derived: assert within a second, never exact (the test
        // clock keeps running between engine start and this read).
        #expect(abs((state?.targetDuration ?? -1) - 300) < 1.0)
        #expect(abs((state?.remainingSeconds ?? -1) - 300) < 1.0)
        #expect(state?.progress != nil)
    }

    @Test func flowBreakCountsDown() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let initialRemaining = await engine.currentState()?.remainingSeconds
        #expect(abs((initialRemaining ?? -1) - 300) < 1.0)

        try await Task.sleep(for: .milliseconds(300))
        let laterRemaining = await engine.currentState()?.remainingSeconds
        #expect((laterRemaining ?? 0) < (initialRemaining ?? 0))
    }

    @Test func flowBreakCompletesAndReturnsToFlow() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let breakTarget = await engine.currentState()?.targetDuration ?? 0
        await engine.syncExternalState(elapsed: breakTarget, remaining: 0)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.phase == .flow)
        #expect(state?.targetDuration == nil)
        #expect(state?.remainingSeconds == nil)
        #expect(state?.progress == nil)
    }

    @Test func skipFlowBreakReturnsToFlow() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))
        #expect(await engine.currentState()?.phase.isBreak == true)

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.phase == .flow)
    }

    @Test func breakSuggestedUsesConfigThreshold() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.flowtimeMinSessionMinutes = 1
        config.flowtimeShowBreakSuggestion = true

        let startDate = Date.now.addingTimeInterval(-90)
        await engine.start(mode: .flowtime, config: config, timerStart: startDate)

        let suggestedDuration = await firstBreakSuggestion(from: engine, within: .milliseconds(500))
        #expect(abs((suggestedDuration ?? -1) - 300) < 1.0) // 90s focus → 5 min suggested break
    }

    @Test func breakSuggestedRespectsDisabledFlag() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.flowtimeMinSessionMinutes = 1
        config.flowtimeShowBreakSuggestion = false

        let startDate = Date.now.addingTimeInterval(-90)
        await engine.start(mode: .flowtime, config: config, timerStart: startDate)

        let suggestedDuration = await firstBreakSuggestion(from: engine, within: .milliseconds(500))
        #expect(suggestedDuration == nil)
    }

    private func firstBreakSuggestion(from engine: FocusEngine, within timeout: Duration) async -> TimeInterval? {
        await withTaskGroup(of: TimeInterval?.self) { group in
            group.addTask {
                guard let events = await engine.events else { return nil }
                for await event in events {
                    if case .breakSuggested(let duration) = event {
                        return duration
                    }
                }
                return nil
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }

            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    @Test func pauseDuringFlowBreakResumesBreakPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.isPaused == false)
        #expect(state?.phase.isBreak == true)
    }
}

// MARK: - Daily Pomodoro Seed

@Suite("FocusEngine — Daily Pomodoro Seed")
struct FocusEngineDailyPomodoroSeedTests {

    @Test func startWithNoCompletedSessionsUsesPomodoroOne() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro, completedWorkSessionsToday: 0)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.pomodoroNumber == 1)

        if case .work(let number, let total) = state?.phase {
            #expect(number == 1)
            #expect(total == 4)
        } else {
            Issue.record("Expected .work(1, 4), got \(String(describing: state?.phase))")
        }
    }

    @Test func startWithThreeCompletedSessionsUsesPomodoroFour() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro, completedWorkSessionsToday: 3)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.pomodoroNumber == 4)

        if case .work(let number, let total) = state?.phase {
            #expect(number == 4)
            #expect(total == 4)
        } else {
            Issue.record("Expected .work(4, 4), got \(String(describing: state?.phase))")
        }
    }

    @Test func startWrapsCompletedSessionsAtCycleBoundary() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro, completedWorkSessionsToday: 4)
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.pomodoroNumber == 1)

        if case .work(let number, let total) = state?.phase {
            #expect(number == 1)
            #expect(total == 4)
        } else {
            Issue.record("Expected .work(1, 4) after full cycle, got \(String(describing: state?.phase))")
        }
    }

    @Test func seededFourthPomodoroAdvancesToLongBreak() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro, completedWorkSessionsToday: 3)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.phase == .longBreak,
                "Expected long break after completing seeded pomodoro 4, got \(String(describing: state?.phase))")
    }

    @Test func seededThirdPomodoroAdvancesToShortBreak() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro, completedWorkSessionsToday: 2)
        try await Task.sleep(for: .milliseconds(300))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state?.phase == .shortBreak,
                "Expected short break after completing seeded pomodoro 3, got \(String(describing: state?.phase))")
    }
}

// MARK: - External Timer Anchors (#176)

@Suite("FocusEngine — External Timer Anchors")
struct FocusEngineExternalTimerTests {

    @Test func startUsesTimerEndForRemainingWhenProvided() async throws {
        let engine = FocusEngine()
        let now = Date.now
        let target: TimeInterval = 25 * 60
        let start = now.addingTimeInterval(-300)
        let end = now.addingTimeInterval(target - 300)

        await engine.start(mode: .pomodoro, timerStart: start, timerEnd: end)
        try await Task.sleep(for: .milliseconds(300))

        let state = try #require(await engine.currentState())
        let expectedRemaining = target - 300
        #expect(abs((state.remainingSeconds ?? 0) - expectedRemaining) < 1)
        #expect(abs(state.elapsedSeconds - 300) < 1)
    }
}

// MARK: - Midpoint Check-In (#176)

@Suite("FocusEngine — Midpoint Check-In")
struct FocusEngineMidpointTests {

    @Test func midpointFiresOnceWhenElapsedCrossesHalf() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.blockMidpointCheckIn = true
        config.defaultBlockDuration = 60 * 60
        let blockConfig = config

        // Start first so the listener attaches to the live stream: start()
        // finishes any previous stream, and the first-wins group race can
        // never observe the event. Count via lock; the listener is cancelled
        // after the window (reaped at engine deinit, which ends the stream).
        let start = Date.now.addingTimeInterval(-(30 * 60 + 1))
        await engine.start(mode: .timeBlock, config: blockConfig, timerStart: start)
        let midpointCount = LockIsolated(0)
        let listener = Task {
            guard let events = await engine.events else { return }
            for await event in events {
                if case .midpointReached = event {
                    midpointCount.withValue { $0 += 1 }
                }
            }
        }
        try? await Task.sleep(for: .seconds(2))
        listener.cancel()

        #expect(midpointCount.value == 1)
    }

    @Test func midpointDoesNotFireWhenDisabled() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.blockMidpointCheckIn = false
        let blockConfig = config

        let midpointCount = await withTaskGroup(of: Int.self) { group in
            group.addTask {
                guard let events = await engine.events else { return 0 }
                var count = 0
                for await event in events {
                    if case .midpointReached = event {
                        count += 1
                    }
                }
                return count
            }
            group.addTask {
                let start = Date.now.addingTimeInterval(-(30 * 60 + 1))
                await engine.start(mode: .timeBlock, config: blockConfig, timerStart: start)
                try? await Task.sleep(for: .seconds(2))
                return 0
            }

            let observed = await group.next() ?? 0
            group.cancelAll()
            return observed
        }

        #expect(midpointCount == 0)
    }

    @Test func midpointFiresAfterBackgroundTimeJump() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.blockMidpointCheckIn = true
        config.defaultBlockDuration = 60 * 60

        await engine.start(mode: .timeBlock, config: config)
        try await Task.sleep(for: .milliseconds(300))

        // Same lock-count pattern as above: the first-wins group race can
        // never observe the event. syncExternalState re-anchors the wall
        // clock, so the jump past halfway survives subsequent ticks.
        let midpointCount = LockIsolated(0)
        let listener = Task {
            guard let events = await engine.events else { return }
            for await event in events {
                if case .midpointReached = event {
                    midpointCount.withValue { $0 += 1 }
                }
            }
        }
        await engine.syncExternalState(elapsed: 31 * 60, remaining: 29 * 60)
        try? await Task.sleep(for: .seconds(2))
        listener.cancel()

        #expect(midpointCount.value == 1)
    }
}

// MARK: - Config Updates (#176)

@Suite("FocusEngine — Config Updates")
struct FocusEngineConfigUpdateTests {

    @Test func updateConfigWhilePausedEmitsTick() async throws {
        let engine = FocusEngine()
        var config = FocusConfig.default
        config.pomodoroDuration = 25 * 60

        await engine.start(mode: .pomodoro, config: config)
        try await Task.sleep(for: .milliseconds(300))
        await engine.pause()

        var updatedConfig = FocusConfig.default
        updatedConfig.pomodoroDuration = 30 * 60

        guard let events = await engine.events else {
            Issue.record("Engine event stream missing")
            return
        }

        let expectedDuration = TimeInterval(30 * 60)

        async let configUpdateTick: FocusSessionState? = {
            for await event in events {
                if case .tick(let state) = event,
                   state.targetDuration == expectedDuration,
                   state.isPaused {
                    return state
                }
            }
            return nil
        }()

        await engine.updateConfig(updatedConfig)

        let tick = await configUpdateTick
        let state = await engine.currentState()

        #expect(tick?.targetDuration == expectedDuration)
        #expect(tick?.isPaused == true)
        #expect(state?.targetDuration == expectedDuration)
        #expect(state?.isPaused == true)
    }
}

// MARK: - Session total focus (S1)

@Suite("FocusEngine — Session total focus")
struct FocusEngineSessionTotalTests {

    @Test func stopAfterMultipleFlowPhasesReportsTotalFocusExcludingBreaks() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .flowtime)
        // Simulate 40 min of flow without waiting for the 4Hz tick loop.
        // Back-to-back actor calls complete in microseconds; the first tick
        // fires after 250ms, so no tick can overwrite the seeded elapsed.
        await engine.syncExternalState(elapsed: 2400, remaining: nil)
        // User takes a break: flow → flowBreak. Completed flow time must accumulate.
        await engine.skipToNextPhase()
        #expect(await engine.currentState()?.phase.isBreak == true)
        // Simulate 10 min of break, then return to flow for 10 more min.
        await engine.syncExternalState(elapsed: 600, remaining: nil)
        await engine.skipToNextPhase()  // flowBreak → flow; break time must NOT accumulate.
        #expect(await engine.currentState()?.phase == .flow)
        await engine.syncExternalState(elapsed: 600, remaining: nil)

        let result = await withTaskGroup(of: FocusSessionResult?.self) { group in
            group.addTask {
                guard let events = await engine.events else { return nil }
                for await event in events {
                    if case .sessionCompleted(let result) = event {
                        return result
                    }
                }
                return nil
            }
            group.addTask {
                await engine.stop(completed: false)
                return nil
            }

            // Skip the stop-task's immediate nil: the sessionCompleted event
            // arrives via the stream a moment later.
            var found: FocusSessionResult?
            while found == nil, let value = await group.next() {
                found = value
            }
            group.cancelAll()
            return found
        }

        #expect(result?.mode == .flowtime)
        #expect(result?.wasCompleted == false)
        // 40 min + 10 min of flow counted; the 10 min break excluded.
        let total = result?.totalFocusSeconds ?? -1
        #expect(total >= 3000 && total < 3000 + 60)
    }
}

// MARK: - Widget anchor across pause (S2)

@Suite("FocusEngine — Anchored pause")
struct FocusEngineAnchoredPauseTests {

    @Test func resumePreservesRemainingForWidgetAnchoredSession() async throws {
        // 4s pomodoro adopted from widget anchors, 2s in: 2s elapsed, 2s remaining.
        var config = FocusConfig()
        config.pomodoroDuration = 4
        let engine = FocusEngine()
        let now = Date.now
        await engine.start(
            mode: .pomodoro,
            config: config,
            timerStart: now.addingTimeInterval(-2),
            timerEnd: now.addingTimeInterval(2)
        )

        await engine.pause()
        // A 1s pause must not be subtracted from the phase on resume.
        try await Task.sleep(for: .milliseconds(1000))
        await engine.resume()
        // Let a 4Hz tick recompute remaining from the anchor.
        try await Task.sleep(for: .milliseconds(500))

        let state = await engine.currentState()
        // Buggy: ~0.5s (anchor kept pre-pause end). Fixed: ~1.5s (end shifted by pause).
        let remaining = state?.remainingSeconds ?? -1
        #expect(remaining > 1.0)
        if case .work(let number, _) = state?.phase {
            #expect(number == 1)
        } else {
            Issue.record("Phase completed early; anchored pause stole phase time")
        }
        await engine.stop()
    }
}

// MARK: - Skipped work partial credit (S3)

@Suite("FocusEngine — Skipped work")
struct FocusEngineSkippedWorkTests {

    @Test func skippingPomodoroWorkEmitsPartialCreditAndContinuesSession() async throws {
        let engine = FocusEngine()
        // Seed 10 min into a 25 min work phase via widget-style anchors so the
        // elapsed time is immune to the 4Hz tick loop (Date arithmetic agrees).
        let now = Date.now
        await engine.start(
            mode: .pomodoro,
            timerStart: now.addingTimeInterval(-600),
            timerEnd: now.addingTimeInterval(900)
        )

        let partial = await withTaskGroup(of: FocusSessionResult?.self) { group in
            group.addTask {
                guard let events = await engine.events else { return nil }
                for await event in events {
                    if case .phaseSkipped(let partial) = event {
                        return partial
                    }
                }
                return nil
            }
            group.addTask {
                await engine.skipToNextPhase()
                return nil
            }

            // Skip the stop-task's immediate nil: the partial credit arrives
            // via the event stream a moment later.
            var found: FocusSessionResult?
            while found == nil, let value = await group.next() {
                found = value
            }
            group.cancelAll()
            return found
        }

        #expect(partial?.mode == .pomodoro)
        #expect(partial?.wasCompleted == false)
        if case .work = partial?.phase {
        } else {
            Issue.record("Expected partial credit for the skipped .work phase")
        }
        let credit = partial?.actualDuration ?? -1
        #expect(credit >= 600 && credit < 600 + 120)
        // The session continues into the break instead of tearing down.
        #expect(await engine.currentState() != nil)
        #expect(await engine.currentState()?.phase.isBreak == true)
        await engine.stop()
    }
}

// MARK: - Stop during waiting hold (S4)

@Suite("FocusEngine — Hold stop")
struct FocusEngineHoldStopTests {

    @Test func stopDuringHoldMarksResultAsAlreadyAccounted() async throws {
        // 1s work phases with auto-start OFF: completing work enters the hold.
        var config = FocusConfig()
        config.pomodoroDuration = 1
        config.autoStartBreaks = false
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro, config: config)
        // Let the work phase complete naturally into the waiting hold.
        try await Task.sleep(for: .milliseconds(2000))

        let result = await withTaskGroup(of: FocusSessionResult?.self) { group in
            group.addTask {
                guard let events = await engine.events else { return nil }
                for await event in events {
                    if case .sessionCompleted(let result) = event {
                        return result
                    }
                }
                return nil
            }
            group.addTask {
                await engine.stop(completed: false)
                return nil
            }

            // Skip the stop-task's immediate nil: the sessionCompleted event
            // arrives via the stream a moment later.
            var found: FocusSessionResult?
            while found == nil, let value = await group.next() {
                found = value
            }
            group.cancelAll()
            return found
        }

        // The completed work interval was already persisted via phaseCompleted;
        // the hold-stop result must say so, with the phase folded exactly once.
        #expect(result?.phase == .work(number: 1, total: 4))
        #expect(result?.isHoldStop == true)
        let total = result?.totalFocusSeconds ?? -1
        #expect(total >= 1.0 && total < 2.0)
        #expect(await engine.currentState() == nil)
    }
}

// MARK: - Direct abandon (S7)

@Suite("FocusEngine — Abandon session")
struct FocusEngineAbandonTests {

    @Test func abandonSessionReturnsTerminalResultWithoutEmitting() async throws {
        let engine = FocusEngine()
        // Seed 10 min into a 25 min work phase via widget-style anchors so the
        // elapsed time is immune to the 4Hz tick loop (Date arithmetic agrees).
        let now = Date.now
        await engine.start(
            mode: .pomodoro,
            timerStart: now.addingTimeInterval(-600),
            timerEnd: now.addingTimeInterval(900)
        )

        // The result comes back directly: unlike stop(), nothing is emitted to
        // the stream, so a later start cannot drop it (S7).
        let result = await engine.abandonSession()

        #expect(result?.mode == .pomodoro)
        #expect(result?.wasCompleted == false)
        if case .work = result?.phase {
        } else {
            Issue.record("Expected the abandoned .work phase")
        }
        let credit = result?.actualDuration ?? -1
        #expect(credit >= 600 && credit < 600 + 120)
        #expect(await engine.currentState() == nil)
        // Second take finds nothing (single-take semantics).
        #expect(await engine.abandonSession() == nil)
    }
}

// MARK: - Ghost adoption (Sprint-5 T1)

@Suite("FocusEngine — Ghost adoption")
struct FocusEngineGhostAdoptionTests {

    @Test func adoptPomodoroWorkResumesWithWallClockMath() async throws {
        let engine = FocusEngine()
        // Ghost: pomodoro work #2/4, 25-min target, 20 min remaining.
        await engine.adoptGhostSession(
            mode: .pomodoro,
            phase: .work(number: 2, total: 4),
            elapsed: 300
        )

        let state = await engine.currentState()
        #expect(state?.mode == .pomodoro)
        #expect(state?.phase == .work(number: 2, total: 4))
        #expect(state?.isPaused == false)
        #expect(state?.pomodoroNumber == 2)
        #expect(state?.totalPomodoros == 4)
        // Invariant: remaining + elapsed == target (no tick sleep needed).
        let remaining = state?.remainingSeconds ?? -1
        let elapsed = state?.elapsedSeconds ?? -1
        #expect(abs((remaining + elapsed) - 1500) < 1)
        await engine.stop()
    }

    @Test func adoptFlowRestartsOpenClock() async throws {
        let engine = FocusEngine()
        await engine.adoptGhostSession(mode: .flowtime, phase: .flow, elapsed: 1200)

        let state = await engine.currentState()
        #expect(state?.mode == .flowtime)
        #expect(state?.phase == .flow)
        #expect(state?.targetDuration == nil)
        #expect(state?.remainingSeconds == nil)
        let elapsed = state?.elapsedSeconds ?? -1
        #expect(elapsed >= 1200 && elapsed < 1205)
        await engine.stop()
    }

    @Test func adoptWhileRunningIsNoOp() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        try await Task.sleep(for: .milliseconds(300))

        await engine.adoptGhostSession(mode: .pomodoro, phase: .work(number: 1, total: 4), elapsed: 600)

        // Original session untouched.
        let state = await engine.currentState()
        #expect(state?.mode == .stopwatch)
        await engine.stop()
    }

    @Test func resolveGhostPhaseMatrix() {
        let config = FocusConfig()
        #expect(FocusEngine.resolveGhostPhase(mode: .pomodoro, phaseDuration: 1500, pomodoroNumber: 3, config: config) == .work(number: 3, total: 4))
        #expect(FocusEngine.resolveGhostPhase(mode: .pomodoro, phaseDuration: 300, pomodoroNumber: 1, config: config) == .shortBreak)
        #expect(FocusEngine.resolveGhostPhase(mode: .pomodoro, phaseDuration: 900, pomodoroNumber: 4, config: config) == .longBreak)
        #expect(FocusEngine.resolveGhostPhase(mode: .pomodoro, phaseDuration: 12345, pomodoroNumber: nil, config: config) == .work(number: 1, total: 4))
        #expect(FocusEngine.resolveGhostPhase(mode: .flowtime, phaseDuration: nil, pomodoroNumber: nil, config: config) == .flow)
        #expect(FocusEngine.resolveGhostPhase(mode: .flowtime, phaseDuration: 480, pomodoroNumber: nil, config: config) == .flowBreak(suggestedDuration: 480))
        #expect(FocusEngine.resolveGhostPhase(mode: .timeBlock, phaseDuration: 3600, pomodoroNumber: nil, config: config) == .block)
        #expect(FocusEngine.resolveGhostPhase(mode: .stopwatch, phaseDuration: nil, pomodoroNumber: nil, config: config) == .freeform)
    }
}

// MARK: - Ghost resume eligibility (Sprint-5 T2)

@Suite("FocusEngine — Ghost resume eligibility")
struct FocusEngineGhostResumeTests {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    // Fixed now: 2026-01-15T12:00 UTC.
    private var now: Date { Date(timeIntervalSince1970: 1_774_958_400) }

    @Test func timedGhostWithTimeLeftIsEligible() {
        // Pomodoro started 10 min ago, ends in 15 min: work #1/4, 10 min elapsed.
        let start = now.addingTimeInterval(-600)
        let end = now.addingTimeInterval(900)
        let taskID = UUID()
        let spec = FocusEngine.resolveGhostResume(
            modeName: "pomodoro",
            timerStart: start,
            timerEnd: end,
            elapsedAnchor: 0,
            pomodoroNumber: 1,
            taskID: taskID.uuidString,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == FocusEngine.GhostResumeSpec(
            mode: .pomodoro,
            phase: .work(number: 1, total: 4),
            elapsed: 600,
            remaining: 900,
            linkedTaskID: taskID
        ))
    }

    @Test func expiredEndIsIneligible() {
        let spec = FocusEngine.resolveGhostResume(
            modeName: "pomodoro",
            timerStart: now.addingTimeInterval(-1500),
            timerEnd: now.addingTimeInterval(-60),
            elapsedAnchor: 0,
            pomodoroNumber: 1,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == nil)
    }

    @Test func shortRemainingIsIneligible() {
        let spec = FocusEngine.resolveGhostResume(
            modeName: "pomodoro",
            timerStart: now.addingTimeInterval(-1470),
            timerEnd: now.addingTimeInterval(30),
            elapsedAnchor: 0,
            pomodoroNumber: 1,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == nil)
    }

    @Test func yesterdayStartIsIneligible() {
        let start = now.addingTimeInterval(-86400 - 600)
        let spec = FocusEngine.resolveGhostResume(
            modeName: "pomodoro",
            timerStart: start,
            timerEnd: now.addingTimeInterval(900),
            elapsedAnchor: 0,
            pomodoroNumber: 1,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == nil)
    }

    @Test func unknownModeIsIneligible() {
        let spec = FocusEngine.resolveGhostResume(
            modeName: "sauna",
            timerStart: now.addingTimeInterval(-600),
            timerEnd: now.addingTimeInterval(900),
            elapsedAnchor: 0,
            pomodoroNumber: nil,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == nil)
    }

    @Test func missingStartIsIneligible() {
        let spec = FocusEngine.resolveGhostResume(
            modeName: "pomodoro",
            timerStart: nil,
            timerEnd: now.addingTimeInterval(900),
            elapsedAnchor: 0,
            pomodoroNumber: 1,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == nil)
    }

    @Test func openFlowGhostIsEligibleWithAnchorElapsed() {
        let spec = FocusEngine.resolveGhostResume(
            modeName: "flowtime",
            timerStart: now.addingTimeInterval(-2400),
            timerEnd: nil,
            elapsedAnchor: 2400,
            pomodoroNumber: nil,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == FocusEngine.GhostResumeSpec(
            mode: .flowtime,
            phase: .flow,
            elapsed: 2400,
            remaining: nil,
            linkedTaskID: nil
        ))
    }

    @Test func openEndedNonFlowModeIsIneligible() {
        let spec = FocusEngine.resolveGhostResume(
            modeName: "timeBlock",
            timerStart: now.addingTimeInterval(-600),
            timerEnd: nil,
            elapsedAnchor: 600,
            pomodoroNumber: nil,
            taskID: nil,
            now: now,
            calendar: utcCalendar
        )
        #expect(spec == nil)
    }
}
