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

    @Test("signInWithAppleBackendFailed surfaces sync error without clearing local identity")
    func backendFailureSurfacesError() async {
        var state = AppFeature.State()
        state.appleUserID = "apple-1"
        state.displayName = "Tiago"
        state.userEmail = "tiago@example.com"

        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(.signInWithAppleBackendFailed) {
            $0.signInWithAppleError = String(
                localized: "Signed in with Apple, but account sync failed. Some cloud features may be unavailable."
            )
        }

        #expect(store.state.appleUserID == "apple-1")
        #expect(store.state.displayName == "Tiago")
        #expect(store.state.userEmail == "tiago@example.com")
    }

    @Test("AppleLoginRequest encodes camelCase keys for backend Fiber")
    func appleLoginRequestEncodesCamelCase() throws {
        let request = AppleLoginRequest(
            idToken: "token-value",
            nonce: "nonce-value",
            name: "Tiago",
            email: "tiago@example.com"
        )
        let data = try JSONEncoder().encode(request)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"idToken\""))
        #expect(json.contains("\"nonce\""))
        #expect(!json.contains("id_token"))
        #expect(!json.contains("refresh_token"))
    }
}
