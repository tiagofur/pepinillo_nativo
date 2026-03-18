// FocusModeStrategyTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for all 4 focus mode strategies.
// Validates mode-specific behavior without any UI or TCA dependencies.

import Testing
import Foundation
@testable import Pepinillo

// MARK: - Pomodoro Strategy Tests

struct PomodoroStrategyTests {
    let strategy = PomodoroStrategy()
    let config = FocusConfig.default

    @Test func hasCorrectModeProperties() {
        #expect(strategy.mode == .pomodoro)
        #expect(strategy.direction == .countDown)
        #expect(strategy.hasTarget == true)
        #expect(strategy.supportsAutoAdvance == true)
    }

    @Test func initialPhaseIsWork() {
        let phase = strategy.initialPhase(config: config)
        if case .work(let number, let total) = phase {
            #expect(number == 1)  // Starts at work 1
            #expect(total == 4)   // Default 4 pomodoros per cycle
        } else {
            Issue.record("Expected .work phase, got \(phase)")
        }
    }

    @Test func targetDurationMatchesConfig() {
        let workDuration = strategy.targetDuration(config: config, phase: .work(number: 1, total: 4))
        #expect(workDuration == TimeInterval(25 * 60))  // 25 minutes

        let shortBreak = strategy.targetDuration(config: config, phase: .shortBreak)
        #expect(shortBreak == TimeInterval(5 * 60))  // 5 minutes

        let longBreak = strategy.targetDuration(config: config, phase: .longBreak)
        #expect(longBreak == TimeInterval(15 * 60))  // 15 minutes
    }

    @Test func workTransitionsToShortBreakBeforeFinalPomodoro() {
        let next = strategy.nextPhase(after: .work(number: 2, total: 4), elapsed: 1500, config: config)
        #expect(next == .shortBreak)
    }

    @Test func finalWorkTransitionsToLongBreak() {
        let next = strategy.nextPhase(after: .work(number: 4, total: 4), elapsed: 1500, config: config)
        #expect(next == .longBreak)
    }

    @Test func longBreakEndsSession() {
        let next = strategy.nextPhase(after: .longBreak, elapsed: 900, config: config)
        #expect(next == nil)  // Session complete
    }

    @Test func shortBreakTransitionsToWork() {
        let next = strategy.nextPhase(after: .shortBreak, elapsed: 300, config: config)
        if case .work(_, let total) = next {
            #expect(total == 4)
        } else {
            Issue.record("Expected .work phase after short break")
        }
    }

    @Test func customConfigIsRespected() {
        var custom = FocusConfig.default
        custom.pomodoroDuration = 50 * 60
        custom.shortBreakDuration = 10 * 60
        custom.pomodorosPerCycle = 2

        let workDuration = strategy.targetDuration(config: custom, phase: .work(number: 1, total: 2))
        #expect(workDuration == TimeInterval(50 * 60))

        let breakDuration = strategy.targetDuration(config: custom, phase: .shortBreak)
        #expect(breakDuration == TimeInterval(10 * 60))
    }
}

// MARK: - Flowtime Strategy Tests

struct FlowtimeStrategyTests {
    let strategy = FlowtimeStrategy()
    let config = FocusConfig.default

    @Test func hasCorrectModeProperties() {
        #expect(strategy.mode == .flowtime)
        #expect(strategy.direction == .countUp)
        #expect(strategy.hasTarget == false)
        #expect(strategy.supportsAutoAdvance == false)
    }

    @Test func initialPhaseIsFlow() {
        let phase = strategy.initialPhase(config: config)
        #expect(phase == .flow)
    }

    @Test func flowHasNoTarget() {
        let target = strategy.targetDuration(config: config, phase: .flow)
        #expect(target == nil)
    }

    @Test func breakDurationScalesWithFocusTime() {
        // < 25 min → 5 min break
        #expect(strategy.suggestedBreakDuration(afterFocusing: 10 * 60) == 5 * 60)
        #expect(strategy.suggestedBreakDuration(afterFocusing: 24 * 60) == 5 * 60)

        // < 50 min → 8 min break
        #expect(strategy.suggestedBreakDuration(afterFocusing: 30 * 60) == 8 * 60)
        #expect(strategy.suggestedBreakDuration(afterFocusing: 49 * 60) == 8 * 60)

        // < 90 min → 10 min break
        #expect(strategy.suggestedBreakDuration(afterFocusing: 60 * 60) == 10 * 60)
        #expect(strategy.suggestedBreakDuration(afterFocusing: 89 * 60) == 10 * 60)

        // >= 90 min → 15 min break
        #expect(strategy.suggestedBreakDuration(afterFocusing: 90 * 60) == 15 * 60)
        #expect(strategy.suggestedBreakDuration(afterFocusing: 120 * 60) == 15 * 60)
    }

