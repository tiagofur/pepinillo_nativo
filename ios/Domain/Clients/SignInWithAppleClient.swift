// SignInWithAppleClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency client for Sign In with Apple.
// The actual sign-in button and flow live in AuthView;
// this client only verifies credential state on app launch.

import Foundation
import AuthenticationServices
import ComposableArchitecture

// MARK: - Apple User Info

public struct AppleUserInfo: Sendable, Equatable {
    public let userID: String       // ASAuthorizationAppleIDCredential.user
    public let displayName: String? // fullName (only available on first sign-in)
    public let email: String?       // email (only available on first sign-in)
    public let identityToken: String? // JWT identity token for backend verification
    public let nonce: String?       // raw nonce used to sign the idToken (PKCE-equivalent)

    public init(userID: String, displayName: String?, email: String?, identityToken: String? = nil, nonce: String? = nil) {
        self.userID = userID
        self.displayName = displayName
        self.email = email
        self.identityToken = identityToken
        self.nonce = nonce
    }
}

// MARK: - Client

@DependencyClient
public struct SignInWithAppleClient: Sendable {
    /// Returns `true` if the saved Apple ID is still authorized.
    /// Call this on app launch with the stored `appleUserID`.
    public var checkCredentialState: @Sendable (String) async -> Bool = { _ in false }
}

// MARK: - Live implementation

extension SignInWithAppleClient: DependencyKey {
    public static let liveValue = SignInWithAppleClient(
        checkCredentialState: { userID in
            await withCheckedContinuation { continuation in
                ASAuthorizationAppleIDProvider()
                    .getCredentialState(forUserID: userID) { state, _ in
                        continuation.resume(returning: state == .authorized)
                    }
            }
        }
    )

    public static let testValue = SignInWithAppleClient()
}

extension DependencyValues {
    public var signInWithAppleClient: SignInWithAppleClient {
        get { self[SignInWithAppleClient.self] }
        set { self[SignInWithAppleClient.self] = newValue }
    }
}
