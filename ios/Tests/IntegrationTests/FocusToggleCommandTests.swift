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

@Suite("MacSessionCommand")
struct MacSessionCommandTests {
    @Test func waitingHoldStartsNextPhase() {
        #expect(
            MacSessionCommand.nextPhaseDecision(isRunning: true, isWaitingForNextPhase: true)
                == .startNextPhase
        )
    }

    @Test func runningSkipsPhase() {
        #expect(
            MacSessionCommand.nextPhaseDecision(isRunning: true, isWaitingForNextPhase: false)
                == .skip
        )
    }

    @Test func idleDoesNothing() {
        #expect(
            MacSessionCommand.nextPhaseDecision(isRunning: false, isWaitingForNextPhase: false)
                == .none
        )
    }

    @Test func stopDecisionGuardsOnRunning() {
        #expect(MacSessionCommand.stopDecision(isRunning: true) == .stop)
        #expect(MacSessionCommand.stopDecision(isRunning: false) == .none)
    }
}
