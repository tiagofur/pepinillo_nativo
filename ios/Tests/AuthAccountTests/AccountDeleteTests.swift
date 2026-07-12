// AccountDeleteTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for AppFeature account-deletion flow (#193): the backend call must not
// be swallowed with `try?`, local PII must be wiped on success, and errors must
// surface to the UI so the user can retry.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("Account Delete")
@MainActor
struct AccountDeleteTests {

    // MARK: - Fixtures

    /// A verified email user with tokens in the keychain.
    private func signedInState() -> AppFeature.State {
        var state = AppFeature.State()
        state.cachedUser = CachedUserDTO(
            id: "user-1", email: "test@example.com", name: "Test", emailVerified: true
        )
        state.displayName = "Test"
        state.userEmail = "test@example.com"
        return state
    }

    private func configureDependencies(_ deps: inout DependencyValues, deleteSucceeds: Bool) {
        deps.keychainClient.loadRefreshToken = { "refresh-token-abc" }
        deps.keychainClient.deleteTokens = {}
        deps.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
        deps.persistenceClient.savePreferences = { _ in }
        deps.persistenceClient.deleteCachedUser = {}
        deps.persistenceClient.deleteAllTasks = {}
        deps.persistenceClient.deleteAllSessions = {}
        deps.persistenceClient.deleteAllStats = {}
        deps.subscriptionClient.logOut = {}
        deps.webSocketClient.disconnect = {}
        if deleteSucceeds {
            deps.apiClient.deleteAccount = { _ in }
        } else {
            deps.apiClient.deleteAccount = { _ in throw APIClientError.networkError }
        }
    }

    // MARK: - Success path

    @Test("deleteAccount succeeds wipes local data tokens and session")
    func deleteAccountSucceedsWipesLocalData() async {
        let store = TestStore(initialState: signedInState()) {
            AppFeature()
        } withDependencies: { [self] in
            configureDependencies(&$0, deleteSucceeds: true)
        }
        store.exhaustivity = .off

        await store.send(.deleteAccountTapped) {
            $0.isDeletingAccount = true
            $0.deleteAccountError = nil
        }

        // Backend confirms → wipe runs → session torn down.
        await store.receive(.deleteAccountSucceeded) {
            $0.isDeletingAccount = false
            $0.cachedUser = nil
            $0.appleUserID = nil
            $0.displayName = nil
            $0.userEmail = nil
        }
    }

    // MARK: - Failure path

    @Test("deleteAccount fails keeps session and surfaces error")
    func deleteAccountFailsKeepsSessionShowsError() async {
        let store = TestStore(initialState: signedInState()) {
            AppFeature()
        } withDependencies: { [self] in
            configureDependencies(&$0, deleteSucceeds: false)
        }
        store.exhaustivity = .off

        await store.send(.deleteAccountTapped) {
            $0.isDeletingAccount = true
        }

        // Backend rejects → session MUST stay intact so the user can retry.
        await store.receive(.deleteAccountFailed(APIClientError.networkError.userMessage)) {
            $0.isDeletingAccount = false
            $0.deleteAccountError = APIClientError.networkError.userMessage
            // Session preserved — not nil.
            $0.cachedUser = store.state.cachedUser
        }

        // Verify session survived.
        #expect(store.state.cachedUser != nil)
        #expect(store.state.isSignedIn)
    }

    // MARK: - Apple authorization code forwarded

    @Test("deleteAccount includes appleAuthorizationCode when present")
    func deleteAccountIncludesAppleAuthCode() async {
        var initialState = signedInState()
        initialState.appleUserID = "apple-123"

        let capturedRequest = LockIsolated<DeleteAccountRequest?>(nil)

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.keychainClient.loadRefreshToken = { "refresh-token-abc" }
            $0.keychainClient.deleteTokens = {}
            $0.persistenceClient.fetchPreferences = {
                var prefs = UserPreferencesDTO()
                prefs.appleAuthorizationCode = "apple-auth-code-xyz"
                return prefs
            }
            $0.persistenceClient.savePreferences = { _ in }
            $0.persistenceClient.deleteCachedUser = {}
            $0.persistenceClient.deleteAllTasks = {}
            $0.persistenceClient.deleteAllSessions = {}
            $0.persistenceClient.deleteAllStats = {}
            $0.subscriptionClient.logOut = {}
            $0.webSocketClient.disconnect = {}
            $0.apiClient.deleteAccount = { req in
                capturedRequest.setValue(req)
            }
        }
        store.exhaustivity = .off

        await store.send(.deleteAccountTapped) {
            $0.isDeletingAccount = true
        }
        await store.receive(.deleteAccountSucceeded)

        // The persisted Apple authorization code must be forwarded to the backend.
        let request = try! #require(capturedRequest.value)
        #expect(request.appleAuthorizationCode == "apple-auth-code-xyz")
        #expect(request.refreshToken == "refresh-token-abc")
    }
}
