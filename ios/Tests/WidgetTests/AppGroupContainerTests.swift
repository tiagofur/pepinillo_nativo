// AppGroupContainerTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for AppGroupDefaults capability read/write.
// Verifies that userCapabilities can be stored and retrieved from shared UserDefaults.

import Testing
import Foundation
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

    @Test("CompleteTaskFromWidgetIntent enqueues a command without touching the store")
    func completeTaskIntentEnqueuesCommand() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalCompleteTaskRequested = false
        AppGroupDefaults.externalCompleteTaskID = nil

        let taskID = UUID().uuidString
        _ = try await CompleteTaskFromWidgetIntent(taskID: taskID).perform()

        // S7 RED pre-fix: the intent wrote SwiftData directly and set no command.
        #expect(AppGroupDefaults.externalCompleteTaskRequested == true)
        #expect(AppGroupDefaults.externalCompleteTaskID == taskID)
        #expect(AppGroupDefaults.externalCommandID != nil)
        #expect(AppGroupDefaults.externalCommandIssuedAt != nil)

    @Test("CompleteTaskFromWidgetIntent cannot bypass entitlement")
    func completeTaskFromWidgetIntentCannotBypassEntitlement() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        let now = Date.now
        let taskID = UUID()
        AppGroupDefaults.userCapabilities = .free
        AppGroupDefaults.subscriptionTierIdentifier = "free"
        #expect(CompleteTaskFromWidgetIntent.authorizedTaskID(taskID.uuidString, now: now) == nil)
        AppGroupDefaults.userCapabilities = .pepinilloPlus
        AppGroupDefaults.subscriptionTierIdentifier = "pepinillo_plus"
        #expect(CompleteTaskFromWidgetIntent.authorizedTaskID(taskID.uuidString, now: now) == taskID)
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

    // MARK: - Ghost abandonment persistence (S5)

    @Test("ghost validator ignores inactive sessions and waiting holds")
    func ghostValidatorIgnoresInactiveAndWaiting() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        let start = now.addingTimeInterval(-900)
        let end = start.addingTimeInterval(1500)
        #expect(AppGroupDefaults.SessionReconcilePolicy.validatedGhostSnapshot(
            isSessionActive: false, isWaiting: false, modeName: "pomodoro",
            elapsed: 900, timerStart: start, timerEnd: end,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now) == nil)
        // A waiting hold already completed its phase: nothing new to persist.
        #expect(AppGroupDefaults.SessionReconcilePolicy.validatedGhostSnapshot(
            isSessionActive: true, isWaiting: true, modeName: "pomodoro",
            elapsed: 900, timerStart: start, timerEnd: end,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now) == nil)
    }

    @Test("ghost validator drops trivial sub-minute ghosts")
    func ghostValidatorDropsTrivialGhosts() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        #expect(AppGroupDefaults.SessionReconcilePolicy.validatedGhostSnapshot(
            isSessionActive: true, isWaiting: false, modeName: "pomodoro",
            elapsed: 59, timerStart: now.addingTimeInterval(-59), timerEnd: nil,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now) == nil)
        let kept = AppGroupDefaults.SessionReconcilePolicy.validatedGhostSnapshot(
            isSessionActive: true, isWaiting: false, modeName: "pomodoro",
            elapsed: 61, timerStart: now.addingTimeInterval(-61), timerEnd: nil,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now)
        #expect(kept != nil)
    }

    @Test("ghost validator clamps elapsed to the timer anchors")
    func ghostValidatorClampsToAnchors() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        // Elapsed claims 99999s but the timer started 100s ago.
        let clamped = AppGroupDefaults.SessionReconcilePolicy.validatedGhostSnapshot(
            isSessionActive: true, isWaiting: false, modeName: "flowtime",
            elapsed: 99999, timerStart: now.addingTimeInterval(-100), timerEnd: nil,
            pomodoroNumber: nil, totalPomodoros: nil, taskID: nil, now: now)
        #expect(abs((clamped?.actualDuration ?? -1) - 100) < 1)
        #expect(clamped?.targetDuration == nil)
        // Timer start in the future clamps to zero → trivial → nil.
        #expect(AppGroupDefaults.SessionReconcilePolicy.validatedGhostSnapshot(
            isSessionActive: true, isWaiting: false, modeName: "pomodoro",
            elapsed: 600, timerStart: now.addingTimeInterval(60), timerEnd: nil,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now) == nil)
    }

    @Test("ghost snapshot maps to an abandoned pomodoro record")
    func ghostSnapshotMapsToAbandonedRecord() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        let taskID = UUID()
        let snapshot = GhostSessionSnapshot(
            modeName: "pomodoro",
            startedAt: now.addingTimeInterval(-600),
            endedAt: now,
            targetDuration: 1500,
            actualDuration: 600,
            pomodoroNumber: 2,
            totalPomodoros: 4,
            taskID: taskID.uuidString
        )
        let result = FocusSessionResult(ghost: snapshot)
        #expect(result.mode == .pomodoro)
        #expect(result.phase == .work(number: 2, total: 4))
        #expect(result.wasCompleted == false)
        #expect(result.actualDuration == 600)
        #expect(result.totalFocusSeconds == 600)
        #expect(result.isHoldStop == false)
        #expect(result.pomodoroNumber == 2)
        #expect(result.linkedTaskID == taskID)
        #expect(result.targetDuration == 1500)
    }

    @Test("ghost snapshot falls back to pomodoro for unknown modes")
    func ghostSnapshotFallsBackForUnknownMode() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        let unknown = GhostSessionSnapshot(
            modeName: "sauna",
            startedAt: now.addingTimeInterval(-600),
            endedAt: now,
            targetDuration: nil,
            actualDuration: 600,
            pomodoroNumber: nil,
            totalPomodoros: nil,
            taskID: "not-a-uuid"
        )
        let fallback = FocusSessionResult(ghost: unknown)
        #expect(fallback.mode == .pomodoro)
        #expect(fallback.phase == .work(number: 1, total: 4))
        #expect(fallback.linkedTaskID == nil)

        let flow = GhostSessionSnapshot(
            modeName: "flowtime",
            startedAt: now.addingTimeInterval(-600),
            endedAt: now,
            targetDuration: nil,
            actualDuration: 600,
            pomodoroNumber: nil,
            totalPomodoros: nil,
            taskID: nil
        )
        #expect(FocusSessionResult(ghost: flow).phase == .flow)
    }

    @Test("ghost reader snapshots a staged ghost without clearing")
    func ghostReaderSnapshotsStagedGhost() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.isSessionActive = true
        AppGroupDefaults.activeModeName = "flowtime"
        AppGroupDefaults.activeSessionElapsed = 600
        AppGroupDefaults.activeSessionTimerStart = Date.now.addingTimeInterval(-600)
        AppGroupDefaults.externalStartRequested = false

        let snapshot = AppGroupDefaults.SessionReconcilePolicy.ghostSnapshotIfNeeded(engineIsRunning: false)
        #expect(snapshot?.modeName == "flowtime")
        #expect(abs((snapshot?.actualDuration ?? -1) - 600) < 1)
        // The reader never clears; the reconcile step owns clearing.
        #expect(AppGroupDefaults.isSessionActive == true)
    }

    // MARK: - Stale external-start backfill (S6)

    @Test("stale external start with fully served window backfills completed")
    func staleStartWithServedWindowBackfillsCompleted() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.pomodoroDuration = 25 * 60
        let taskID = UUID()
        // Widget pomodoro issued 30 min ago: 25-min window fully served.
        AppGroupDefaults.startWidgetSession(
            modeID: "pomodoro",
            taskID: taskID.uuidString,
            issuedAt: Date.now.addingTimeInterval(-1800)
        )

        let backfill = AppGroupDefaults.SessionReconcilePolicy.takeStaleExternalStartBackfill()
        #expect(backfill?.wasCompleted == true)
        #expect(backfill?.actualDuration == 1500)
        #expect(backfill?.targetDuration == 1500)
        #expect(backfill?.modeName == "pomodoro")
        #expect(backfill?.taskID == taskID.uuidString)
        // Atomic take: commands + session cleared, second take finds nothing.
        #expect(AppGroupDefaults.externalStartRequested == false)
        #expect(AppGroupDefaults.isSessionActive == false)
        #expect(AppGroupDefaults.SessionReconcilePolicy.takeStaleExternalStartBackfill() == nil)
    }

    @Test("stale external start mid-window backfills abandoned partial")
    func staleStartMidWindowBackfillsAbandonedPartial() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.pomodoroDuration = 25 * 60
        // Widget pomodoro issued 10 min ago: 10 of 25 min served.
        AppGroupDefaults.startWidgetSession(
            modeID: "pomodoro",
            issuedAt: Date.now.addingTimeInterval(-600)
        )

        let backfill = AppGroupDefaults.SessionReconcilePolicy.takeStaleExternalStartBackfill()
        #expect(backfill?.wasCompleted == false)
        #expect(abs((backfill?.actualDuration ?? -1) - 600) < 5)
        #expect(backfill?.targetDuration == 1500)
    }

    @Test("fresh external start is never taken for backfill")
    func freshExternalStartIsNeverTaken() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.pomodoroDuration = 25 * 60
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: Date.now)

        // Fresh snapshots belong to the normal adopt path: untouched.
        #expect(AppGroupDefaults.SessionReconcilePolicy.takeStaleExternalStartBackfill() == nil)
        #expect(AppGroupDefaults.isSessionActive == true)
        #expect(AppGroupDefaults.externalStartRequested == true)
    }

    @Test("stale open-ended start is capped as corruption guard")
    func staleOpenEndedStartIsCapped() {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        // Widget flowtime issued 3 days ago: unbounded served time.
        AppGroupDefaults.startWidgetSession(
            modeID: "flowtime",
            issuedAt: Date.now.addingTimeInterval(-3 * 86400)
        )

        let backfill = AppGroupDefaults.SessionReconcilePolicy.takeStaleExternalStartBackfill()
        #expect(backfill?.wasCompleted == false)
        #expect(backfill?.actualDuration == 12 * 3600)
        #expect(backfill?.targetDuration == nil)
    }

    @Test("stale backfill validator rejects missing or inverted anchors")
    func staleBackfillValidatorRejectsBadAnchors() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        #expect(AppGroupDefaults.SessionReconcilePolicy.validatedStaleStartBackfill(
            modeName: "pomodoro", timerStart: nil, timerEnd: nil,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now) == nil)
        let start = now.addingTimeInterval(-600)
        #expect(AppGroupDefaults.SessionReconcilePolicy.validatedStaleStartBackfill(
            modeName: "pomodoro", timerStart: start, timerEnd: start,
            pomodoroNumber: 1, totalPomodoros: 4, taskID: nil, now: now) == nil)
    }

    @Test("completed backfill maps to a completed record")
    func completedBackfillMapsToCompletedRecord() {
        let now = Date(timeIntervalSince1970: 1_800_300_000)
        let snapshot = GhostSessionSnapshot(
            modeName: "pomodoro",
            startedAt: now.addingTimeInterval(-1500),
            endedAt: now,
            targetDuration: 1500,
            actualDuration: 1500,
            pomodoroNumber: 1,
            totalPomodoros: 4,
            taskID: nil,
            wasCompleted: true
        )
        let result = FocusSessionResult(ghost: snapshot)
        #expect(result.wasCompleted == true)
        #expect(result.actualDuration == 1500)
        #expect(result.totalFocusSeconds == 1500)
        #expect(result.phase == .work(number: 1, total: 4))
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
    var externalCompleteTaskRequested: Bool
    var externalCompleteTaskID: String?
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
            externalCompleteTaskRequested: AppGroupDefaults.externalCompleteTaskRequested,
            externalCompleteTaskID: AppGroupDefaults.externalCompleteTaskID,
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
        AppGroupDefaults.externalCompleteTaskRequested = externalCompleteTaskRequested
        AppGroupDefaults.externalCompleteTaskID = externalCompleteTaskID
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
