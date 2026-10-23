// FocusToggleCommandTests.swift
// Pepinillo — Deep Work Companion for Apple

import Testing
@testable import Pepinillo

@Suite("FocusToggleCommand")
struct FocusToggleCommandTests {
    @Test func idleStartsFocus() {
        let focus = FocusFeature.State()
        #expect(FocusToggleCommand.decision(for: focus) == .start)
    }

    @Test func runningPausesFocus() {
        var focus = FocusFeature.State()
        focus.isRunning = true
        #expect(FocusToggleCommand.decision(for: focus) == .pause)
    }

    @Test func pausedResumesFocus() {
        var focus = FocusFeature.State()
        focus.isRunning = true
        focus.isPaused = true
        #expect(FocusToggleCommand.decision(for: focus) == .resume)
    }

    @Test func waitingForNextPhaseAdvances() {
        var focus = FocusFeature.State()
        focus.isRunning = true
        focus.isWaitingForNextPhase = true
        focus.pendingNextPhase = .shortBreak
        #expect(FocusToggleCommand.decision(for: focus) == .nextPhase)
    }
}
