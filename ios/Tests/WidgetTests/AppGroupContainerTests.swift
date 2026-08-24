// AppGroupContainerTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for AppGroupDefaults capability read/write.
// Verifies that userCapabilities can be stored and retrieved from shared UserDefaults.

import Testing
import Foundation
import SwiftData
@testable import Pepinillo

@Suite("AppGroupContainerTests", .serialized, .appGroupDefaultsSerialized)
struct AppGroupContainerTests {

    @Test("userCapabilities round-trips through AppGroupDefaults")
    func userCapabilitiesRoundTrip() {
        let original = UserCapabilities.everywherePlus
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = original
        let read = AppGroupDefaults.userCapabilities
        #expect(read == original)
    }

    @Test("userCapabilities defaults to nil when unset")
    func userCapabilitiesDefaultsNilWhenUnset() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.subscriptionTierIdentifier = "everywhere_plus"
        AppGroupDefaults.userCapabilities = nil
        #expect(AppGroupDefaults.userCapabilities == nil)
        #expect(AppGroupDefaults.subscriptionTierIdentifier == nil)
    }

    @Test("userCapabilities stores pepinilloPlus preset")
    func userCapabilitiesStoresPepinilloPlus() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .pepinilloPlus
        let read = AppGroupDefaults.userCapabilities
        #expect(read?.backendSync == false)
        #expect(read?.localPremium == true)
        #expect(AppGroupDefaults.canBackendSync == false)
        #expect(AppGroupDefaults.canAppleCloudSync == true)
    }

    @Test("userCapabilities stores free preset")
    func userCapabilitiesStoresFreePreset() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .free
        let read = AppGroupDefaults.userCapabilities
        #expect(read?.backendSync == false)
        #expect(read?.localPremium == false)
        #expect(read?.hasAnyPremium == false)
    }

    @Test("userCapabilities stores everywherePlus backendSync=true")
    func userCapabilitiesStoresEverywhereSync() {
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = .everywherePlus
        let read = AppGroupDefaults.userCapabilities
        #expect(read?.backendSync == true)
        #expect(read?.hasAnyPremium == true)
        #expect(AppGroupDefaults.canBackendSync == true)
        #expect(AppGroupDefaults.canAppleCloudSync == false)
    }

    @Test("sync mode flags round-trip")
    func syncModeFlagsRoundTrip() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.activeSyncMode = .appleCloud
        AppGroupDefaults.syncStatus = .appleCloudUnavailable
        AppGroupDefaults.lastAppleCloudActivationError = "iCloud unavailable"

        #expect(AppGroupDefaults.activeSyncMode == .appleCloud)
        #expect(AppGroupDefaults.syncStatus == .appleCloudUnavailable)
        #expect(AppGroupDefaults.lastAppleCloudActivationError == "iCloud unavailable")
    }

    @Test("subscription verification dates round-trip")
    func subscriptionVerificationDatesRoundTrip() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        let now = Date()
        AppGroupDefaults.subscriptionTierIdentifier = "everywhere_plus"
        AppGroupDefaults.lastVerifiedDate = now
        AppGroupDefaults.subscriptionExpirationDate = now.addingTimeInterval(3600)
        #expect(AppGroupDefaults.subscriptionTierIdentifier == "everywhere_plus")
        #expect(AppGroupDefaults.lastVerifiedDate == now)
        #expect(AppGroupDefaults.subscriptionExpirationDate == now.addingTimeInterval(3600))

        AppGroupDefaults.subscriptionTierIdentifier = nil
        AppGroupDefaults.lastVerifiedDate = nil
        AppGroupDefaults.subscriptionExpirationDate = nil
        #expect(AppGroupDefaults.subscriptionTierIdentifier == nil)
        #expect(AppGroupDefaults.lastVerifiedDate == nil)
        #expect(AppGroupDefaults.subscriptionExpirationDate == nil)
    }


    @Test("extensionModelStoreURL maps activeSyncMode to the correct SQLite file")
    func extensionStoreURLSelection() {
        #expect(extensionModelStoreURL(for: .local).lastPathComponent == AppGroup.storeFileName)
        #expect(extensionModelStoreURL(for: .backend).lastPathComponent == AppGroup.storeFileName)
        #expect(extensionModelStoreURL(for: .appleCloud).lastPathComponent == AppGroup.appleCloudStoreFileName)
        #expect(extensionModelStoreURL(for: .local) == AppGroup.storeURL)
        #expect(extensionModelStoreURL(for: .appleCloud) == AppGroup.appleCloudStoreURL)
    }

    @Test("extension container cache invalidates when activeSyncMode changes")
    func extensionContainerCacheInvalidatesOnSyncModeChange() throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        defer { resetExtensionModelContainerCacheForTesting() }

        AppGroupDefaults.activeSyncMode = .local
        let localContainer = try makeWidgetModelContainer()

        AppGroupDefaults.activeSyncMode = .appleCloud
        let appleCloudContainer = try makeWidgetModelContainer()

        #expect(ObjectIdentifier(localContainer) != ObjectIdentifier(appleCloudContainer))
    }

    @Test("widget duration cache falls back when stored value is zero")
    func widgetDurationCacheFallsBackWhenZero() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.pomodoroDuration = 0
        AppGroupDefaults.blockDuration = 0

        #expect(AppGroupDefaults.pomodoroDuration == 25 * 60)
        #expect(AppGroupDefaults.blockDuration == 60 * 60)
    }

    @Test("widget-started sessions use cached settings durations")
    func widgetStartedSessionsUseCachedSettingsDurations() throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_100_000)
        AppGroupDefaults.pomodoroDuration = 45 * 60
        AppGroupDefaults.blockDuration = 90 * 60

        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        let pomodoroEnd = try #require(AppGroupDefaults.activeSessionTimerEnd)
        #expect(abs(pomodoroEnd.timeIntervalSince(issuedAt) - 45 * 60) < 1)

        AppGroupDefaults.startWidgetSession(modeID: "timeBlock", issuedAt: issuedAt)
        let blockEnd = try #require(AppGroupDefaults.activeSessionTimerEnd)
        #expect(abs(blockEnd.timeIntervalSince(issuedAt) - 90 * 60) < 1)
    }

    @Test("StartFocusFromWidgetIntent writes a complete widget-started session")
    func startFocusFromWidgetIntentWritesActiveSession() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.isProUser = false
        AppGroupDefaults.pomodoroDuration = 25 * 60

        let before = Date.now
        _ = try await StartFocusFromWidgetIntent(modeID: "pomodoro").perform()
        let after = Date.now

        #expect(StartFocusFromWidgetIntent.openAppWhenRun == false)
        #expect(AppGroupDefaults.externalStartRequested == true)
        #expect(AppGroupDefaults.externalCommandID != nil)
        #expect(AppGroupDefaults.externalCommandIssuedAt != nil)
        #expect(AppGroupDefaults.isSessionActive == true)
        #expect(AppGroupDefaults.activeSessionStartedFromWidget == true)
        #expect(AppGroupDefaults.activeModeName == "pomodoro")
        #expect(AppGroupDefaults.requestedMode == "pomodoro")
        #expect(AppGroupDefaults.activeSessionPomodoroNumber == 1)
        #expect(AppGroupDefaults.activeSessionProgress == 0)

        let timerStart = try #require(AppGroupDefaults.activeSessionTimerStart)
        let timerEnd = try #require(AppGroupDefaults.activeSessionTimerEnd)
        #expect(timerStart >= before && timerStart <= after)
        #expect(abs(timerEnd.timeIntervalSince(timerStart) - 25 * 60) < 1)
    }

    @Test("ghost session reconcile clears stale App Group snapshot when engine is idle")
    func ghostSessionReconcileClearsStaleSnapshot() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_200_000)
        AppGroupDefaults.isSessionActive = true
        AppGroupDefaults.activeModeName = "pomodoro"
        AppGroupDefaults.activeSessionTimerStart = issuedAt
        AppGroupDefaults.activeSessionTimerEnd = issuedAt.addingTimeInterval(25 * 60)
        AppGroupDefaults.externalStartRequested = false

        let cleared = AppGroupDefaults.SessionReconcilePolicy.clearGhostSessionIfNeeded(engineIsRunning: false)
        #expect(cleared == true)
        #expect(AppGroupDefaults.isSessionActive == false)
        #expect(AppGroupDefaults.activeModeName == nil)
        #expect(AppGroupDefaults.activeSessionTimerStart == nil)
        #expect(AppGroupDefaults.activeSessionTimerEnd == nil)
    }

    @Test("ghost session reconcile preserves widget restore path when external start is pending")
    func ghostSessionReconcilePreservesPendingExternalStart() throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.pomodoroDuration = 25 * 60

        let issuedAt = Date(timeIntervalSince1970: 1_800_200_100)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)

        let cleared = AppGroupDefaults.SessionReconcilePolicy.clearGhostSessionIfNeeded(engineIsRunning: false)
        #expect(cleared == false)
        #expect(AppGroupDefaults.isSessionActive == true)
        #expect(AppGroupDefaults.externalStartRequested == true)
        let timerStart = try #require(AppGroupDefaults.activeSessionTimerStart)
        #expect(timerStart == issuedAt)
    }

    @Test("ghost session reconcile is a no-op when the engine is running")
    func ghostSessionReconcileSkipsWhenEngineIsRunning() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        AppGroupDefaults.isSessionActive = true
        AppGroupDefaults.activeModeName = "pomodoro"

        let cleared = AppGroupDefaults.SessionReconcilePolicy.clearGhostSessionIfNeeded(engineIsRunning: true)
        #expect(cleared == false)
        #expect(AppGroupDefaults.isSessionActive == true)
        #expect(AppGroupDefaults.activeModeName == "pomodoro")
    }

    @Test("requestExternalPause freezes elapsed, remaining, and command anchors")
    func requestExternalPauseWritesPauseProtocol() throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_300_000)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = false

        let pauseAt = issuedAt.addingTimeInterval(90)
        let paused = AppGroupDefaults.requestExternalPause(at: pauseAt)

        #expect(paused == true)
        #expect(AppGroupDefaults.externalPauseRequested == true)
        #expect(AppGroupDefaults.externalResumeRequested == false)
        #expect(AppGroupDefaults.activeSessionIsPaused == true)
        #expect(AppGroupDefaults.externalCommandID != nil)
        #expect(AppGroupDefaults.externalCommandIssuedAt == pauseAt)
        #expect(AppGroupDefaults.activeSessionPausedAt == pauseAt)
        #expect(AppGroupDefaults.activeSessionElapsed == 90)
        #expect(AppGroupDefaults.activeSessionRemaining == (25 * 60) - 90)
        #expect(AppGroupDefaults.activeSessionProgress != nil)
    }

    @Test("requestExternalResume re-anchors timers and clears pause state")
    func requestExternalResumeWritesResumeProtocol() throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_300_100)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = false

        let pauseAt = issuedAt.addingTimeInterval(120)
        #expect(AppGroupDefaults.requestExternalPause(at: pauseAt) == true)
        AppGroupDefaults.clearExternalCommands()

        let resumeAt = pauseAt.addingTimeInterval(30)
        let resumed = AppGroupDefaults.requestExternalResume(at: resumeAt)

        #expect(resumed == true)
        #expect(AppGroupDefaults.externalResumeRequested == true)
        #expect(AppGroupDefaults.externalPauseRequested == false)
        #expect(AppGroupDefaults.activeSessionIsPaused == false)
        #expect(AppGroupDefaults.activeSessionPausedAt == nil)
        #expect(AppGroupDefaults.externalCommandIssuedAt == resumeAt)
        #expect(AppGroupDefaults.activeSessionRemaining == nil)

        let timerStart = try #require(AppGroupDefaults.activeSessionTimerStart)
        let timerEnd = try #require(AppGroupDefaults.activeSessionTimerEnd)
        #expect(timerStart == resumeAt.addingTimeInterval(-120))
        #expect(timerEnd == resumeAt.addingTimeInterval((25 * 60) - 120))
    }

    @Test("Tasks widget start action enforces every entitlement state")
    func tasksWidgetStartActionEntitlementMatrix() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        let now = Date.now
        var unknown = UserCapabilities.pepinilloPlus
        unknown.localAI = false
        let cases: [(String?, UserCapabilities?, Date?, Date?, Bool)] = [
            (nil, nil, nil, nil, false), ("free", .free, now, nil, false),
            ("pepinillo_plus", .pepinilloPlus, nil, nil, true), ("everywhere_plus", .everywherePlus, now, nil, true),
            ("everywhere_plus", .everywherePlus, nil, nil, false), ("everywhere_plus", .everywherePlus, now, now.addingTimeInterval(-1), false),
            ("everywhere_plus", .everywherePlus, now.addingTimeInterval(-TasksWidgetAccess.everywhereOfflineGracePeriod), nil, false),
            ("everywhere_plus", .everywherePlus, now.addingTimeInterval(1), nil, false), ("pepinillo_plus", unknown, nil, nil, false),
        ]

        for (tier, capabilities, lastVerifiedDate, expirationDate, isAllowed) in cases {
            AppGroupDefaults.clearExternalCommands()
            AppGroupDefaults.clearActiveSession()
            AppGroupDefaults.userCapabilities = capabilities
            AppGroupDefaults.subscriptionTierIdentifier = tier
            AppGroupDefaults.lastVerifiedDate = lastVerifiedDate
            AppGroupDefaults.subscriptionExpirationDate = expirationDate
            AppGroupDefaults.widgetSelectedMode = "pomodoro"

            _ = try await StartFocusFromTasksWidgetIntent().perform()

            #expect(AppGroupDefaults.externalStartRequested == isAllowed)
            #expect(AppGroupDefaults.isSessionActive == isAllowed)
        }
    }

    @Test("StartFocusWithTaskIntent fails closed for free users")
    func startFocusWithTaskIntentFailsClosedForFreeUser() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.userCapabilities = .free
        AppGroupDefaults.subscriptionTierIdentifier = "free"
        AppGroupDefaults.lastVerifiedDate = nil
        AppGroupDefaults.isProUser = false
        AppGroupDefaults.widgetSelectedMode = "flowtime"

        let taskID = UUID().uuidString
        _ = try await StartFocusWithTaskIntent(taskID: taskID).perform()

        #expect(AppGroupDefaults.externalStartRequested == false)
        #expect(AppGroupDefaults.isSessionActive == false)
        #expect(AppGroupDefaults.requestedMode == nil)
        #expect(AppGroupDefaults.requestedTaskID == nil)
    }

    @Test("StartFocusWithTaskIntent preserves the task and creates a widget-started session")
    func startFocusWithTaskIntentWritesTaskSession() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.userCapabilities = .pepinilloPlus
        AppGroupDefaults.subscriptionTierIdentifier = "pepinillo_plus"
        AppGroupDefaults.lastVerifiedDate = nil
        AppGroupDefaults.isProUser = true
        AppGroupDefaults.widgetSelectedMode = "pomodoro"
        AppGroupDefaults.pomodoroDuration = 25 * 60

        let taskID = UUID().uuidString
        _ = try await StartFocusWithTaskIntent(taskID: taskID).perform()

        #expect(StartFocusWithTaskIntent.openAppWhenRun == false)
        #expect(AppGroupDefaults.externalStartRequested == true)
        #expect(AppGroupDefaults.externalCommandID != nil)
        #expect(AppGroupDefaults.isSessionActive == true)
        #expect(AppGroupDefaults.activeSessionStartedFromWidget == true)
        #expect(AppGroupDefaults.activeModeName == "pomodoro")
        #expect(AppGroupDefaults.requestedTaskID == taskID)
        #expect(AppGroupDefaults.activeTaskID == taskID)
        #expect(AppGroupDefaults.activeSessionTimerStart != nil)
        #expect(AppGroupDefaults.activeSessionTimerEnd != nil)
    }

    @Test("CompleteTaskFromWidgetIntent cannot bypass entitlement")
    func completeTaskFromWidgetIntentCannotBypassEntitlement() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        defer { resetExtensionModelContainerCacheForTesting() }

        AppGroupDefaults.activeSyncMode = .local
        resetExtensionModelContainerCacheForTesting()
        let container = try makeWidgetModelContainer()
        let context = ModelContext(container)
        let task = TaskItem(title: "Entitlement boundary task")
        let taskID = task.id
        context.insert(task)
        try context.save()
        func storedTask(in context: ModelContext) throws -> TaskItem {
            try #require(context.fetch(
                FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == taskID })
            ).first)
        }
        defer {
            let cleanup = ModelContext(container)
            if let stored = try? storedTask(in: cleanup) {
                cleanup.delete(stored)
                try? cleanup.save()
            }
        }

        AppGroupDefaults.userCapabilities = .free
        AppGroupDefaults.subscriptionTierIdentifier = "free"
        AppGroupDefaults.lastVerifiedDate = nil
        _ = try await CompleteTaskFromWidgetIntent(taskID: taskID.uuidString).perform()
        #expect(try !storedTask(in: ModelContext(container)).isCompleted)

        AppGroupDefaults.userCapabilities = .pepinilloPlus
        AppGroupDefaults.subscriptionTierIdentifier = "pepinillo_plus"
        _ = try await CompleteTaskFromWidgetIntent(taskID: taskID.uuidString).perform()
        #expect(try storedTask(in: ModelContext(container)).isCompleted)
    }

    @Test("queueExternalStart blocks premium modes without ghost session (#220)")
    func queueExternalStartProGate() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.isProUser = false

        let allowed = AppGroupDefaults.queueExternalStart(modeID: "flowtime")
        #expect(allowed == false)
        #expect(AppGroupDefaults.externalStartRequested == true)
        #expect(AppGroupDefaults.isSessionActive == false)
    }

    @Test("discardStaleExternalCommandsIfNeeded clears expired commands (#221)")
    func discardStaleExternalCommands() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = true
        AppGroupDefaults.externalCommandIssuedAt = Date.now.addingTimeInterval(-600)
        AppGroupDefaults.isSessionActive = true

        AppGroupDefaults.discardStaleExternalCommandsIfNeeded()

        #expect(AppGroupDefaults.externalStartRequested == false)
        #expect(AppGroupDefaults.isSessionActive == false)
    }
}

