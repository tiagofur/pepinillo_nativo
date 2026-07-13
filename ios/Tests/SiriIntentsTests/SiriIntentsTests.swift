// SiriIntentsTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for App Intents: FocusModeEntity, FocusModeQuery, TaskEntity,
// StartFocusIntent, and StopFocusIntent.
// These tests cover pure logic and entity query behavior without SwiftData.

import Testing
import AppIntents
import Foundation
@testable import Pepinillo

@Suite("Siri Intents", .serialized, .appGroupDefaultsSerialized)
struct SiriIntentsTests {

    // MARK: - FocusModeEntity Properties

    @Test("FocusModeEntity IDs match FocusMode rawValues")
    func focusModeEntityIDs() {
        #expect(FocusModeEntity.pomodoro.id == "pomodoro")
        #expect(FocusModeEntity.flowtime.id == "flowtime")
        #expect(FocusModeEntity.timeBlock.id == "timeBlock")
        #expect(FocusModeEntity.stopwatch.id == "stopwatch")
    }

    @Test("FocusModeEntity display names are human-readable")
    func focusModeEntityDisplayNames() {
        #expect(FocusModeEntity.pomodoro.displayName == "Pomodoro")
        #expect(FocusModeEntity.flowtime.displayName == "Flowtime")
        #expect(FocusModeEntity.timeBlock.displayName == "Time Block")
        #expect(FocusModeEntity.stopwatch.displayName == "Stopwatch")
    }

    @Test("FocusModeEntity emoji icons are correct")
    func focusModeEntityIcons() {
        #expect(FocusModeEntity.pomodoro.icon == "🍅")
        #expect(FocusModeEntity.flowtime.icon == "🌊")
        #expect(FocusModeEntity.timeBlock.icon == "📦")
        #expect(FocusModeEntity.stopwatch.icon == "⏱️")
    }

    @Test("FocusModeEntity SF Symbol names are correct")
    func focusModeEntitySystemImages() {
        #expect(FocusModeEntity.pomodoro.iconSystemName == "timer")
        #expect(FocusModeEntity.flowtime.iconSystemName == "wind")
        #expect(FocusModeEntity.timeBlock.iconSystemName == "rectangle.split.3x1")
        #expect(FocusModeEntity.stopwatch.iconSystemName == "stopwatch")
    }

    @Test("FocusModeEntity.allModes contains exactly 4 modes")
    func allModesCount() {
        #expect(FocusModeEntity.allModes.count == 4)
    }

    @Test("FocusModeEntity.allModes includes every mode")
    func allModesContents() {
        let ids = Set(FocusModeEntity.allModes.map(\.id))
        #expect(ids == ["pomodoro", "flowtime", "timeBlock", "stopwatch"])
    }

    // MARK: - FocusModeQuery

    @Test("FocusModeQuery.entities(for:) filters by identifiers")
    func focusModeQueryEntitiesForIdentifiers() async throws {
        let query = FocusModeQuery()

        let twoModes = try await query.entities(for: ["pomodoro", "flowtime"])
        #expect(twoModes.count == 2)
        #expect(twoModes.map(\.id).contains("pomodoro"))
        #expect(twoModes.map(\.id).contains("flowtime"))
    }

    @Test("FocusModeQuery.entities(for:) returns empty for unknown identifiers")
    func focusModeQueryUnknownIdentifiers() async throws {
        let query = FocusModeQuery()
        let result = try await query.entities(for: ["unknown_mode", "fake_mode"])
        #expect(result.isEmpty)
    }

    @Test("FocusModeQuery.entities(for:) returns single mode by identifier")
    func focusModeQuerySingleEntity() async throws {
        let query = FocusModeQuery()
        let result = try await query.entities(for: ["stopwatch"])
        #expect(result.count == 1)
        #expect(result.first?.id == "stopwatch")
    }

    @Test("FocusModeQuery.suggestedEntities() returns all 4 modes")
    func focusModeQuerySuggestedEntities() async throws {
        let query = FocusModeQuery()
        let result = try await query.suggestedEntities()
        #expect(result.count == 4)
    }

    @Test("FocusModeQuery.defaultResult() returns pomodoro")
    func focusModeQueryDefaultResult() async throws {
        let query = FocusModeQuery()
        let result = await query.defaultResult()
        #expect(result?.id == "pomodoro")
    }

