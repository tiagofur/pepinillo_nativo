// SyncClientTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for SyncClient capability gating.
// Verifies that all sync methods gate on capabilities.backendSync, NOT a legacy isProUser bool.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@MainActor
struct SyncClientTests {

    // MARK: - Helpers

    private func makeCapabilitiesAndSet(_ caps: UserCapabilities) {
        AppGroupDefaults.userCapabilities = caps
    }

    // MARK: - syncAll gating

    @Test("syncAll does not proceed when backendSync=false (Free)")
    func syncAllBlockedForFreeUser() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        makeCapabilitiesAndSet(.free)

        var apiCallCount = 0
        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in apiCallCount += 1; return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in apiCallCount += 1; return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in apiCallCount += 1; return PreferenceSyncResponse(preferences: []) }
            $0.persistenceClient.fetchDirtyTasks = { [] }
            $0.persistenceClient.fetchDirtySessions = { [] }
            $0.persistenceClient.getAllPreferencesAsKeyValue = { [] }
            $0.persistenceClient.getLastSyncTimestamp = { nil }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        #expect(apiCallCount == 0, "No API calls should be made when backendSync=false")
    }

    @Test("syncAll does not proceed when backendSync=false (PepinilloPlus)")
    func syncAllBlockedForPepinilloPlus() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        makeCapabilitiesAndSet(.pepinilloPlus)

        var apiCallCount = 0
        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in apiCallCount += 1; return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in apiCallCount += 1; return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in apiCallCount += 1; return PreferenceSyncResponse(preferences: []) }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        #expect(apiCallCount == 0, "PepinilloPlus (no backendSync) should not trigger API calls")
    }

    @Test("syncAll proceeds when backendSync=true (EverywhereePlus)")
    func syncAllProceedsForEverywherePlus() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        makeCapabilitiesAndSet(.everywherePlus)

        var syncTasksCalled = false
        var syncSessionsCalled = false
        var syncSettingsCalled = false

        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in syncTasksCalled = true; return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in syncSessionsCalled = true; return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in syncSettingsCalled = true; return PreferenceSyncResponse(preferences: []) }
            $0.persistenceClient.fetchDirtyTasks = { [] }
            $0.persistenceClient.fetchDirtySessions = { [] }
            $0.persistenceClient.getAllPreferencesAsKeyValue = { [] }
            $0.persistenceClient.getLastSyncTimestamp = { nil }
            $0.persistenceClient.getLastSessionSyncTimestamp = { nil }
            $0.persistenceClient.saveLastSyncTimestamp = { _ in }
            $0.persistenceClient.saveLastSessionSyncTimestamp = { _ in }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        #expect(syncTasksCalled, "syncTasks should be called for Everywhere+ users")
        #expect(syncSessionsCalled, "syncSessions should be called for Everywhere+ users")
        #expect(syncSettingsCalled, "syncSettings should be called for Everywhere+ users")
    }

    // MARK: - Legacy isProUser isolation (spec: "Legacy isProUser bool no longer read by SyncClient")

    @Test("SyncClient reads capabilities not legacy bool — backendSync=false wins even when capabilities say no-sync")
    func syncClientIgnoresLegacyBoolAndUsesCapabilities() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        // Set capabilities to PepinilloPlus (backendSync=false)
        makeCapabilitiesAndSet(.pepinilloPlus)

        var apiCallCount = 0
        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in apiCallCount += 1; return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in apiCallCount += 1; return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in apiCallCount += 1; return PreferenceSyncResponse(preferences: []) }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        // Capability says backendSync=false → should NOT proceed regardless of any legacy bool
        #expect(apiCallCount == 0, "Capability (backendSync=false) must win — no API calls")
    }
}
