// PomodoroStrategy.swift
// Pepinillo — Deep Work Companion for Apple
//
// Classic Pomodoro Technique: 25min work → 5min break → repeat → long break after N cycles.
// The most structured of the 4 modes. Ideal for users who need external time pressure.

import Foundation

struct PomodoroStrategy: FocusModeStrategy, Sendable {
    let mode = FocusMode.pomodoro
    let direction = TimerDirection.countDown
    let hasTarget = true
    let supportsAutoAdvance = true

    func initialPhase(config: FocusConfig) -> FocusPhase {
        .work(number: 1, total: config.pomodorosPerCycle)
    }

    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval? {
        switch phase {
        case .work:       return config.pomodoroDuration
        case .shortBreak: return config.shortBreakDuration
        case .longBreak:  return config.longBreakDuration
        default:          return nil
        }
    }

    func nextPhase(
        after phase: FocusPhase,
        elapsed: TimeInterval,
        config: FocusConfig
    ) -> FocusPhase? {
        switch phase {
        case .work(let number, let total):
            if number >= total {
                return .longBreak
            } else {
                return .shortBreak
            }

        case .shortBreak:
            // After a short break, advance to the next work number.
            // We need the current number — extract from context.
            // The engine tracks this; here we return a placeholder that
            // the engine fills with the correct number.
            return .work(number: 0, total: config.pomodorosPerCycle)
            // NOTE: The FocusEngine is responsible for incrementing the
            // pomodoro number. This returns a template that the engine fills.

        case .longBreak:
            // Full cycle complete
            return nil

        default:
            return nil
        }
    }

    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval {
        // Pomodoro has fixed breaks, but if called directly, use short break duration.
        5 * 60  // 5 minutes
    }
}