struct AppGroupDefaultsSnapshot {
    var userCapabilities: UserCapabilities?
    var isProUser: Bool
    var canBackendSync: Bool
    var canAppleCloudSync: Bool
    var activeSyncMode: AppGroupDefaults.SyncMode
    var syncStatus: AppGroupDefaults.SyncStatus
    var lastAppleCloudActivationError: String?
    var lastVerifiedDate: Date?
    var subscriptionExpirationDate: Date?
    var subscriptionTierIdentifier: String?
    var widgetSelectedMode: String?
    var pomodoroDuration: Double
    var blockDuration: Double
    var isSessionActive: Bool
    var externalStartRequested: Bool
    var externalStopRequested: Bool
    var externalPauseRequested: Bool
    var externalResumeRequested: Bool
    var externalCommandID: String?
    var externalCommandIssuedAt: Date?
    var requestedMode: String?
    var requestedTaskID: String?
    var activeModeName: String?
    var activeSessionElapsed: Double
    var activeSessionRemaining: Double?
    var activeSessionPhase: String?
    var activeSessionProgress: Double?
    var activeSessionPomodoroNumber: Int?
    var activeSessionTotalPomodoros: Int?
    var activeSessionTaskTitle: String?
    var activeSessionIsPaused: Bool
    var activeSessionStartedFromWidget: Bool
    var activeSessionPausedAt: Date?
    var activeTaskID: String?
    var activeSessionTimerStart: Date?
    var activeSessionTimerEnd: Date?

