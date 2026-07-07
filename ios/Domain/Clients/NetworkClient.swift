// NetworkClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA Dependency Client wrapping NWPathMonitor.
// Surfaces connectivity changes so the UI can show an offline banner (issue #89)
// and so sync/reducers can react to connectivity loss without silent failures.

import Foundation
import Network
import ComposableArchitecture

struct NetworkClient: Sendable {
    /// Emits the current connectivity state immediately, then on every change.
    /// `true` = connected (any usable interface). `false` = no usable path.
    var observeConnectivity: @Sendable () -> AsyncStream<Bool> = { AsyncStream { _ in } }
}

extension NetworkClient: DependencyKey {
    static let liveValue: NetworkClient = {
        // `NWPathMonitor` is not Sendable; wrap in a nonisolated(unsafe) token.
        // Only one monitor is needed for the app lifetime.
        nonisolated(unsafe) let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.pepinillo.network-monitor")

        return NetworkClient(
            observeConnectivity: {
                AsyncStream { continuation in
                    // Seed with the current state immediately.
                    continuation.yield(monitor.currentPath.status == .satisfied)

                    monitor.pathUpdateHandler = { path in
                        let isConnected = path.status == .satisfied
                        continuation.yield(isConnected)
                    }
                    monitor.start(queue: queue)

                    // Stop the monitor when the stream consumer finishes.
                    continuation.onTermination = { _ in
                        monitor.cancel()
                    }
                }
            }
        )
    }()

    /// Preview/test value — always reports connected.
    static let testValue = NetworkClient(
        observeConnectivity: { AsyncStream { $0.yield(true) } }
    )
}

extension DependencyValues {
    var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}
