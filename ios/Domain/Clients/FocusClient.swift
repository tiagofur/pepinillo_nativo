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
    public var start: @Sendable (FocusMode, FocusConfig, UUID?, TimeInterval?) async -> Void
    /// Pause the active session.
    public var pause: @Sendable () async -> Void
    /// Resume a paused session.
    public var resume: @Sendable () async -> Void
    /// Stop the active session.
    public var stop: @Sendable (Bool) async -> Void
    /// Record an interruption.
    public var recordInterruption: @Sendable () async -> Void
    /// Skip to next phase.
    public var skipPhase: @Sendable () async -> Void
    /// Observe engine events as an AsyncStream (no-op on watchOS).
    public var events: @Sendable () async -> AsyncStream<FocusEngineEvent> = { .finished }
    /// Get current state snapshot.
    public var currentState: @Sendable () async -> FocusSessionState? = { nil }
}

// MARK: - Dependency Registration

extension FocusClient: DependencyKey {
    public static let liveValue: FocusClient = {
        #if os(iOS) || os(macOS)
        let engine = FocusEngine()

        return FocusClient(
            start: { mode, config, taskID, duration in
                await engine.start(
                    mode: mode,
                    config: config,
                    linkedTaskID: taskID,
                    customDuration: duration
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
            recordInterruption: {
                await engine.recordInterruption()
            },
            skipPhase: {
                await engine.skipToNextPhase()
            },
            events: {
                await engine.events ?? AsyncStream { $0.finish() }
            },
            currentState: {
                await engine.currentState()
            }
        )
        #else
        // watchOS uses WatchConnectivity instead of local FocusEngine
        return FocusClient(
            start: { _, _, _, _ in },
            pause: {},
            resume: {},
            stop: { _ in },
            recordInterruption: {},
            skipPhase: {},
            events: { .finished },
            currentState: { nil }
        )
        #endif
    }()

    public static let testValue = FocusClient()
}

extension DependencyValues {
    public var focusClient: FocusClient {
        get { self[FocusClient.self] }
        set { self[FocusClient.self] = newValue }
    }
}