    static func capture() -> Self {
        Self(
            userCapabilities: AppGroupDefaults.userCapabilities,
            isProUser: AppGroupDefaults.isProUser,
            canBackendSync: AppGroupDefaults.canBackendSync,
            canAppleCloudSync: AppGroupDefaults.canAppleCloudSync,
            activeSyncMode: AppGroupDefaults.activeSyncMode,
            syncStatus: AppGroupDefaults.syncStatus,
            lastAppleCloudActivationError: AppGroupDefaults.lastAppleCloudActivationError,
            lastVerifiedDate: AppGroupDefaults.lastVerifiedDate,
            subscriptionExpirationDate: AppGroupDefaults.subscriptionExpirationDate,
            subscriptionTierIdentifier: AppGroupDefaults.subscriptionTierIdentifier,
            widgetSelectedMode: AppGroupDefaults.widgetSelectedMode,
            pomodoroDuration: AppGroupDefaults.pomodoroDuration,
            blockDuration: AppGroupDefaults.blockDuration,
            isSessionActive: AppGroupDefaults.isSessionActive,
            externalStartRequested: AppGroupDefaults.externalStartRequested,
            externalStopRequested: AppGroupDefaults.externalStopRequested,
            externalPauseRequested: AppGroupDefaults.externalPauseRequested,
            externalResumeRequested: AppGroupDefaults.externalResumeRequested,
            externalCommandID: AppGroupDefaults.externalCommandID,
            externalCommandIssuedAt: AppGroupDefaults.externalCommandIssuedAt,
            requestedMode: AppGroupDefaults.requestedMode,
            requestedTaskID: AppGroupDefaults.requestedTaskID,
            activeModeName: AppGroupDefaults.activeModeName,
            activeSessionElapsed: AppGroupDefaults.activeSessionElapsed,
            activeSessionRemaining: AppGroupDefaults.activeSessionRemaining,
            activeSessionPhase: AppGroupDefaults.activeSessionPhase,
            activeSessionProgress: AppGroupDefaults.activeSessionProgress,
            activeSessionPomodoroNumber: AppGroupDefaults.activeSessionPomodoroNumber,
            activeSessionTotalPomodoros: AppGroupDefaults.activeSessionTotalPomodoros,
            activeSessionTaskTitle: AppGroupDefaults.activeSessionTaskTitle,
            activeSessionIsPaused: AppGroupDefaults.activeSessionIsPaused,
            activeSessionStartedFromWidget: AppGroupDefaults.activeSessionStartedFromWidget,
            activeSessionPausedAt: AppGroupDefaults.activeSessionPausedAt,
            activeTaskID: AppGroupDefaults.activeTaskID,
            activeSessionTimerStart: AppGroupDefaults.activeSessionTimerStart,
            activeSessionTimerEnd: AppGroupDefaults.activeSessionTimerEnd
        )
    }