    // MARK: - TaskEntity

    @Test("TaskEntity active task has empty completion subtitle")
    func taskEntityActiveTaskSubtitle() {
        let entity = TaskEntity(
            id: UUID().uuidString,
            title: "Write unit tests",
            isCompleted: false
        )
        let repr = entity.displayRepresentation
        // Active tasks show no subtitle (empty string)
        #expect(repr.subtitle?.key == "")
    }

    @Test("TaskEntity completed task has 'Completed' subtitle")
    func taskEntityCompletedTaskSubtitle() {
        let entity = TaskEntity(
            id: UUID().uuidString,
            title: "Finished task",
            isCompleted: true
        )
        let repr = entity.displayRepresentation
        #expect(repr.subtitle?.key == "Completed")
    }

    @Test("TaskEntity title appears in display representation")
    func taskEntityDisplayTitle() {
        let title = "Design the onboarding flow"
        let entity = TaskEntity(id: UUID().uuidString, title: title, isCompleted: false)
        let repr = entity.displayRepresentation
        #expect(String(describing: repr.title).contains(title))
    }

    @Test("TaskEntity preserves UUID string as ID")
    func taskEntityPreservesID() {
        let uuidString = UUID().uuidString
        let entity = TaskEntity(id: uuidString, title: "Task", isCompleted: false)
        #expect(entity.id == uuidString)
    }

    // MARK: - StartFocusIntent

    @Test("StartFocusIntent.perform() completes without throwing")
    func startFocusIntentPerforms() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.isProUser = false

        var intent = StartFocusIntent()
        intent.mode = FocusModeEntity.pomodoro
        intent.task = nil
        intent.duration = nil
        _ = try await intent.perform()
        #expect(AppGroupDefaults.externalStartRequested == true)
        #expect(AppGroupDefaults.isSessionActive == true)
    }

    @Test("StartFocusIntent premium mode for free user does not create ghost session (#220)")
    func startFocusIntentProModeBlockedForFreeUser() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.userCapabilities = .free
        AppGroupDefaults.isProUser = false

        var intent = StartFocusIntent()
        intent.mode = FocusModeEntity.flowtime
        _ = try await intent.perform()

        #expect(AppGroupDefaults.externalStartRequested == true)
        #expect(AppGroupDefaults.isSessionActive == false)
        #expect(AppGroupDefaults.requestedMode == "flowtime")
    }

    @Test("StopFocusIntent mirrors widget stop protocol (#222)")
    func stopFocusIntentClearsSessionSnapshot() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro")
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = false

        _ = try await StopFocusIntent().perform()

        #expect(AppGroupDefaults.externalStopRequested == true)
        #expect(AppGroupDefaults.isSessionActive == false)
        #expect(AppGroupDefaults.externalCommandID != nil)
    }

    @Test("StartFocusIntent.perform() with task completes without throwing")
    func startFocusIntentWithTaskPerforms() async throws {
        var intent = StartFocusIntent()
        intent.mode = FocusModeEntity.flowtime
        intent.task = TaskEntity(id: UUID().uuidString, title: "Code review", isCompleted: false)
        intent.duration = nil
        _ = try await intent.perform()
    }

    @Test("StartFocusIntent.perform() with duration completes without throwing")
    func startFocusIntentWithDurationPerforms() async throws {
        var intent = StartFocusIntent()
        intent.mode = FocusModeEntity.timeBlock
        intent.task = nil
        intent.duration = 60
        _ = try await intent.perform()
    }

    @Test("StartFocusIntent duration parameter sets timer anchors (#224)")
    func startFocusIntentDurationSetsTimerAnchors() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.isProUser = true
        AppGroupDefaults.blockDuration = 60 * 60

        var intent = StartFocusIntent()
        intent.mode = FocusModeEntity.timeBlock
        intent.duration = 45
        _ = try await intent.perform()

        let start = try #require(AppGroupDefaults.activeSessionTimerStart)
        let end = try #require(AppGroupDefaults.activeSessionTimerEnd)
        #expect(end.timeIntervalSince(start) == 45 * 60)
        #expect(AppGroupDefaults.externalStartDurationMinutes == 45)
    }

    // MARK: - StopFocusIntent

    @Test("StopFocusIntent.perform() completes without throwing")
    func stopFocusIntentPerforms() async throws {
        let intent = StopFocusIntent()
        _ = try await intent.perform()
    }

    @Test("StopFocusIntent opens app so the engine can stop (#222)")
    func stopFocusIntentOpensApp() {
        #expect(StopFocusIntent.openAppWhenRun == true)
    }

    @Test("StartFocusIntent opens app when run")
    func startFocusIntentOpensApp() {
        #expect(StartFocusIntent.openAppWhenRun == true)
    }

    // MARK: - PepinilloShortcuts

    @Test("PepinilloShortcuts provides at least 2 shortcuts")
    func shortcutsCount() {
        #expect(PepinilloShortcuts.appShortcuts.count >= 2)
    }
}

