// AuthFeatureTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA TestStore tests for AuthFeature: wipeAndSync failure alert path.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("AuthFeature")
@MainActor
struct AuthFeatureTests {

    // MARK: - Helpers

    private func makeUser() -> CachedUserDTO {
        CachedUserDTO(id: "user-1", email: "test@example.com", name: "Test", emailVerified: true)
    }

    // MARK: - wipeAndSync failure alert

    @Test("useAccountOnlyTapped shows alert when wipeAndSync throws")
    func useAccountOnlyTappedShowsAlertOnWipeFailure() async throws {
        struct SimulatedSyncError: Error, LocalizedError {
            var errorDescription: String? { "simulated network error" }
        }

        let store = TestStore(
            initialState: AuthFeature.State(showMergeDialog: true)
        ) {
            AuthFeature()
        } withDependencies: {
            $0.syncClient.wipeAndSync = { throw SimulatedSyncError() }
            $0.persistenceClient.fetchCachedUser = { nil }
        }

        // Dismiss the merge dialog and choose account-only
        await store.send(.useAccountOnlyTapped) {
            $0.showMergeDialog = false
            $0.isSyncing = true
        }

        // The error should surface as wipeAndSyncFailed — no authenticated delegate sent
        await store.receive(.wipeAndSyncFailed("simulated network error")) {
            $0.isSyncing = false
            $0.wipeAndSyncError = "simulated network error"
        }
    }

    @Test("retryWipeAndSync re-runs wipeAndSync and authenticates on success")
    func retryWipeAndSyncAuthenticatesOnSuccess() async throws {
        let fakeUser = makeUser()

        let store = TestStore(
            initialState: AuthFeature.State(isSyncing: false, wipeAndSyncError: "previous error")
        ) {
            AuthFeature()
        } withDependencies: {
            $0.syncClient.wipeAndSync = { /* succeeds */ }
            $0.persistenceClient.fetchCachedUser = { fakeUser }
        }
        store.exhaustivity = .off

        await store.send(.retryWipeAndSync) {
            $0.wipeAndSyncError = nil
            $0.isSyncing = true
        }

        await store.receive(.delegate(.authenticated(fakeUser)))
    }

    @Test("dismissWipeAndSyncError continues to authenticated state")
    func dismissWipeAndSyncErrorAuthenticatesUser() async throws {
        let fakeUser = makeUser()

        let store = TestStore(
            initialState: AuthFeature.State(isSyncing: false, wipeAndSyncError: "some error")
        ) {
            AuthFeature()
        } withDependencies: {
            $0.persistenceClient.fetchCachedUser = { fakeUser }
        }
        store.exhaustivity = .off

        await store.send(.dismissWipeAndSyncError) {
            $0.wipeAndSyncError = nil
            $0.isSyncing = false
        }

        await store.receive(.delegate(.authenticated(fakeUser)))
    }

    @Test("useAccountOnlyTapped authenticates directly when wipeAndSync succeeds")
    func useAccountOnlyTappedAuthenticatesOnSuccess() async throws {
        let fakeUser = makeUser()

        let store = TestStore(
            initialState: AuthFeature.State(showMergeDialog: true)
        ) {
            AuthFeature()
        } withDependencies: {
            $0.syncClient.wipeAndSync = { /* succeeds */ }
            $0.persistenceClient.fetchCachedUser = { fakeUser }
        }
        store.exhaustivity = .off

        await store.send(.useAccountOnlyTapped) {
            $0.showMergeDialog = false
            $0.isSyncing = true
        }

        // Happy path: no alert, goes straight to authenticated
        await store.receive(.delegate(.authenticated(fakeUser)))
    }

    // MARK: - Probe-then-upload merge flow (S1)

    @Test("authSucceeded with server data asks before uploading anything")
    func authSucceededAsksBeforeUploading() async throws {
        struct ProbeBypassError: Error {}
        let oldCanSync = AppGroupDefaults.canBackendSync
        AppGroupDefaults.canBackendSync = true
        defer { AppGroupDefaults.canBackendSync = oldCanSync }

        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.persistenceClient.getSessionCount = { 3 }
            $0.syncClient.serverHasData = { true }
            // Tripwire: pre-fix code uploads before asking (S1 violation).
            $0.syncClient.initialUpload = { throw ProbeBypassError() }
        }

        await store.send(.authSucceeded(makeUser())) {
            $0.isSyncing = true
        }
        await store.receive(.initialSyncCompleted(makeUser())) {
            $0.isSyncing = false
            $0.showMergeDialog = true
        }
    }

    @Test("authSucceeded with empty server uploads then authenticates")
    func authSucceededUploadsWhenServerEmpty() async throws {
        let oldCanSync = AppGroupDefaults.canBackendSync
        AppGroupDefaults.canBackendSync = true
        defer { AppGroupDefaults.canBackendSync = oldCanSync }
        let user = makeUser()

        let store = TestStore(initialState: AuthFeature.State()) {
            AuthFeature()
        } withDependencies: {
            $0.persistenceClient.getSessionCount = { 2 }
            $0.syncClient.serverHasData = { false }
            $0.syncClient.initialUpload = { false }
        }

        await store.send(.authSucceeded(user)) {
            $0.isSyncing = true
        }
        await store.receive(.delegate(.authenticated(user)))
    }
}