    func restore() {
        AppGroupDefaults.userCapabilities = userCapabilities
        AppGroupDefaults.isProUser = isProUser
        AppGroupDefaults.canBackendSync = canBackendSync
        AppGroupDefaults.canAppleCloudSync = canAppleCloudSync
        AppGroupDefaults.activeSyncMode = activeSyncMode
        AppGroupDefaults.syncStatus = syncStatus
        AppGroupDefaults.lastAppleCloudActivationError = lastAppleCloudActivationError
        AppGroupDefaults.lastVerifiedDate = lastVerifiedDate
        AppGroupDefaults.subscriptionExpirationDate = subscriptionExpirationDate
        AppGroupDefaults.subscriptionTierIdentifier = subscriptionTierIdentifier
        AppGroupDefaults.widgetSelectedMode = widgetSelectedMode
        AppGroupDefaults.pomodoroDuration = pomodoroDuration
        AppGroupDefaults.blockDuration = blockDuration
        AppGroupDefaults.isSessionActive = isSessionActive
        AppGroupDefaults.externalStartRequested = externalStartRequested
        AppGroupDefaults.externalStopRequested = externalStopRequested
        AppGroupDefaults.externalPauseRequested = externalPauseRequested
        AppGroupDefaults.externalResumeRequested = externalResumeRequested
        AppGroupDefaults.externalCommandID = externalCommandID
        AppGroupDefaults.externalCommandIssuedAt = externalCommandIssuedAt
        AppGroupDefaults.requestedMode = requestedMode
        AppGroupDefaults.requestedTaskID = requestedTaskID
        AppGroupDefaults.activeModeName = activeModeName
        AppGroupDefaults.activeSessionElapsed = activeSessionElapsed
        AppGroupDefaults.activeSessionRemaining = activeSessionRemaining
        AppGroupDefaults.activeSessionPhase = activeSessionPhase
        AppGroupDefaults.activeSessionProgress = activeSessionProgress
        AppGroupDefaults.activeSessionPomodoroNumber = activeSessionPomodoroNumber
        AppGroupDefaults.activeSessionTotalPomodoros = activeSessionTotalPomodoros
        AppGroupDefaults.activeSessionTaskTitle = activeSessionTaskTitle
        AppGroupDefaults.activeSessionIsPaused = activeSessionIsPaused
        AppGroupDefaults.activeSessionStartedFromWidget = activeSessionStartedFromWidget
        AppGroupDefaults.activeSessionPausedAt = activeSessionPausedAt
        AppGroupDefaults.activeTaskID = activeTaskID
        AppGroupDefaults.activeSessionTimerStart = activeSessionTimerStart
        AppGroupDefaults.activeSessionTimerEnd = activeSessionTimerEnd
    }
}

