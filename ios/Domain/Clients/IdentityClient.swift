// IdentityClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for user identity state management.
// Derives identity from keychain token presence.

import Foundation
import ComposableArchitecture

// MARK: - Identity State

enum IdentityState: String, Sendable {
    case anonymous
    case registered
    case verified
}

// MARK: - Client

@DependencyClient
public struct IdentityClient: Sendable {
    public var currentState: @Sendable () async -> IdentityState = { .anonymous }
    public var isAnonymous: @Sendable () async -> Bool = { true }
    public var isAuthenticated: @Sendable () async -> Bool = { false }
    public var refreshState: @Sendable () -> Void = { }
}

// MARK: - Live implementation

extension IdentityClient: DependencyKey {
    public static var liveValue: IdentityClient {
        @Dependency(\.keychainClient) var keychain
        return IdentityClient(
            currentState: { await keychain.hasTokens() ? .registered : .anonymous },
            isAnonymous: { !(await keychain.hasTokens()) },
            isAuthenticated: { await keychain.hasTokens() },
            refreshState: { /* no-op, derived from keychain state */ }
        )
    }

    public static let testValue = IdentityClient()
}

// MARK: - DependencyValues registration

extension DependencyValues {
    public var identityClient: IdentityClient {
        get { self[IdentityClient.self] }
        set { self[IdentityClient.self] = newValue }
    }
}
