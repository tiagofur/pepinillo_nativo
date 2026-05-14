// AppGroupContainerTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for AppGroupDefaults capability read/write.
// Verifies that userCapabilities can be stored and retrieved from shared UserDefaults.

import Testing
import Foundation
@testable import Pepinillo

@Suite("AppGroupContainerTests", .serialized)
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
        let saved = AppGroupDefaults.userCapabilities
        defer { AppGroupDefaults.userCapabilities = saved }

        AppGroupDefaults.userCapabilities = nil
        #expect(AppGroupDefaults.userCapabilities == nil)
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

    @Test("StartFocusWithTaskIntent preserves the task and creates a widget-started session")
    func startFocusWithTaskIntentWritesTaskSession() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
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
}

struct AppGroupDefaultsSnapshot {
    var userCapabilities: UserCapabilities?
    var isProUser: Bool
    var canBackendSync: Bool
    var canAppleCloudSync: Bool
    var activeSyncMode: AppGroupDefaults.SyncMode
    var syncStatus: AppGroupDefaults.SyncStatus
    var lastAppleCloudActivationError: String?
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