// MARK: - Cross-suite serialization for shared App Group UserDefaults

/// Mutual exclusion across suites that touch `AppGroupDefaults`.
///
/// `.serialized` only orders tests within a single suite; Swift Testing still
/// runs different suites in parallel in the same process, and every test that
/// touches `AppGroupDefaults` reads and writes the same real
/// `UserDefaults(suiteName: AppGroup.id)` plist. Without this trait, a test
/// like `widgetColdStartNoCapabilitiesDefaultsFree` can clear capabilities and
/// then observe a value written concurrently by another suite.
///
/// Apply to every suite that mutates App Group state, alongside `.serialized`.
struct AppGroupDefaultsSerialTrait: TestTrait, SuiteTrait, TestScoping {
    var isRecursive: Bool { true }

    private static let gate = Gate()
    @TaskLocal private static var isHoldingGate = false

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        // Re-entrancy guard: if the trait ends up applied at both suite and
        // test level, the inner application must not acquire the gate again.
        guard Self.isHoldingGate == false else {
            try await function()
            return
        }
        await Self.gate.acquire()
        defer { Self.gate.release() }
        try await Self.$isHoldingGate.withValue(true) {
            try await function()
        }
    }

    /// Minimal async mutex: suspends waiting tests instead of blocking
    /// cooperative-pool threads (an `NSLock` held across `await` is unsafe).
    private final class Gate: @unchecked Sendable {
        private let lock = NSLock()
        private var isLocked = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func acquire() async {
            // NSLock is unavailable directly in async contexts; the
            // continuation closure is synchronous, so locking happens there.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                if isLocked == false {
                    isLocked = true
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append(continuation)
                    lock.unlock()
                }
            }
        }

        func release() {
            lock.lock()
            if waiters.isEmpty {
                isLocked = false
                lock.unlock()
            } else {
                let next = waiters.removeFirst()
                lock.unlock()
                next.resume()
            }
        }
    }
}

extension Trait where Self == AppGroupDefaultsSerialTrait {
    /// Serializes this suite against every other suite carrying the same trait.
    static var appGroupDefaultsSerialized: Self { Self() }
}
