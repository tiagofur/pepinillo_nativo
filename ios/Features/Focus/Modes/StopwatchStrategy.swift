// StopwatchStrategy.swift
// Pepinillo — Deep Work Companion for Apple
//
// Stopwatch Mode: Just count up. No goals, no breaks, no pressure.
// Start. Work. Stop whenever you want. Perfect for:
// - Days when you just want to track time without structure
// - Tasks where you don't know how long they'll take
// - Users who are new to focus tracking and want zero friction
//
// This is the simplest strategy — it delegates almost everything to defaults.
// But it's strategically important: it's free-tier and captures casual users
// who might upgrade later when they want Flowtime or Time Block.

import Foundation

struct StopwatchStrategy: FocusModeStrategy, Sendable {
    let mode = FocusMode.stopwatch
    let direction = TimerDirection.countUp
    let hasTarget = false
    let supportsAutoAdvance = false

    func initialPhase(config: FocusConfig) -> FocusPhase {
        .freeform
    }

    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval? {
        // No target — ever.
        nil
    }

    func nextPhase(
        after phase: FocusPhase,
        elapsed: TimeInterval,
        config: FocusConfig
    ) -> FocusPhase? {
        // No next phase — user stops manually.
        nil
    }

    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval {
        // If somehow called, use Flowtime formula as a reasonable default.
        let minutes = elapsed / 60.0
        switch minutes {
        case ..<25:  return 5 * 60
        case ..<50:  return 8 * 60
        case ..<90:  return 10 * 60
        default:     return 15 * 60
        }
    }
}
