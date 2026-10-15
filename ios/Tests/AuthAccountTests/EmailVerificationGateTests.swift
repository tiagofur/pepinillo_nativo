// EmailVerificationGateTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for the email verification gate on cold-start restore (#192):
// - Unverified email users cannot bypass the gate after force-quit/relaunch.
// - Sign-in with Apple users (authorized credential) are not gated.
// - The verification sheet escape hatch clears the unverified session.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("Email Verification Gate", .serialized, .appGroupDefaultsSerialized)
@MainActor
struct EmailVerificationGateTests {

    // MARK: - Cold-start restore of unverified email user re-presents gate (#192)

    @Test("cachedUserLoaded with unverified email and no Apple ID presents verification sheet")
    func unverifiedEmailUserRePresentsVerificationSheet() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
        }
        store.exhaustivity = .off

        let unverifiedUser = CachedUserDTO(
            id: "user-1", email: "unverified@example.com", name: "Unverified", emailVerified: false
        )

        await store.send(.cachedUserLoaded(unverifiedUser)) {
            $0.cachedUser = unverifiedUser
            $0.displayName = "Unverified"
            $0.userEmail = "unverified@example.com"
            $0.emailVerification = EmailVerificationFeature.State(email: "unverified@example.com")
        }

        // The verification sheet must be presented — the user cannot use the app.
        #expect(store.state.emailVerification != nil)
    }

    // MARK: - Verified email user is not gated

    @Test("cachedUserLoaded with verified email does not present verification sheet")
    func verifiedEmailUserNotGated() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
        }
        store.exhaustivity = .off

        let verifiedUser = CachedUserDTO(
            id: "user-1", email: "verified@example.com", name: "Verified", emailVerified: true
        )

        await store.send(.cachedUserLoaded(verifiedUser)) {
            $0.cachedUser = verifiedUser
            $0.displayName = "Verified"
            $0.userEmail = "verified@example.com"
        }

        #expect(store.state.emailVerification == nil)
    }

    // MARK: - Unverified email user with Apple ID is not gated

    @Test("cachedUserLoaded with unverified email but active Apple ID is not gated")
    func unverifiedEmailWithAppleIDNotGated() async {
        var initialState = AppFeature.State()
        // Apple credential was already restored — appleUserID set by signInWithAppleSucceeded.
        initialState.appleUserID = "apple-abc"

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
        }
        store.exhaustivity = .off

        // Even though emailVerified is false, the Apple credential implies a verified
        // account — the gate should NOT present.
        let unverifiedUser = CachedUserDTO(
            id: "user-1", email: "apple-user@example.com", name: "Apple User", emailVerified: false
        )

        await store.send(.cachedUserLoaded(unverifiedUser)) {
            $0.cachedUser = unverifiedUser
            $0.displayName = "apple-user"
            $0.userEmail = "apple-user@example.com"
        }

        #expect(store.state.emailVerification == nil)
    }

    // MARK: - Verification sheet escape hatch clears session (#192)

    @Test("emailVerification signOutRequested clears session and dismisses sheet")
    func emailVerificationSignOutRequestedClearsSession() async {
        var initialState = AppFeature.State()
        let unverifiedUser = CachedUserDTO(
            id: "user-1", email: "unverified@example.com", name: "Unverified", emailVerified: false
        )
        initialState.cachedUser = unverifiedUser
        initialState.emailVerification = EmailVerificationFeature.State(email: "unverified@example.com")

        let store = TestStore(initialState: initialState) {
            AppFeature()
        } withDependencies: {
            $0.keychainClient.deleteTokens = {}
            $0.persistenceClient.fetchPreferences = { UserPreferencesDTO() }
            $0.persistenceClient.savePreferences = { _ in }
            $0.persistenceClient.deleteCachedUser = {}
            $0.subscriptionClient.logOut = {}
            $0.webSocketClient.disconnect = {}
        }
        store.exhaustivity = .off

        await store.send(.emailVerification(.presented(.delegate(.signOutRequested)))) {
            $0.emailVerification = nil
            $0.cachedUser = nil
            $0.appleUserID = nil
            $0.displayName = nil
            $0.userEmail = nil
        }

        // The unverified session is gone — the user will see AuthView on next render.
        #expect(store.state.isSignedIn == false)
        #expect(store.state.emailVerification == nil)
    }
}
