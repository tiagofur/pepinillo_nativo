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
    /// Apple authorization code used by the backend to revoke Apple user tokens on
    /// account deletion (Sign in with Apple requirement, #196). Captured on each
    /// SIWA completion; persisted in prefs for later revocation.
    public let authorizationCode: String?

    public init(userID: String, displayName: String?, email: String?, identityToken: String? = nil, nonce: String? = nil, authorizationCode: String? = nil) {
        self.userID = userID
        self.displayName = displayName
        self.email = email
        self.identityToken = identityToken
        self.nonce = nonce
        self.authorizationCode = authorizationCode
    }
}

// MARK: - Client

@DependencyClient
public struct SignInWithAppleClient: Sendable {
    /// Returns `true` if the saved Apple ID is still authorized.
    /// Call this on app launch with the stored `appleUserID`.
    public var checkCredentialState: @Sendable (String) async -> Bool = { _ in false }

    /// Emits the affected Apple user ID whenever the system reports that the
    /// user revoked Sign in with Apple credentials mid-session (Settings → Apple
    /// ID → Sign in with Apple → Stop, or signed out of all devices). Use this
    /// to perform a full sign-out without waiting for the next cold start (#195).
    public var observeCredentialRevocation: @Sendable () async -> AsyncStream<Void> = { AsyncStream { $0.finish() } }
}

/// Sendable box around a NotificationCenter observer token so it can cross the
/// `@Sendable` termination closure boundary.
private struct ObserverBox: @unchecked Sendable {
    let value: NSObjectProtocol
    init(_ value: NSObjectProtocol) { self.value = value }
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
        },
        observeCredentialRevocation: {
            AsyncStream { continuation in
                let token = NotificationCenter.default.addObserver(
                    forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
                    object: nil,
                    queue: nil
                ) { _ in
                    continuation.yield(())
                }
                // `token` is an NSObjectProtocol that is not Sendable; wrap the
                // removal in a @Sendable closure via an unsafe transferable box.
                let boxed = ObserverBox(token)
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(boxed.value)
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
