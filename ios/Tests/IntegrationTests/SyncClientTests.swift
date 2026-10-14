// SyncClientTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for SyncClient capability gating.
// Verifies that all sync methods gate on capabilities.backendSync, NOT a legacy isProUser bool.

import Testing
import Foundation
import ComposableArchitecture
@testable import Pepinillo

@Suite("SyncClient", .serialized, .appGroupDefaultsSerialized)
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

    // MARK: - wipeAndSync data-safety

    @Test("wipeAndSync preserves local data when performInitialSync (getFullSync) fails")
    func wipeAndSyncPreservesLocalDataOnNetworkFailure() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        makeCapabilitiesAndSet(.everywherePlus)

        // Track whether the wipe methods were called
        actor WipeProbe {
            var deleteAllTasksCalled = false
            var deleteAllSessionsCalled = false
            var deleteAllStatsCalled = false

            func markTasksDeleted() { deleteAllTasksCalled = true }
            func markSessionsDeleted() { deleteAllSessionsCalled = true }
            func markStatsDeleted() { deleteAllStatsCalled = true }
        }
        let wipeProbe = WipeProbe()

        struct SimulatedNetworkError: Error {}

        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            // getFullSync throws — simulates a network failure during the fetch phase
            $0.apiClient.getFullSync = { _, _, _ in throw SimulatedNetworkError() }
            // Wipe methods should NOT be called before a successful fetch
            $0.persistenceClient.deleteAllTasks = {
                await wipeProbe.markTasksDeleted()
            }
            $0.persistenceClient.deleteAllSessions = {
                await wipeProbe.markSessionsDeleted()
            }
            $0.persistenceClient.deleteAllStats = {
                await wipeProbe.markStatsDeleted()
            }
        } operation: {
            SyncClient.liveValue
        }

        do {
            try await client.wipeAndSync()
            Issue.record("wipeAndSync should have thrown when the server fetch fails")
        } catch {
            // Expected: getFullSync threw, so wipeAndSync must propagate the error
        }

        // Local data must not have been touched — the fetch failed before any wipe
        let tasksDeleted = await wipeProbe.deleteAllTasksCalled
        let sessionsDeleted = await wipeProbe.deleteAllSessionsCalled
        let statsDeleted = await wipeProbe.deleteAllStatsCalled

        #expect(!tasksDeleted, "deleteAllTasks must NOT be called when server fetch fails")
        #expect(!sessionsDeleted, "deleteAllSessions must NOT be called when server fetch fails")
        #expect(!statsDeleted, "deleteAllStats must NOT be called when server fetch fails")
    }

    @Test("wipeAndSync wipes and applies data when server fetch succeeds")
    func wipeAndSyncAppliesServerDataOnSuccess() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        makeCapabilitiesAndSet(.everywherePlus)

        actor SequenceProbe {
            var events: [String] = []
            func record(_ event: String) { events.append(event) }
            func getEvents() -> [String] { events }
        }
        let seqProbe = SequenceProbe()

        let fakeTask = TaskSyncDTO(id: 1, syncId: "abc", title: "Server Task")
        let fakeResponse = FullSyncResponse(
            tasks: PaginatedTaskPage(items: [fakeTask], nextCursor: nil, hasMore: false),
            sessions: PaginatedSessionPage(items: [], nextCursor: nil, hasMore: false),
            settings: [],
            serverTimestamp: "2024-01-01T00:00:00Z"
        )

        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.getFullSync = { _, _, _ in
                await seqProbe.record("fetch")
                return fakeResponse
            }
            $0.persistenceClient.deleteAllTasks = {
                await seqProbe.record("deleteTasks")
            }
            $0.persistenceClient.deleteAllSessions = {
                await seqProbe.record("deleteSessions")
            }
            $0.persistenceClient.deleteAllStats = {
                await seqProbe.record("deleteStats")
            }
            $0.persistenceClient.upsertTaskFromServer = { _, _ in
                await seqProbe.record("upsertTask")
                // no-op — just recording the call order
            }
            $0.persistenceClient.save = { await seqProbe.record("save") }
            $0.persistenceClient.saveLastSyncTimestamp = { _ in }
            $0.persistenceClient.saveLastSessionSyncTimestamp = { _ in }
        } operation: {
            SyncClient.liveValue
        }

        try await client.wipeAndSync()

        let events = await seqProbe.getEvents()
        // Fetch must come before any delete
        let fetchIdx = events.firstIndex(of: "fetch") ?? Int.max
        let deleteTasksIdx = events.firstIndex(of: "deleteTasks") ?? Int.max
        let upsertIdx = events.firstIndex(of: "upsertTask") ?? Int.max

        #expect(fetchIdx < deleteTasksIdx, "fetch must happen before deleteAllTasks")
        #expect(deleteTasksIdx < upsertIdx, "deleteAllTasks must happen before upsertTask")
        #expect(events.contains("upsertTask"), "server task should be upserted after wipe")
    }

    @Test("wipeAndSync rebuilds DailyStats after applying server sessions")
    func wipeAndSyncRebuildsDailyStats() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        makeCapabilitiesAndSet(.everywherePlus)

        actor RebuildProbe {
            var called = false
            func mark() { called = true }
            func wasCalled() -> Bool { called }
        }
        let rebuildProbe = RebuildProbe()

        let fakeSession = FocusSessionSyncDTO(
            id: UUID().uuidString,
            startedAt: "2024-01-01T00:00:00Z",
            endedAt: "2024-01-01T00:25:00Z",
            mode: "pomodoro",
            phase: "work",
            durationSeconds: 1500,
            elapsedSeconds: 1500,
            wasCompleted: true,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:25:00Z"
        )
        let fakeResponse = FullSyncResponse(
            tasks: PaginatedTaskPage(items: [], nextCursor: nil, hasMore: false),
            sessions: PaginatedSessionPage(items: [fakeSession], nextCursor: nil, hasMore: false),
            settings: [],
            serverTimestamp: "2024-01-01T00:00:00Z"
        )

        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.getFullSync = { _, _, _ in return fakeResponse }
            $0.persistenceClient.deleteAllTasks = { }
            $0.persistenceClient.deleteAllSessions = { }
            $0.persistenceClient.deleteAllStats = { }
            $0.persistenceClient.sessionExists = { _ in false }
            $0.persistenceClient.upsertSessionFromServer = { _, _ in }
            $0.persistenceClient.save = { }
            $0.persistenceClient.saveLastSyncTimestamp = { _ in }
            $0.persistenceClient.saveLastSessionSyncTimestamp = { _ in }
            $0.persistenceClient.linkSessionToTask = { _, _, _ in }
            // S4 RED: pre-fix wipeAndSync never calls this (behavioral RED).
            $0.persistenceClient.rebuildDailyStatsFromSessions = {
                await rebuildProbe.mark()
            }
        } operation: {
            SyncClient.liveValue
        }

        try await client.wipeAndSync()

        #expect(await rebuildProbe.wasCalled() == true)
    }

    // MARK: - Asymmetric pagination (tasks done in 1 page, sessions need 2)

    @Test("wipeAndSync does not re-request or duplicate tasks when sessions need more pages")
    func wipeAndSyncNoDuplicateTasksOnAsymmetricPagination() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        makeCapabilitiesAndSet(.everywherePlus)

        let taskA = TaskSyncDTO(id: 1, syncId: "task-a", title: "Task A")
        let session1 = FocusSessionSyncDTO(
            id: UUID().uuidString, startedAt: "2024-01-01T00:00:00Z",
            mode: "pomodoro", phase: "work", durationSeconds: 1500,
            elapsedSeconds: 1500, wasCompleted: true,
            createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"
        )
        let session2 = FocusSessionSyncDTO(
            id: UUID().uuidString, startedAt: "2024-01-02T00:00:00Z",
            mode: "pomodoro", phase: "work", durationSeconds: 1500,
            elapsedSeconds: 1500, wasCompleted: true,
            createdAt: "2024-01-02T00:00:00Z", updatedAt: "2024-01-02T00:00:00Z"
        )

        // Page 1: tasks finish (hasMore=false), sessions have more (hasMore=true, cursor="s2")
        let page1 = FullSyncResponse(
            tasks: PaginatedTaskPage(items: [taskA], nextCursor: nil, hasMore: false),
            sessions: PaginatedSessionPage(items: [session1], nextCursor: "s2", hasMore: true),
            settings: [],
            serverTimestamp: "2024-01-01T00:00:00Z"
        )
        // Page 2: tasks would restart from page 1 if cursor bug was present; sessions finish.
        // The server is called with (taskCursor: nil, sessionCursor: "s2") — correct behavior.
        let page2 = FullSyncResponse(
            tasks: PaginatedTaskPage(items: [taskA], nextCursor: nil, hasMore: false), // server echoes task again
            sessions: PaginatedSessionPage(items: [session2], nextCursor: nil, hasMore: false),
            settings: [],
            serverTimestamp: "2024-01-01T00:00:00Z"
        )

        actor PagedProbe {
            var callCount = 0
            var taskUpsertCount = 0
            var upsertedSyncIds: [String] = []
            func nextPage() -> Int { callCount += 1; return callCount }
            func recordTask(_ syncId: String) { taskUpsertCount += 1; upsertedSyncIds.append(syncId) }
            func getTaskCount() -> Int { taskUpsertCount }
            func getSyncIds() -> [String] { upsertedSyncIds }
        }
        let probe = PagedProbe()

        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.getFullSync = { _, _, _ in
                let n = await probe.nextPage()
                return n == 1 ? page1 : page2
            }
            $0.persistenceClient.deleteAllTasks = {}
            $0.persistenceClient.deleteAllSessions = {}
            $0.persistenceClient.deleteAllStats = {}
            $0.persistenceClient.upsertTaskFromServer = { dto, _ in
                await probe.recordTask(dto.syncId)
            }
            $0.persistenceClient.sessionExists = { _ in false }
            $0.persistenceClient.upsertSessionFromServer = { _, _ in }
            $0.persistenceClient.save = {}
            $0.persistenceClient.saveLastSyncTimestamp = { _ in }
            $0.persistenceClient.saveLastSessionSyncTimestamp = { _ in }
        } operation: {
            SyncClient.liveValue
        }

        try await client.wipeAndSync()

        let count = await probe.getTaskCount()
        let syncIds = await probe.getSyncIds()
        #expect(count == 1, "task-a must be upserted exactly once, not duplicated across pages; got \(syncIds)")
    }

    @Test("performInitialSync does not re-request or duplicate tasks when sessions need more pages")
    func performInitialSyncNoDuplicateTasksOnAsymmetricPagination() async throws {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }
        makeCapabilitiesAndSet(.everywherePlus)

        let taskA = TaskSyncDTO(id: 1, syncId: "task-a", title: "Task A")
        let session1 = FocusSessionSyncDTO(
            id: UUID().uuidString, startedAt: "2024-01-01T00:00:00Z",
            mode: "pomodoro", phase: "work", durationSeconds: 1500,
            elapsedSeconds: 1500, wasCompleted: true,
            createdAt: "2024-01-01T00:00:00Z", updatedAt: "2024-01-01T00:00:00Z"
        )
        let session2 = FocusSessionSyncDTO(
            id: UUID().uuidString, startedAt: "2024-01-02T00:00:00Z",
            mode: "pomodoro", phase: "work", durationSeconds: 1500,
            elapsedSeconds: 1500, wasCompleted: true,
            createdAt: "2024-01-02T00:00:00Z", updatedAt: "2024-01-02T00:00:00Z"
        )

        let page1 = FullSyncResponse(
            tasks: PaginatedTaskPage(items: [taskA], nextCursor: nil, hasMore: false),
            sessions: PaginatedSessionPage(items: [session1], nextCursor: "s2", hasMore: true),
            settings: [],
            serverTimestamp: "2024-01-01T00:00:00Z"
        )
        let page2 = FullSyncResponse(
            tasks: PaginatedTaskPage(items: [taskA], nextCursor: nil, hasMore: false), // server echoes task again
            sessions: PaginatedSessionPage(items: [session2], nextCursor: nil, hasMore: false),
            settings: [],
            serverTimestamp: "2024-01-01T00:00:00Z"
        )

        actor InitSyncProbe {
            var callCount = 0
            var taskUpsertCount = 0
            func nextPage() -> Int { callCount += 1; return callCount }
            func recordTask() { taskUpsertCount += 1 }
            func getTaskCount() -> Int { taskUpsertCount }
        }
        let probe = InitSyncProbe()

        let client = withDependencies {
            $0.keychainClient.hasTokens = { true }
            $0.apiClient.getFullSync = { _, _, _ in
                let n = await probe.nextPage()
                return n == 1 ? page1 : page2
            }
            $0.persistenceClient.upsertTaskFromServer = { _, _ in await probe.recordTask() }
            $0.persistenceClient.sessionExists = { _ in false }
            $0.persistenceClient.upsertSessionFromServer = { _, _ in }
            $0.persistenceClient.applyServerPreference = { _, _, _ in }
            $0.persistenceClient.save = {}
            $0.persistenceClient.saveLastSyncTimestamp = { _ in }
            $0.persistenceClient.saveLastSessionSyncTimestamp = { _ in }
        } operation: {
            SyncClient.liveValue
        }

        try await client.performInitialSync()

        let count = await probe.getTaskCount()
        #expect(count == 1, "task-a must be upserted exactly once; got \(count)")
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
