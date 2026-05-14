// SyncModeClient.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation
import ComposableArchitecture

@DependencyClient
struct SyncModeClient: Sendable {
    var reconcile: @Sendable (_ capabilities: UserCapabilities) async -> Void = { _ in }
}

extension SyncModeClient: DependencyKey {
    static let liveValue = SyncModeClient()
    static let testValue = SyncModeClient()
}

extension DependencyValues {
    var syncModeClient: SyncModeClient {
        get { self[SyncModeClient.self] }
        set { self[SyncModeClient.self] = newValue }
    }
}
