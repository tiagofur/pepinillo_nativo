// LiveActivityClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client for managing ActivityKit Live Activities.
// The live implementation is wired in PepinilloApp — this file defines
// only the interface and the test/preview stubs.

import Foundation
import ComposableArchitecture

// MARK: - Live Activity Client

struct LiveActivityClient: Sendable {
    /// Start a new Live Activity for the given session state.
    var start: @Sendable (FocusSessionState, String?) async -> Void = { _, _ in }
    /// Update the Live Activity's dynamic content on each tick.
    var update: @Sendable (FocusSessionState, String?) async -> Void = { _, _ in }
    /// End the Live Activity. Pass wasCompleted to show completion or cancellation.
    var end: @Sendable (Bool) async -> Void = { _ in }
    /// Whether ActivityKit Live Activities are enabled on this device.
    var isAvailable: @Sendable () -> Bool = { false }
}

// MARK: - Dependency Registration

extension LiveActivityClient: DependencyKey {
    /// No-op live value. The real ActivityKit implementation is injected
    /// in PepinilloApp using LiveActivityClient.activityKit().
    static let liveValue = LiveActivityClient(
        start: { _, _ in },
        update: { _, _ in },
        end: { _ in },
        isAvailable: { false }
    )

    static let testValue = LiveActivityClient(
        start: { _, _ in },
        update: { _, _ in },
        end: { _ in },
        isAvailable: { false }
    )
}

extension DependencyValues {
    var liveActivityClient: LiveActivityClient {
        get { self[LiveActivityClient.self] }
        set { self[LiveActivityClient.self] = newValue }
    }
}

