// TimeBlockStrategy.swift
// Pepinillo — Deep Work Companion for Apple
//
// Time Block Technique: Set a fixed duration and work until it's done.
// No intermediate breaks, no cycles — one continuous focused block.
//
// Inspired by Cal Newport's "Deep Work" and "Time-Block Planner."
// The user decides: "I'm going to write for 2 hours" and the app counts down.
//
// Key difference from Pomodoro: no forced breaks. The block is sacred.
// Optional mid-point check-in ("You're halfway through your 2h block!").

import Foundation

struct TimeBlockStrategy: FocusModeStrategy, Sendable {
    let mode = FocusMode.timeBlock
    let direction = TimerDirection.countDown
    let hasTarget = true
    let supportsAutoAdvance = false  // Block ends → session done

    func initialPhase(config: FocusConfig) -> FocusPhase {
        .block
    }

    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval? {
        switch phase {
        case .block:
            return config.defaultBlockDuration
        default:
            return nil
        }
    }

    func nextPhase(
        after phase: FocusPhase,
        elapsed: TimeInterval,
        config: FocusConfig
    ) -> FocusPhase? {
        // Time Block has no next phase — when the block is done, the session is done.
        nil
    }

    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval {
        // If the user manually requests a break (unusual for time blocks),
        // suggest 10% of their focus time, clamped to 5-15 minutes.
        let suggested = elapsed * 0.1
        return min(max(suggested, 5 * 60), 15 * 60)
    }
}
