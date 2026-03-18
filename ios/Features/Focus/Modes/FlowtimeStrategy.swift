// FlowtimeStrategy.swift
// Pepinillo — Deep Work Companion for Apple
//
// Flowtime Technique: Open-ended focus session where the user decides when to break.
// The app calculates an optimal break duration based on how long they focused.
//
// Break formula (based on Flowtime research):
//   Focus < 25min  →  5min break
//   Focus < 50min  →  8min break
//   Focus < 90min  → 10min break
//   Focus ≥ 90min  → 15min break
//
// Why Flowtime matters: Many users find Pomodoro's rigid 25-minute blocks interrupt
// their flow state. Flowtime captures the "Pomodoro dropouts" — a large, underserved segment.

import Foundation

struct FlowtimeStrategy: FocusModeStrategy, Sendable {
    let mode = FocusMode.flowtime
    let direction = TimerDirection.countUp
    let hasTarget = false
    let supportsAutoAdvance = false  // User decides when to take a break

    func initialPhase(config: FocusConfig) -> FocusPhase {
        .flow
    }

    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval? {
        switch phase {
        case .flow:
            // Open-ended — no target
            return nil
        case .flowBreak(let suggestedDuration):
            // Break has a target (the calculated suggestion)
            return suggestedDuration
        default:
            return nil
        }
    }

    func nextPhase(
        after phase: FocusPhase,
        elapsed: TimeInterval,
        config: FocusConfig
    ) -> FocusPhase? {
        switch phase {
        case .flow:
            // User tapped "take a break" — suggest a break duration
            let breakDuration = suggestedBreakDuration(afterFocusing: elapsed)
            return .flowBreak(suggestedDuration: breakDuration)

        case .flowBreak:
            // After break, go back to flow
            return .flow

        default:
            return nil
        }
    }

    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval {
        let minutes = elapsed / 60.0
        switch minutes {
        case ..<25:  return 5 * 60    //  5 min break
        case ..<50:  return 8 * 60    //  8 min break
        case ..<90:  return 10 * 60   // 10 min break
        default:     return 15 * 60   // 15 min break
        }
    }
}
