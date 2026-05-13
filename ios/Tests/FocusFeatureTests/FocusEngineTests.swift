// FocusEngineTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Direct actor-based tests for the FocusEngine.
// Validates session lifecycle, pause/resume, interruptions, and phase management.
//
// The engine uses a 100ms tick loop. Tests use brief sleeps (200ms)
// to let at least one tick occur where needed.

import Testing
import Foundation
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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.pomodoroNumber == 1)
        #expect(state?.totalPomodoros == 4)
    }

    @Test func nonPomodoroModesHaveNilPomodoroCounts() async throws {
        let engine = FocusEngine()

        for mode in [FocusMode.flowtime, .timeBlock, .stopwatch] {
            await engine.start(mode: mode)
            try await Task.sleep(for: .milliseconds(200))

            let state = await engine.currentState()
            #expect(state?.pomodoroNumber == nil, "Expected nil pomodoroNumber for \(mode)")
            #expect(state?.totalPomodoros == nil, "Expected nil totalPomodoros for \(mode)")
        }
    }

    @Test func startAssignsUniqueSessionID() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))
        let firstID = await engine.currentState()?.id

        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))
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
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        let state = await engine.currentState()

        #expect(state?.isPaused == true)
        #expect(state?.phase == .paused)
        #expect(state?.pausedAt != nil)
    }

    @Test func resumeRestoresWorkPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        let pausedState = await engine.currentState()
        #expect(pausedState?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))
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
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.isPaused == false)
        #expect(state?.phase == .flow)
    }

    @Test func resumeRestoresBlockPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .timeBlock)
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))

        #expect(await engine.currentState()?.phase == .block)
    }

    @Test func resumeRestoresFreeformPhase() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))

        #expect(await engine.currentState()?.phase == .freeform)
    }

    // REGRESSION: Pausing during a break phase and resuming must restore
    // the break phase, not the default work phase.
    @Test func pauseDuringBreakResumesBreakPhase() async throws {
        let engine = FocusEngine()

        // Start Pomodoro and skip to trigger a break phase.
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

        // Skip the work phase to advance to short break
        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(200))

        let preBreakState = await engine.currentState()
        #expect(preBreakState?.phase == .shortBreak,
                "Expected shortBreak after skipping work, got \(String(describing: preBreakState?.phase))")

        // Pause during the break
        await engine.pause()
        #expect(await engine.currentState()?.phase == .paused)

        // Resume — the break phase must be restored, NOT work
        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))

        let resumedState = await engine.currentState()
        #expect(resumedState?.isPaused == false)
        #expect(resumedState?.phase == .shortBreak,
                "Regression: resume during break should restore .shortBreak, got \(String(describing: resumedState?.phase))")
    }

    @Test func pauseWhenAlreadyPausedIsNoOp() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

        // Not paused — resume should be a no-op
        let stateBefore = await engine.currentState()
        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))
        let stateAfter = await engine.currentState()

        #expect(stateBefore?.isPaused == false)
        #expect(stateAfter?.isPaused == false)
    }

    @Test func resumeTracksPausedDuration() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        try await Task.sleep(for: .milliseconds(200))
        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.totalPausedDuration ?? 0 > 0)
    }

    @Test func externalPauseUsesWidgetTapTimestampWhenAppWakesLater() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        #expect(await engine.currentState()?.isPaused == true)

        await engine.stop()
        #expect(await engine.currentState() == nil)
    }
}

// MARK: - Interruptions

@Suite("FocusEngine — Interruptions")
struct FocusEngineInterruptionTests {

    @Test func recordInterruptionIncrementsCount() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))
        let firstState = await engine.currentState()
        #expect(firstState?.mode == .pomodoro)

        // Start a different mode — should cancel the pomodoro
        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(200))
        let secondState = await engine.currentState()

        #expect(secondState?.mode == .flowtime)
        #expect(secondState?.id != firstState?.id)
    }

    @Test func startingNewSessionResetsInterruptions() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

        await engine.recordInterruption()
        await engine.recordInterruption()
        #expect(await engine.currentState()?.interruptions == 2)

        await engine.start(mode: .flowtime)
        try await Task.sleep(for: .milliseconds(200))
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
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.targetDuration == customDuration)
    }

    @Test func customDurationIsIgnoredForNonTimeBlock() async throws {
        let engine = FocusEngine()
        let customDuration: TimeInterval = 45 * 60

        // Custom duration should only apply to timeBlock
        await engine.start(mode: .pomodoro, customDuration: customDuration)
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.linkedTaskID == taskID)
    }

    @Test func linkedTaskIDIsNilByDefault() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.linkedTaskID == nil)
    }

    @Test func linkedTaskIDSurvivesPauseResume() async throws {
        let engine = FocusEngine()
        let taskID = UUID()

        await engine.start(mode: .flowtime, linkedTaskID: taskID)
        try await Task.sleep(for: .milliseconds(200))

        await engine.pause()
        await engine.resume()
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.linkedTaskID == taskID)
    }
}

// MARK: - Timer Ticking

@Suite("FocusEngine — Timer")
struct FocusEngineTimerTests {

    @Test func elapsedTimeIncreasesAfterTick() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .stopwatch)

        // Wait for a few ticks
        try await Task.sleep(for: .milliseconds(300))

        let state = await engine.currentState()
        #expect(state != nil)
        #expect((state?.elapsedSeconds ?? 0) > 0)
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
}

// MARK: - Skip Phase

@Suite("FocusEngine — Skip Phase")
struct FocusEngineSkipPhaseTests {

    @Test func skipWorkPhaseAdvancesToBreak() async throws {
        let engine = FocusEngine()
        await engine.start(mode: .pomodoro)
        try await Task.sleep(for: .milliseconds(200))

        await engine.skipToNextPhase()
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

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
        try await Task.sleep(for: .milliseconds(200))

        let state = await engine.currentState()
        #expect(state?.targetDuration == TimeInterval(25 * 60))
        #expect(state?.totalPomodoros == 4)
    }
}
