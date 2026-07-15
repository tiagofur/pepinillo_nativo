// AppleSignInTests.swift
// Tests for SIWA cold-restore vs fresh sign-in and error surfacing (#199, #200).

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("Apple Sign In")
@MainActor
struct AppleSignInTests {

    @Test("appleIdentityRestored does not invent emailVerified or save cached user")
    func identityRestoreIsLightweight() async {
        var state = AppFeature.State()
        state.cachedUser = nil

        let store = TestStore(initialState: state) {
            AppFeature()
        }
        store.exhaustivity = .off

        await store.send(.appleIdentityRestored(AppleUserInfo(
            userID: "apple-1",
            displayName: "Apple User",
            email: "apple@privaterelay.appleid.com"
        ))) {
            $0.appleUserID = "apple-1"
            $0.displayName = "Apple User"
            $0.userEmail = "apple@privaterelay.appleid.com"
        }

        #expect(store.state.cachedUser == nil)
        #expect(store.state.profileSummaryUser?.emailVerified == false)
    }

    @Test("signInWithAppleFailed shows error for real failures")
    func signInFailureSurfacesError() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.signInWithAppleFailed(wasUserCancelled: false)) {
            $0.signInWithAppleError = String(
                localized: "Could not sign in with Apple. Please try again."
            )
        }
    }

    @Test("signInWithAppleFailed cancel is silent")
    func signInCancelIsSilent() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.signInWithAppleFailed(wasUserCancelled: true))
        #expect(store.state.signInWithAppleError == nil)
    }
}