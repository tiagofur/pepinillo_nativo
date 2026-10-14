// FocusClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client wrapping the FocusEngine actor.
// This is the bridge between TCA's effect system and our actor-based engine.

import Foundation
import ComposableArchitecture

// MARK: - Focus Client

@DependencyClient
public struct FocusClient: Sendable {
    /// Start a new focus session.
    public var start: @Sendable (FocusMode, FocusConfig, UUID?, TimeInterval?, Date?, Date?, Int) async -> Void
    /// Pause the active session.
    public var pause: @Sendable () async -> Void
    /// Resume a paused session.
    public var resume: @Sendable () async -> Void
    /// Stop the active session.
    public var stop: @Sendable (Bool) async -> Void
    /// Stop without emitting to the event stream, returning the terminal result (S7).
    /// stopTapped drains the abandon through this instead of the observation task.
    public var abandonSession: @Sendable () async -> FocusSessionResult? = { nil }
    /// Adopt a killed session as live (Sprint-5 T3). Rebuilds timer state from
    /// ghost anchors without emitting persistence events.
    public var adoptGhostSession: @Sendable (FocusMode, FocusConfig, FocusPhase, TimeInterval, UUID?) async -> Void = { _, _, _, _, _ in }
    /// Record an interruption.
    public var recordInterruption: @Sendable () async -> Void
    /// Skip to next phase.
    public var skipPhase: @Sendable () async -> Void
    /// Advance from the waiting-for-next-phase hold into the pending next phase.
    /// Only has an effect when the engine is in the waiting state (auto-start OFF).
    public var startNextPhase: @Sendable () async -> Void
    /// Update the focus configuration while a session is active (real-time settings sync).
    public var updateConfig: @Sendable (FocusConfig) async -> Void
    /// Observe engine events as an AsyncStream (no-op on watchOS).
    public var events: @Sendable () async -> AsyncStream<FocusEngineEvent> = { .finished }
    /// Get current state snapshot.
    public var currentState: @Sendable () async -> FocusSessionState? = { nil }
    /// Reset engine cycle counter for a new calendar day.
    public var resetForNewDay: @Sendable () async -> Void = {}
    /// Sync with an external state change (e.g. from a widget) to align internal timing anchors.
    public var syncExternalState: @Sendable (TimeInterval, TimeInterval?) async -> Void = { _, _ in }
    /// Apply a pause that happened outside the app at a specific timestamp.
    public var applyExternalPause: @Sendable (TimeInterval, TimeInterval?, Date) async -> Void = { _, _, _ in }
    /// Apply a resume that happened outside the app and reconcile live elapsed/remaining.
    public var applyExternalResume: @Sendable (TimeInterval, TimeInterval?) async -> Void = { _, _ in }
}

// MARK: - Dependency Registration

extension FocusClient: DependencyKey {
    public static let liveValue: FocusClient = {
        #if os(iOS) || os(macOS)
        let engine = FocusEngine()

        return FocusClient(
            start: { mode, config, taskID, duration, timerStart, timerEnd, completedWorkSessionsToday in
                await engine.start(
                    mode: mode,
                    config: config,
                    linkedTaskID: taskID,
                    customDuration: duration,
                    timerStart: timerStart,
                    timerEnd: timerEnd,
                    completedWorkSessionsToday: completedWorkSessionsToday
                )
            },
            pause: {
                await engine.pause()
            },
            resume: {
                await engine.resume()
            },
            stop: { completed in
                await engine.stop(completed: completed)
            },
            abandonSession: {
                await engine.abandonSession()
            },
            adoptGhostSession: { mode, config, phase, elapsed, linkedTaskID in
                await engine.adoptGhostSession(
                    mode: mode,
                    config: config,
                    phase: phase,
                    elapsed: elapsed,
                    linkedTaskID: linkedTaskID
                )
            },
            recordInterruption: {
                await engine.recordInterruption()
            },
            skipPhase: {
                await engine.skipToNextPhase()
            },
            startNextPhase: {
                await engine.startNextPhase()
            },
            updateConfig: { newConfig in
                await engine.updateConfig(newConfig)
            },
            events: {
                await engine.events ?? AsyncStream { $0.finish() }
            },
            currentState: {
                await engine.currentState()
            },
            resetForNewDay: {
                await engine.resetForNewDay()
            },
            syncExternalState: { elapsed, remaining in
                await engine.syncExternalState(elapsed: elapsed, remaining: remaining)
            },
            applyExternalPause: { elapsed, remaining, pausedAt in
                await engine.applyExternalPause(elapsed: elapsed, remaining: remaining, pausedAt: pausedAt)
            },
            applyExternalResume: { elapsed, remaining in
                await engine.applyExternalResume(elapsed: elapsed, remaining: remaining)
            }
        )
        #else
        // watchOS uses WatchConnectivity instead of local FocusEngine
        return FocusClient(
            start: { _, _, _, _, _, _, _ in },
            pause: {},
            resume: {},
            stop: { _ in },
            // No local engine: nothing to abandon or adopt (explicit because
            // Swift 6.4 ignores memberwise-init defaults for these).
            abandonSession: { nil },
            adoptGhostSession: { _, _, _, _, _ in },
            recordInterruption: {},
            skipPhase: {},
            startNextPhase: {},
            updateConfig: { _ in },
            events: { .finished },
            currentState: { nil },
            resetForNewDay: {},
            syncExternalState: { _, _ in },
            applyExternalPause: { _, _, _ in },
            applyExternalResume: { _, _ in }
        )
        #endif
    }()

    public static let testValue: FocusClient = {
        var client = FocusClient()
        client.start = { _, _, _, _, _, _, _ in }
        return client
    }()
}

extension DependencyValues {
    public var focusClient: FocusClient {
        get { self[FocusClient.self] }
        set { self[FocusClient.self] = newValue }
    }
}
