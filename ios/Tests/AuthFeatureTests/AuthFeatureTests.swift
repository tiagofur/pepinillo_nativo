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

        // The error should surface as wipeAndSyncFailed
        await store.receive(\.wipeAndSyncFailed) {
            $0.isSyncing = false
            $0.wipeAndSyncError = "simulated network error"
        }

        // No delegate(.authenticated) should be sent — user must act on the alert first
    }

    @Test("retryWipeAndSync re-runs wipeAndSync and authenticates on success")
    func retryWipeAndSyncAuthenticatesOnSuccess() async throws {
        let fakeUser = CachedUserDTO(
            id: "user-1", email: "test@example.com", name: "Test",
            emailVerified: true
        )

        let store = TestStore(
            initialState: AuthFeature.State(wipeAndSyncError: "previous error", isSyncing: false)
        ) {
            AuthFeature()
        } withDependencies: {
            $0.syncClient.wipeAndSync = { /* succeeds */ }
            $0.persistenceClient.fetchCachedUser = { fakeUser }
        }

        await store.send(.retryWipeAndSync) {
            $0.wipeAndSyncError = nil
            $0.isSyncing = true
        }

        await store.receive(\.delegate.authenticated)
    }

    @Test("dismissWipeAndSyncError continues to authenticated state")
    func dismissWipeAndSyncErrorAuthenticatesUser() async throws {
        let fakeUser = CachedUserDTO(
            id: "user-1", email: "test@example.com", name: "Test",
            emailVerified: true
        )

        let store = TestStore(
            initialState: AuthFeature.State(wipeAndSyncError: "some error", isSyncing: false)
        ) {
            AuthFeature()
        } withDependencies: {
            $0.persistenceClient.fetchCachedUser = { fakeUser }
        }

        await store.send(.dismissWipeAndSyncError) {
            $0.wipeAndSyncError = nil
            $0.isSyncing = false
        }

        await store.receive(\.delegate.authenticated)
    }

    @Test("useAccountOnlyTapped authenticates directly when wipeAndSync succeeds")
    func useAccountOnlyTappedAuthenticatesOnSuccess() async throws {
        let fakeUser = CachedUserDTO(
            id: "user-1", email: "test@example.com", name: "Test",
            emailVerified: true
        )

        let store = TestStore(
            initialState: AuthFeature.State(showMergeDialog: true)
        ) {
            AuthFeature()
        } withDependencies: {
            $0.syncClient.wipeAndSync = { /* succeeds */ }
            $0.persistenceClient.fetchCachedUser = { fakeUser }
        }

        await store.send(.useAccountOnlyTapped) {
            $0.showMergeDialog = false
            $0.isSyncing = true
        }

        // Happy path: no alert, goes straight to authenticated
        await store.receive(\.delegate.authenticated)
    }
}