    @Test func flowTransitionsToBreakThenBack() {
        // Flow → Break (with calculated duration)
        let afterFlow = strategy.nextPhase(after: .flow, elapsed: 30 * 60, config: config)
        if case .flowBreak(let duration) = afterFlow {
            #expect(duration == 8 * 60)  // 30 min focus → 8 min break
        } else {
            Issue.record("Expected .flowBreak after flow")
        }

        // Break → Flow
        let afterBreak = strategy.nextPhase(after: .flowBreak(suggestedDuration: 480), elapsed: 480, config: config)
        #expect(afterBreak == .flow)
    }
}

// MARK: - Time Block Strategy Tests

struct TimeBlockStrategyTests {
    let strategy = TimeBlockStrategy()
    let config = FocusConfig.default

    @Test func hasCorrectModeProperties() {
        #expect(strategy.mode == .timeBlock)
        #expect(strategy.direction == .countDown)
        #expect(strategy.hasTarget == true)
        #expect(strategy.supportsAutoAdvance == false)
    }

    @Test func initialPhaseIsBlock() {
        let phase = strategy.initialPhase(config: config)
        #expect(phase == .block)
    }

    @Test func targetDurationIsConfigurable() {
        var custom = FocusConfig.default
        custom.defaultBlockDuration = 2 * 3600  // 2 hours

        let target = strategy.targetDuration(config: custom, phase: .block)
        #expect(target == TimeInterval(2 * 3600))
    }

    @Test func blockHasNoNextPhase() {
        let next = strategy.nextPhase(after: .block, elapsed: 3600, config: config)
        #expect(next == nil)  // Session ends when block completes
    }

    @Test func breakSuggestionIsTenPercentOfFocusTime() {
        // 60 min focus → 6 min break (clamped to 5-15)
        let shortBreak = strategy.suggestedBreakDuration(afterFocusing: 60 * 60)
        #expect(shortBreak == 6 * 60)

        // 10 min focus → 5 min break (minimum)
        let minBreak = strategy.suggestedBreakDuration(afterFocusing: 10 * 60)
        #expect(minBreak == 5 * 60)

        // 3 hour focus → 15 min break (maximum)
        let maxBreak = strategy.suggestedBreakDuration(afterFocusing: 3 * 3600)
        #expect(maxBreak == 15 * 60)
    }
}

// MARK: - Stopwatch Strategy Tests

struct StopwatchStrategyTests {
    let strategy = StopwatchStrategy()
    let config = FocusConfig.default

    @Test func hasCorrectModeProperties() {
        #expect(strategy.mode == .stopwatch)
        #expect(strategy.direction == .countUp)
        #expect(strategy.hasTarget == false)
        #expect(strategy.supportsAutoAdvance == false)
    }

    @Test func initialPhaseIsFreeform() {
        let phase = strategy.initialPhase(config: config)
        #expect(phase == .freeform)
    }

    @Test func hasNoTarget() {
        let target = strategy.targetDuration(config: config, phase: .freeform)
        #expect(target == nil)
    }

    @Test func hasNoNextPhase() {
        let next = strategy.nextPhase(after: .freeform, elapsed: 7200, config: config)
        #expect(next == nil)
    }
}

// MARK: - Cross-Mode Tests

struct FocusModeFactoryTests {
    @Test func allModesReturnCorrectStrategy() {
        #expect(FocusMode.pomodoro.strategy.mode == .pomodoro)
        #expect(FocusMode.flowtime.strategy.mode == .flowtime)
        #expect(FocusMode.timeBlock.strategy.mode == .timeBlock)
        #expect(FocusMode.stopwatch.strategy.mode == .stopwatch)
    }

    @Test func freeTierModesAreCorrect() {
        #expect(FocusMode.pomodoro.isFreeTier == true)
        #expect(FocusMode.stopwatch.isFreeTier == true)
        #expect(FocusMode.flowtime.isFreeTier == false)
        #expect(FocusMode.timeBlock.isFreeTier == false)
    }

    @Test func timerDirectionsAreConsistent() {
        for mode in FocusMode.allCases {
            let strategy = mode.strategy
            #expect(mode.direction == strategy.direction)
        }
    }
}