// MARK: - Pause / Resume Focus Intents

@Suite("Siri Pause/Resume Intents", .serialized, .appGroupDefaultsSerialized)
struct SiriPauseResumeIntentTests {

    @Test("PauseFocusIntent writes the same external pause protocol as the widget")
    func pauseFocusIntentWritesPauseAnchors() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_400_000)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = false

        let before = Date.now
        _ = try await PauseFocusIntent().perform()
        let after = Date.now

        #expect(PauseFocusIntent.openAppWhenRun == false)
        #expect(AppGroupDefaults.externalPauseRequested == true)
        #expect(AppGroupDefaults.externalResumeRequested == false)
        #expect(AppGroupDefaults.activeSessionIsPaused == true)
        #expect(AppGroupDefaults.externalCommandID != nil)

        let issued = try #require(AppGroupDefaults.externalCommandIssuedAt)
        let pausedAt = try #require(AppGroupDefaults.activeSessionPausedAt)
        #expect(issued >= before && issued <= after)
        #expect(pausedAt == issued)
        #expect(AppGroupDefaults.activeSessionElapsed > 0)
        #expect(AppGroupDefaults.activeSessionRemaining != nil)
    }

    @Test("ResumeFocusIntent writes the same external resume protocol as the widget")
    func resumeFocusIntentWritesResumeAnchors() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_400_100)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = false
        #expect(AppGroupDefaults.requestExternalPause(at: issuedAt.addingTimeInterval(60)) == true)
        AppGroupDefaults.clearExternalCommands()

        let before = Date.now
        _ = try await ResumeFocusIntent().perform()
        let after = Date.now

        #expect(ResumeFocusIntent.openAppWhenRun == false)
        #expect(AppGroupDefaults.externalResumeRequested == true)
        #expect(AppGroupDefaults.externalPauseRequested == false)
        #expect(AppGroupDefaults.activeSessionIsPaused == false)
        #expect(AppGroupDefaults.activeSessionPausedAt == nil)
        #expect(AppGroupDefaults.externalCommandID != nil)

        let issued = try #require(AppGroupDefaults.externalCommandIssuedAt)
        #expect(issued >= before && issued <= after)
        #expect(AppGroupDefaults.activeSessionTimerStart != nil)
        #expect(AppGroupDefaults.activeSessionTimerEnd != nil)
    }

    @Test("GetCurrentSessionIntent uses live elapsed from timer anchors (#232)")
    func getCurrentSessionIntentUsesLiveElapsed() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()

        let issuedAt = Date(timeIntervalSince1970: 1_800_500_000)
        AppGroupDefaults.startWidgetSession(modeID: "pomodoro", issuedAt: issuedAt)
        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.externalStartRequested = false

        _ = try await GetCurrentSessionIntent().perform()

        let liveElapsed = Int(AppGroupDefaults.activeSessionLiveElapsed())
        #expect(liveElapsed >= 60)
    }

    @Test("PauseFocusIntent rejects pause when session is already paused")
    func pauseFocusIntentRejectsAlreadyPausedSession() async throws {
        let saved = AppGroupDefaultsSnapshot.capture()
        defer { saved.restore() }

        AppGroupDefaults.clearExternalCommands()
        AppGroupDefaults.clearActiveSession()
        AppGroupDefaults.isSessionActive = true
        AppGroupDefaults.activeSessionIsPaused = true

        _ = try await PauseFocusIntent().perform()

        #expect(AppGroupDefaults.externalPauseRequested == false)
        #expect(AppGroupDefaults.externalCommandIssuedAt == nil)
    }
}
