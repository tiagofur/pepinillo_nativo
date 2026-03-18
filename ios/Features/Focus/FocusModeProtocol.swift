// FocusModeProtocol.swift
// Pepinillo — Deep Work Companion for Apple
//
// The Strategy pattern protocol that all 4 focus modes conform to.
// This is the architectural backbone — the FocusEngine delegates all
// mode-specific behavior to the active strategy, keeping itself generic.

import Foundation

// MARK: - Focus Mode Strategy Protocol

/// Defines the contract for a focus mode's behavior.
///
/// Each mode (Pomodoro, Flowtime, TimeBlock, Stopwatch) implements this protocol.
/// The FocusEngine calls these methods without knowing which mode is active,
/// enabling ~80% code sharing across all modes.
///
/// Adding a 5th mode = one new file conforming to this protocol. Zero engine changes.
protocol FocusModeStrategy: Sendable {
    /// Which focus mode this strategy implements.
    var mode: FocusMode { get }

    /// Whether the timer counts down (Pomodoro, TimeBlock) or up (Flowtime, Stopwatch).
    var direction: TimerDirection { get }

    /// Whether this mode has a defined end time.
    /// `true` for Pomodoro (25min) and TimeBlock (user-defined).
    /// `false` for Flowtime and Stopwatch (open-ended).
    var hasTarget: Bool { get }

    /// Returns the target duration for the current phase, or `nil` for open-ended modes.
    /// - Parameter config: User's focus configuration settings.
    /// - Parameter phase: The current focus phase.
    func targetDuration(config: FocusConfig, phase: FocusPhase) -> TimeInterval?

    /// Returns the initial phase when starting a new session.
    /// - Parameter config: User's focus configuration settings.
    func initialPhase(config: FocusConfig) -> FocusPhase

    /// Determines what phase comes after the current one completes.
    /// Returns `nil` if the session is fully complete (no more phases).
    /// - Parameter phase: The phase that just finished.
    /// - Parameter elapsed: Total elapsed focus time (not including breaks).
    /// - Parameter config: User's focus configuration settings.
    func nextPhase(after phase: FocusPhase, elapsed: TimeInterval, config: FocusConfig) -> FocusPhase?

    /// Calculates the suggested break duration based on how long the user focused.
    /// - Parameter elapsed: How many seconds the user focused before requesting a break.
    func suggestedBreakDuration(afterFocusing elapsed: TimeInterval) -> TimeInterval

    /// Whether the mode supports auto-advancing to the next phase without user interaction.
    var supportsAutoAdvance: Bool { get }
}

// MARK: - Factory

extension FocusMode {
    /// Returns the strategy implementation for this mode.
    /// This is the only place that maps enum cases to concrete types.
    var strategy: any FocusModeStrategy {
        switch self {
        case .pomodoro:  return PomodoroStrategy()
        case .flowtime:  return FlowtimeStrategy()
        case .timeBlock: return TimeBlockStrategy()
        case .stopwatch: return StopwatchStrategy()
        }
    }
}
