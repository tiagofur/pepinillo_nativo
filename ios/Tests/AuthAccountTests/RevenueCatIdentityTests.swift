// RevenueCatIdentityTests.swift
// Tests for RevenueCat logIn on all backend auth paths (#197).

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("RevenueCat Identity")
@MainActor
struct RevenueCatIdentityTests {

    private func verifiedUser() -> CachedUserDTO {
        CachedUserDTO(
            id: "backend-user-42",
            email: "test@example.com",
            name: "Test",
            emailVerified: true
        )
    }

    @Test("email auth authenticated links RevenueCat to backend user id")
    func emailAuthLinksRevenueCat() async {
        let loggedInID = LockIsolated<String?>(nil)

        var appState = AppFeature.State()
        appState.auth = AuthFeature.State()

        let store = TestStore(initialState: appState) {
            AppFeature()
        } withDependencies: {
            $0.subscriptionClient.logIn = { userID in
                loggedInID.setValue(userID)
            }
            $0.syncClient.syncAll = {}
            $0.webSocketClient.connect = {}
            $0.persistenceClient.generateRecurringTasks = {}
            $0.persistenceClient.fetchTasks = { [] }
        }
        store.exhaustivity = .off

        let user = verifiedUser()
        await store.send(.auth(.presented(.delegate(.authenticated(user))))) {
            $0.cachedUser = user
            $0.displayName = user.name
            $0.userEmail = user.email
            $0.auth = nil
        }

        #expect(loggedInID.value == "backend-user-42")
    }

    @Test("email verification success links RevenueCat to backend user id")
    func verificationLinksRevenueCat() async {
        let loggedInID = LockIsolated<String?>(nil)

        var state = AppFeature.State()
        state.emailVerification = EmailVerificationFeature.State(email: "test@example.com")

        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.subscriptionClient.logIn = { userID in
                loggedInID.setValue(userID)
            }
            $0.syncClient.syncAll = {}
            $0.webSocketClient.connect = {}
        }
        store.exhaustivity = .off

        let user = verifiedUser()
        await store.send(.emailVerification(.presented(.delegate(.verificationSucceeded(user))))) {
            $0.cachedUser = user
            $0.displayName = user.name
            $0.userEmail = user.email
            $0.emailVerification = nil
        }

        #expect(loggedInID.value == "backend-user-42")
    }
}