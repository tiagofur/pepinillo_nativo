// SessionExpiryTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for session teardown paths in AppFeature:
// - tokenRefreshFailed clears the full signed-in state (#194)
// - appleCredentialRevoked mid-session triggers a full sign-out (#195)

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("Session Expiry")
@MainActor
struct SessionExpiryTests {

    private func signedInState() -> AppFeature.State {
        var state = AppFeature.State()
        state.cachedUser = CachedUserDTO(
            id: "user-1", email: "test@example.com", name: "Test", emailVerified: true
        )
        state.displayName = "Test"
        state.userEmail = "test@example.com"
        return state
    }

    private func configureCleanupDeps(_ deps: inout DependencyValues) {
        deps.keychainClient.deleteTokens = {}
        deps.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        deps.persistenceClient.savePreferences = { _ in }
        deps.persistenceClient.deleteCachedUser = {}
        deps.subscriptionClient.logOut = {}
        deps.webSocketClient.disconnect = {}
    }

    // MARK: - tokenRefreshFailed clears session (#194)

    @Test("tokenRefreshFailed clears session state and runs cleanup")
    func tokenRefreshFailedClearsSession() async {
        let store = TestStore(initialState: signedInState()) {
            AppFeature()
        } withDependencies: { [self] in
            configureCleanupDeps(&$0)
        }
        store.exhaustivity = .off

        await store.send(.tokenRefreshFailed) {
            $0.cachedUser = nil
            $0.appleUserID = nil
            $0.displayName = nil
            $0.userEmail = nil
        }

        #expect(store.state.isSignedIn == false)
    }

    // MARK: - Apple credential revoked mid-session (#195)

    @Test("appleCredentialRevoked triggers full sign-out")
    func appleCredentialRevokedSignsOut() async {
        var state = signedInState()
        state.appleUserID = "apple-123"

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: { [self] in
            configureCleanupDeps(&$0)
        }
        store.exhaustivity = .off

        await store.send(.appleCredentialRevoked) {
            $0.cachedUser = nil
            $0.appleUserID = nil
            $0.displayName = nil
            $0.userEmail = nil
        }

        #expect(store.state.isSignedIn == false)
    }

    // MARK: - Apple credential state check unauthorized (#195)

    @Test("appleCredentialStateChecked unauthorized signs out completely")
    func appleCredentialUnauthorizedSignsOut() async {
        var state = signedInState()
        state.appleUserID = "apple-123"

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: { [self] in
            configureCleanupDeps(&$0)
        }
        store.exhaustivity = .off

        await store.send(.appleCredentialStateChecked("apple-123", false)) {
            $0.cachedUser = nil
            $0.appleUserID = nil
            $0.displayName = nil
            $0.userEmail = nil
        }

        // Previously this path only cleared appleUserID/displayName/userEmail but
        // left cachedUser alive — isSignedIn stayed true (#195).
        #expect(store.state.isSignedIn == false)
    }

    // MARK: - Sign-out via profile delegate

    @Test("profile signedOut delegate clears session including tokens and RC")
    func profileSignedOutClearsSession() async {
        var state = signedInState()
        // profile must be present so the ifLet reducer accepts the delegate action.
        state.profile = ProfileFeature.State(user: state.cachedUser!)

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: { [self] in
            configureCleanupDeps(&$0)
        }
        store.exhaustivity = .off

        await store.send(.profile(.presented(.delegate(.signedOut)))) {
            $0.cachedUser = nil
            $0.appleUserID = nil
            $0.displayName = nil
            $0.userEmail = nil
            $0.profile = nil
        }

        #expect(store.state.isSignedIn == false)
    }
}
