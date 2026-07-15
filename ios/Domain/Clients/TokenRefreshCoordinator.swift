// TokenRefreshCoordinator.swift
// Pepinillo — Deep Work Companion for Apple
//
// Single-flight token refresh shared by APIClient and WebSocketClient (#203).
// Concurrent 401s must not rotate the refresh token twice.

import Foundation

/// Coordinates refresh-token rotation so only one refresh runs at a time.
actor TokenRefreshCoordinator {
    static let shared = TokenRefreshCoordinator()

    private var inFlight: Task<(accessToken: String, refreshToken: String), Error>?

    /// Runs `refresh` once; concurrent callers await the same in-flight task.
    func refresh(
        refreshToken: String,
        performRefresh: @escaping @Sendable (String) async throws -> (accessToken: String, refreshToken: String),
        saveTokens: @escaping @Sendable (String, String) async throws -> Void
    ) async throws -> (accessToken: String, refreshToken: String) {
        if let inFlight {
            return try await inFlight.value
        }

        let task = Task<(accessToken: String, refreshToken: String), Error> {
            let tokens = try await performRefresh(refreshToken)
            try await saveTokens(tokens.accessToken, tokens.refreshToken)
            return tokens
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
}