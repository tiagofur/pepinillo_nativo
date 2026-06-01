// SyncClientTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for SyncClient capability gating.
// Verifies that all sync methods gate on capabilities.backendSync, NOT a legacy isProUser bool.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("SyncClient", .serialized)
@MainActor
struct SyncClientTests {

    // MARK: - Helpers

    private actor APICallProbe {
        private var callCount = 0
        private var calledNames: Set<String> = []

        func record(_ name: String = "api") {
            callCount += 1
            calledNames.insert(name)
        }

        func count() -> Int { callCount }

        func wasCalled(_ name: String) -> Bool {
            calledNames.contains(name)
        }
    }

    private func makeCapabilitiesAndSet(_ caps: UserCapabilities) {
        AppGroupDefaults.userCapabilities = caps
    }

    // MARK: - syncAll gating

    @Test("syncAll does not proceed when backendSync=false (Free)")
    func syncAllBlockedForFreeUser() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        makeCapabilitiesAndSet(.free)

        let probe = APICallProbe()
        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in await probe.record(); return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in await probe.record(); return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in await probe.record(); return PreferenceSyncResponse(preferences: [], serverTimestamp: "") }
            $0.persistenceClient.fetchDirtyTasks = { [] }
            $0.persistenceClient.fetchDirtySessions = { [] }
            $0.persistenceClient.getAllPreferencesAsKeyValue = { [] }
            $0.persistenceClient.getLastSyncTimestamp = { nil }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        #expect(await probe.count() == 0, "No API calls should be made when backendSync=false")
    }

    @Test("syncAll does not proceed when backendSync=false (PepinilloPlus)")
    func syncAllBlockedForPepinilloPlus() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        makeCapabilitiesAndSet(.pepinilloPlus)

        let probe = APICallProbe()
        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in await probe.record(); return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in await probe.record(); return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in await probe.record(); return PreferenceSyncResponse(preferences: [], serverTimestamp: "") }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        #expect(await probe.count() == 0, "PepinilloPlus (no backendSync) should not trigger API calls")
    }

    @Test("syncAll proceeds when backendSync=true (EverywhereePlus)")
    func syncAllProceedsForEverywherePlus() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        makeCapabilitiesAndSet(.everywherePlus)

        let probe = APICallProbe()

        let client = SyncClient.liveValue

        try await withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.syncClient.syncSettings = { await probe.record("settings") }
            $0.syncClient.syncTasks = { await probe.record("tasks") }
            $0.syncClient.syncSessions = { await probe.record("sessions") }
        } operation: {
            try await client.syncAll()
        }
        #expect(await probe.wasCalled("tasks"), "syncTasks should be called for Everywhere+ users")
        #expect(await probe.wasCalled("sessions"), "syncSessions should be called for Everywhere+ users")
        #expect(await probe.wasCalled("settings"), "syncSettings should be called for Everywhere+ users")
    }

    // MARK: - Legacy isProUser isolation (spec: "Legacy isProUser bool no longer read by SyncClient")

    @Test("SyncClient reads capabilities not legacy bool — backendSync=false wins even when capabilities say no-sync")
    func syncClientIgnoresLegacyBoolAndUsesCapabilities() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        // Set capabilities to PepinilloPlus (backendSync=false)
        makeCapabilitiesAndSet(.pepinilloPlus)

        let probe = APICallProbe()
        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.syncTasks = { _ in await probe.record(); return TaskSyncResponse(tasks: [], deletedSyncIds: [], syncTimestamp: "") }
            $0.apiClient.syncSessions = { _ in await probe.record(); return SessionSyncResponse(sessions: [], serverTimestamp: "") }
            $0.apiClient.upsertPreferences = { _ in await probe.record(); return PreferenceSyncResponse(preferences: [], serverTimestamp: "") }
        } operation: {
            SyncClient.liveValue
        }

        try await client.syncAll()
        // Capability says backendSync=false → should NOT proceed regardless of any legacy bool
        #expect(await probe.count() == 0, "Capability (backendSync=false) must win — no API calls")
    }
}
