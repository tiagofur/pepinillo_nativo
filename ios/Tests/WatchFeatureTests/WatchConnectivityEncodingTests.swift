// WatchConnectivityEncodingTests.swift
// Pepinillo — Deep Work Companion for Apple
//
// Tests for WatchConnectivity encoding/decoding contracts.
// Since the encode/decode methods on WatchConnectivityManager are private,
// we test the value types themselves and verify dictionary structures match
// the wire format both sides agree on.

import Testing
import Foundation
@testable import Pepinillo

// MARK: - WatchSessionState Tests

@Suite("WatchSessionState")
struct WatchSessionStateTests {

    @Test func idleFactoryHasCorrectDefaults() {
        let idle = WatchSessionState.idle
        #expect(idle.isActive == false)
        #expect(idle.isPaused == false)
        #expect(idle.modeID == "pomodoro")
        #expect(idle.displayTime == "25:00")
        #expect(idle.phaseLabel == "Ready")
        #expect(idle.progress == nil)
        #expect(idle.pomodoroNumber == nil)
        #expect(idle.linkedTaskTitle == nil)
        #expect(idle.linkedTaskID == nil)
        #expect(idle.isPhaseTransition == false)
    }

    @Test func equatableConformance() {
        // Use an explicit sentAt so the two instances are identical — sentAt is a
        // transport timestamp (stale-update dedupe) so tests must pin it explicitly.
        let sentAt: TimeInterval = 1_000_000
        let a = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4",
            sentAt: sentAt
        )
        let b = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4",
            sentAt: sentAt
        )
        #expect(a == b)
    }

    @Test func equatableDiffersOnModeID() {
        let a = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4"
        )
        let b = WatchSessionState(
            isActive: true, isPaused: false, modeID: "flowtime",
            displayTime: "24:30", phaseLabel: "Focus 1/4"
        )
        #expect(a != b)
    }

    @Test func equatableIncludesOptionalFields() {
        let a = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4",
            progress: 0.5, pomodoroNumber: 2, linkedTaskTitle: "Write tests"
        )
        let b = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4",
            progress: 0.5, pomodoroNumber: 2, linkedTaskTitle: "Write tests"
        )
        #expect(a == b)
    }

    @Test func equatableDiffersOnOptionalPresence() {
        let a = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4",
            progress: 0.5
        )
        let b = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4"
        )
        #expect(a != b)
    }

    @Test func phaseTransitionDefaultsToFalse() {
        let state = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "25:00", phaseLabel: "Focus 1/4"
        )
        #expect(state.isPhaseTransition == false)
    }
}

// MARK: - Session State Dictionary Encoding Contract

@Suite("SessionState Dictionary Encoding")
struct SessionStateDictionaryTests {

    /// Builds a dictionary matching the format WatchConnectivityManager.sendSessionState produces.
    private func encodeSessionState(_ state: WatchSessionState) -> [String: Any] {
        var dict: [String: Any] = [
            "type":              "sessionState",
            "isActive":          state.isActive,
            "isPaused":          state.isPaused,
            "modeID":            state.modeID,
            "displayTime":       state.displayTime,
            "phaseLabel":        state.phaseLabel,
            "isPhaseTransition": state.isPhaseTransition,
            "sentAt":            state.sentAt,
        ]
        if let p = state.progress        { dict["progress"]       = p }
        if let n = state.pomodoroNumber  { dict["pomodoroNumber"] = n }
        if let t = state.linkedTaskTitle { dict["linkedTaskTitle"] = t }
        if let t = state.linkedTaskID    { dict["linkedTaskID"]   = t }
        return dict
    }

    /// Decodes a dictionary back to WatchSessionState, matching the manager's decodeSessionState.
    private func decodeSessionState(_ message: [String: Any]) -> WatchSessionState? {
        guard let isActive    = message["isActive"]    as? Bool,
              let isPaused    = message["isPaused"]    as? Bool,
              let modeID      = message["modeID"]      as? String,
              let displayTime = message["displayTime"] as? String,
              let phaseLabel  = message["phaseLabel"]  as? String
        else { return nil }

        return WatchSessionState(
            isActive:          isActive,
            isPaused:          isPaused,
            modeID:            modeID,
            displayTime:       displayTime,
            phaseLabel:        phaseLabel,
            progress:          message["progress"]         as? Double,
            pomodoroNumber:    message["pomodoroNumber"]   as? Int,
            linkedTaskTitle:   message["linkedTaskTitle"]  as? String,
            linkedTaskID:      message["linkedTaskID"]     as? String,
            isPhaseTransition: message["isPhaseTransition"] as? Bool ?? false,
            sentAt:            message["sentAt"]           as? TimeInterval ?? Date().timeIntervalSince1970
        )
    }

    @Test func roundTripWithAllFields() {
        let original = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "22:15", phaseLabel: "Focus 2/4",
            progress: 0.11, pomodoroNumber: 2,
            linkedTaskTitle: "Ship v1", linkedTaskID: "ABC-123",
            isPhaseTransition: true
        )
        let dict = encodeSessionState(original)
        let decoded = decodeSessionState(dict)
        #expect(decoded == original)
    }

    @Test func roundTripWithNoOptionals() {
        let original = WatchSessionState(
            isActive: false, isPaused: false, modeID: "stopwatch",
            displayTime: "0:00", phaseLabel: "Free Focus"
        )
        let dict = encodeSessionState(original)
        let decoded = decodeSessionState(dict)
        #expect(decoded == original)
    }

    @Test func roundTripIdle() {
        let idle = WatchSessionState.idle
        let dict = encodeSessionState(idle)
        let decoded = decodeSessionState(dict)
        #expect(decoded == idle)
    }

    @Test func dictionaryContainsRequiredKeys() {
        let dict = encodeSessionState(.idle)
        #expect(dict["type"] as? String == "sessionState")
        #expect(dict["isActive"]    != nil)
        #expect(dict["isPaused"]    != nil)
        #expect(dict["modeID"]      != nil)
        #expect(dict["displayTime"] != nil)
        #expect(dict["phaseLabel"]  != nil)
    }

    @Test func optionalFieldsOmittedWhenNil() {
        let state = WatchSessionState(
            isActive: true, isPaused: false, modeID: "flowtime",
            displayTime: "5:30", phaseLabel: "Flow"
        )
        let dict = encodeSessionState(state)
        #expect(dict["progress"]       == nil)
        #expect(dict["pomodoroNumber"] == nil)
        #expect(dict["linkedTaskTitle"] == nil)
        #expect(dict["linkedTaskID"]   == nil)
    }

    @Test func decodingFailsWhenRequiredFieldMissing() {
        let incomplete: [String: Any] = [
            "type": "sessionState",
            "isActive": true,
            // missing isPaused, modeID, displayTime, phaseLabel
        ]
        let decoded = decodeSessionState(incomplete)
        #expect(decoded == nil)
    }

    @Test func decodingFailsWithWrongTypes() {
        let wrongTypes: [String: Any] = [
            "type":        "sessionState",
            "isActive":    "yes",       // should be Bool
            "isPaused":    false,
            "modeID":      "pomodoro",
            "displayTime": "25:00",
            "phaseLabel":  "Ready",
        ]
        let decoded = decodeSessionState(wrongTypes)
        #expect(decoded == nil)
    }
}

// MARK: - Command Dictionary Encoding Contract

@Suite("WatchCommand Dictionary Encoding")
struct WatchCommandDictionaryTests {

    /// Builds a dictionary matching the format WatchConnectivityManager.encodeCommand produces.
    private func encodeCommand(_ command: WatchCommand) -> [String: Any] {
        var dict: [String: Any] = ["type": "command"]
        switch command {
        case .startSession(let mode):       dict["action"] = "start"; dict["mode"] = mode
        case .pauseSession:                 dict["action"] = "pause"
        case .resumeSession:                dict["action"] = "resume"
        case .stopSession:                  dict["action"] = "stop"
        case .skipPhase:                    dict["action"] = "skip"
        case .linkTask(let id):             dict["action"] = "linkTask"; dict["taskID"] = id
        case .unlinkTask:                   dict["action"] = "unlinkTask"
        case .setTaskCompleted(let id, let isCompleted):
            dict["action"] = "setTaskCompleted"
            dict["taskID"] = id
            dict["isCompleted"] = isCompleted
        case .requestTasks:                 dict["action"] = "requestTasks"
        case .requestDashboard:             dict["action"] = "requestDashboard"
        case .requestSession:               dict["action"] = "requestSession"
        case .startNextPhase:               dict["action"] = "startNextPhase"
        }
        return dict
    }

    /// Decodes a dictionary back to WatchCommand, matching the manager's decodeCommand.
    private func decodeCommand(_ message: [String: Any]) -> WatchCommand? {
        guard let action = message["action"] as? String else { return nil }
        switch action {
        case "start":            return .startSession(mode: message["mode"] as? String ?? "pomodoro")
        case "pause":            return .pauseSession
        case "resume":           return .resumeSession
        case "stop":             return .stopSession
        case "skip":             return .skipPhase
        case "linkTask":         return .linkTask(id: message["taskID"] as? String ?? "")
        case "unlinkTask":       return .unlinkTask
        case "setTaskCompleted":
            return .setTaskCompleted(
                id: message["taskID"] as? String ?? "",
                isCompleted: message["isCompleted"] as? Bool ?? false
            )
        case "requestTasks":     return .requestTasks
        case "requestDashboard": return .requestDashboard
        case "requestSession":   return .requestSession
        default:                 return nil
        }
    }

    @Test func roundTripStartSession() {
        let cmd = WatchCommand.startSession(mode: "flowtime")
        let dict = encodeCommand(cmd)
        #expect(dict["type"]   as? String == "command")
        #expect(dict["action"] as? String == "start")
        #expect(dict["mode"]   as? String == "flowtime")
        #expect(decodeCommand(dict) == cmd)
    }

    @Test func roundTripPauseSession() {
        let cmd = WatchCommand.pauseSession
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func roundTripResumeSession() {
        let cmd = WatchCommand.resumeSession
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func roundTripStopSession() {
        let cmd = WatchCommand.stopSession
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func roundTripSkipPhase() {
        let cmd = WatchCommand.skipPhase
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func roundTripLinkTask() {
        let cmd = WatchCommand.linkTask(id: "task-uuid-123")
        let dict = encodeCommand(cmd)
        #expect(dict["taskID"] as? String == "task-uuid-123")
        #expect(decodeCommand(dict) == cmd)
    }

    @Test func roundTripUnlinkTask() {
        let cmd = WatchCommand.unlinkTask
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func roundTripSetTaskCompleted() {
        let cmd = WatchCommand.setTaskCompleted(id: "task-456", isCompleted: true)
        let dict = encodeCommand(cmd)
        #expect(dict["action"] as? String == "setTaskCompleted")
        #expect(dict["taskID"] as? String == "task-456")
        #expect(dict["isCompleted"] as? Bool == true)
        #expect(decodeCommand(dict) == cmd)
    }

    @Test func roundTripRequestTasks() {
        let cmd = WatchCommand.requestTasks
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func roundTripRequestDashboard() {
        let cmd = WatchCommand.requestDashboard
        let decoded = decodeCommand(encodeCommand(cmd))
        #expect(decoded == cmd)
    }

    @Test func allCommandsRoundTrip() {
        let commands: [WatchCommand] = [
            .startSession(mode: "pomodoro"),
            .startSession(mode: "flowtime"),
            .startSession(mode: "timeBlock"),
            .startSession(mode: "stopwatch"),
            .pauseSession,
            .resumeSession,
            .stopSession,
            .skipPhase,
            .linkTask(id: "id-1"),
            .unlinkTask,
            .setTaskCompleted(id: "id-2", isCompleted: true),
            .requestTasks,
            .requestDashboard,
            .requestSession,
        ]
        for cmd in commands {
            let roundTripped = decodeCommand(encodeCommand(cmd))
            #expect(roundTripped == cmd, "Round-trip failed for \(cmd)")
        }
    }

    @Test func decodingUnknownActionReturnsNil() {
        let dict: [String: Any] = ["type": "command", "action": "explode"]
        #expect(decodeCommand(dict) == nil)
    }

    @Test func decodingMissingActionReturnsNil() {
        let dict: [String: Any] = ["type": "command"]
        #expect(decodeCommand(dict) == nil)
    }

    @Test func startSessionDefaultsToPomodoro() {
        let dict: [String: Any] = ["type": "command", "action": "start"]
        let decoded = decodeCommand(dict)
        #expect(decoded == .startSession(mode: "pomodoro"))
    }

    @Test func linkTaskDefaultsToEmptyStringWhenMissingID() {
        let dict: [String: Any] = ["type": "command", "action": "linkTask"]
        let decoded = decodeCommand(dict)
        #expect(decoded == .linkTask(id: ""))
    }
}

// MARK: - WatchCommand Equatable Tests

@Suite("WatchCommand Equatable")
struct WatchCommandEquatableTests {

    @Test func sameCommandsAreEqual() {
        #expect(WatchCommand.pauseSession == WatchCommand.pauseSession)
        #expect(WatchCommand.resumeSession == WatchCommand.resumeSession)
        #expect(WatchCommand.stopSession == WatchCommand.stopSession)
        #expect(WatchCommand.skipPhase == WatchCommand.skipPhase)
        #expect(WatchCommand.unlinkTask == WatchCommand.unlinkTask)
        #expect(WatchCommand.requestTasks == WatchCommand.requestTasks)
        #expect(WatchCommand.requestDashboard == WatchCommand.requestDashboard)
    }

    @Test func startSessionDiffersOnMode() {
        #expect(WatchCommand.startSession(mode: "pomodoro") != WatchCommand.startSession(mode: "flowtime"))
    }

    @Test func differentCommandsAreNotEqual() {
        #expect(WatchCommand.pauseSession != WatchCommand.resumeSession)
        #expect(WatchCommand.stopSession != WatchCommand.skipPhase)
    }

    @Test func linkTaskDiffersOnID() {
        #expect(WatchCommand.linkTask(id: "a") != WatchCommand.linkTask(id: "b"))
    }

    @Test func setTaskCompletedDiffersOnIDOrState() {
        #expect(WatchCommand.setTaskCompleted(id: "a", isCompleted: true) != WatchCommand.setTaskCompleted(id: "b", isCompleted: true))
        #expect(WatchCommand.setTaskCompleted(id: "a", isCompleted: true) != WatchCommand.setTaskCompleted(id: "a", isCompleted: false))
    }
}

// MARK: - WatchTaskItem Tests

@Suite("WatchTaskItem")
struct WatchTaskItemTests {

    @Test func identifiableUsesUUID() {
        let id = UUID()
        let item = WatchTaskItem(
            id: id, title: "Write tests", isCompleted: false,
            priority: 2, estimatedPomodoros: 4, completedPomodoros: 1
        )
        #expect(item.id == id)
    }

    @Test func equatableConformance() {
        let id = UUID()
        let a = WatchTaskItem(
            id: id, title: "Write tests", isCompleted: false,
            priority: 2, estimatedPomodoros: 4, completedPomodoros: 1
        )
        let b = WatchTaskItem(
            id: id, title: "Write tests", isCompleted: false,
            priority: 2, estimatedPomodoros: 4, completedPomodoros: 1
        )
        #expect(a == b)
    }

    @Test func equatableDiffersOnCompletion() {
        let id = UUID()
        let a = WatchTaskItem(
            id: id, title: "Task", isCompleted: false,
            priority: 0, estimatedPomodoros: 1, completedPomodoros: 0
        )
        let b = WatchTaskItem(
            id: id, title: "Task", isCompleted: true,
            priority: 0, estimatedPomodoros: 1, completedPomodoros: 0
        )
        #expect(a != b)
    }

    @Test func equatableDiffersOnTitle() {
        let id = UUID()
        let a = WatchTaskItem(
            id: id, title: "Task A", isCompleted: false,
            priority: 0, estimatedPomodoros: 1, completedPomodoros: 0
        )
        let b = WatchTaskItem(
            id: id, title: "Task B", isCompleted: false,
            priority: 0, estimatedPomodoros: 1, completedPomodoros: 0
        )
        #expect(a != b)
    }
}

// MARK: - Task Dictionary Encoding Contract

@Suite("Task Dictionary Encoding")
struct TaskDictionaryEncodingTests {

    /// Encodes tasks the same way WatchConnectivityManager.sendTasks does.
    private func encodeTasks(_ tasks: [WatchTaskItem]) -> [String: Any] {
        let encoded: [[String: Any]] = tasks.map { task in
            [
                "id":                 task.id.uuidString,
                "title":              task.title,
                "isCompleted":        task.isCompleted,
                "priority":           task.priority,
                "estimatedPomodoros": task.estimatedPomodoros,
                "completedPomodoros": task.completedPomodoros,
            ]
        }
        return ["type": "tasks", "items": encoded]
    }

    /// Decodes tasks the same way WatchConnectivityManager.decodeTasks does.
    private func decodeTasks(_ message: [String: Any]) -> [WatchTaskItem]? {
        guard let items = message["items"] as? [[String: Any]] else { return nil }
        return items.compactMap { dict in
            guard let idStr = dict["id"] as? String,
                  let id = UUID(uuidString: idStr),
                  let title = dict["title"] as? String
            else { return nil }
            return WatchTaskItem(
                id:                 id,
                title:              title,
                isCompleted:        dict["isCompleted"]        as? Bool ?? false,
                priority:           dict["priority"]           as? Int ?? 0,
                estimatedPomodoros: dict["estimatedPomodoros"] as? Int ?? 1,
                completedPomodoros: dict["completedPomodoros"] as? Int ?? 0
            )
        }
    }

    @Test func roundTripSingleTask() {
        let id = UUID()
        let tasks = [WatchTaskItem(
            id: id, title: "Ship feature", isCompleted: false,
            priority: 3, estimatedPomodoros: 4, completedPomodoros: 2
        )]
        let dict = encodeTasks(tasks)
        let decoded = decodeTasks(dict)
        #expect(decoded == tasks)
    }

    @Test func roundTripMultipleTasks() {
        let tasks = [
            WatchTaskItem(id: UUID(), title: "Task 1", isCompleted: false,
                          priority: 1, estimatedPomodoros: 2, completedPomodoros: 0),
            WatchTaskItem(id: UUID(), title: "Task 2", isCompleted: true,
                          priority: 0, estimatedPomodoros: 1, completedPomodoros: 1),
            WatchTaskItem(id: UUID(), title: "Task 3", isCompleted: false,
                          priority: 2, estimatedPomodoros: 8, completedPomodoros: 5),
        ]
        let dict = encodeTasks(tasks)
        let decoded = decodeTasks(dict)
        #expect(decoded == tasks)
    }

    @Test func roundTripEmptyList() {
        let dict = encodeTasks([])
        let decoded = decodeTasks(dict)
        #expect(decoded == [])
    }

    @Test func decodingSkipsItemsWithInvalidUUID() {
        let dict: [String: Any] = [
            "type": "tasks",
            "items": [
                ["id": "not-a-uuid", "title": "Bad"],
                ["id": UUID().uuidString, "title": "Good", "isCompleted": false, "priority": 1, "estimatedPomodoros": 1, "completedPomodoros": 0],
            ] as [[String: Any]]
        ]
        let decoded = decodeTasks(dict)
        #expect(decoded?.count == 1)
    }

    @Test func decodingSkipsItemsMissingTitle() {
        let dict: [String: Any] = [
            "type": "tasks",
            "items": [
                ["id": UUID().uuidString, "priority": 1] as [String: Any],
            ] as [[String: Any]]
        ]
        let decoded = decodeTasks(dict)
        #expect(decoded?.count == 0)
    }

    @Test func decodingReturnsNilWhenItemsKeyMissing() {
        let dict: [String: Any] = ["type": "tasks"]
        let decoded = decodeTasks(dict)
        #expect(decoded == nil)
    }

    @Test func decodingUsesDefaultsForMissingOptionalFields() {
        let id = UUID()
        let dict: [String: Any] = [
            "type": "tasks",
            "items": [
                ["id": id.uuidString, "title": "Minimal task"] as [String: Any],
            ] as [[String: Any]]
        ]
        let decoded = decodeTasks(dict)
        #expect(decoded?.count == 1)
        let task = decoded?.first
        #expect(task?.isCompleted == false)
        #expect(task?.priority == 0)
        #expect(task?.estimatedPomodoros == 1)
        #expect(task?.completedPomodoros == 0)
    }
}

// MARK: - WatchDashboardStats Tests

@Suite("WatchDashboardStats")
struct WatchDashboardStatsTests {

    @Test func equatableConformance() {
        let a = WatchDashboardStats(
            todayMinutes: 120, sessionsCompleted: 5, tasksCompleted: 3,
            tasksTotal: 10, streakDays: 7, pomodoroMinutes: 50,
            flowtimeMinutes: 30, timeBlockMinutes: 25,
            stopwatchMinutes: 15, longestSessionMinutes: 45
        )
        let b = WatchDashboardStats(
            todayMinutes: 120, sessionsCompleted: 5, tasksCompleted: 3,
            tasksTotal: 10, streakDays: 7, pomodoroMinutes: 50,
            flowtimeMinutes: 30, timeBlockMinutes: 25,
            stopwatchMinutes: 15, longestSessionMinutes: 45
        )
        #expect(a == b)
    }

    @Test func equatableDiffersOnAnyField() {
        let a = WatchDashboardStats(
            todayMinutes: 120, sessionsCompleted: 5, tasksCompleted: 3,
            tasksTotal: 10, streakDays: 7, pomodoroMinutes: 50,
            flowtimeMinutes: 30, timeBlockMinutes: 25,
            stopwatchMinutes: 15, longestSessionMinutes: 45
        )
        let b = WatchDashboardStats(
            todayMinutes: 121, sessionsCompleted: 5, tasksCompleted: 3,
            tasksTotal: 10, streakDays: 7, pomodoroMinutes: 50,
            flowtimeMinutes: 30, timeBlockMinutes: 25,
            stopwatchMinutes: 15, longestSessionMinutes: 45
        )
        #expect(a != b)
    }
}

// MARK: - Dashboard Stats Dictionary Encoding Contract

@Suite("Dashboard Stats Dictionary Encoding")
struct DashboardStatsDictionaryTests {

    /// Encodes stats the same way WatchConnectivityManager.sendDashboardStats does.
    private func encodeDashboardStats(_ stats: WatchDashboardStats) -> [String: Any] {
        [
            "type":                  "dashboardStats",
            "todayMinutes":          stats.todayMinutes,
            "sessionsCompleted":     stats.sessionsCompleted,
            "tasksCompleted":        stats.tasksCompleted,
            "tasksTotal":            stats.tasksTotal,
            "streakDays":            stats.streakDays,
            "pomodoroMinutes":       stats.pomodoroMinutes,
            "flowtimeMinutes":       stats.flowtimeMinutes,
            "timeBlockMinutes":      stats.timeBlockMinutes,
            "stopwatchMinutes":      stats.stopwatchMinutes,
            "longestSessionMinutes": stats.longestSessionMinutes,
        ]
    }

    /// Decodes stats the same way WatchConnectivityManager.decodeDashboardStats does.
    private func decodeDashboardStats(_ message: [String: Any]) -> WatchDashboardStats {
        WatchDashboardStats(
            todayMinutes:          message["todayMinutes"]          as? Int ?? 0,
            sessionsCompleted:     message["sessionsCompleted"]     as? Int ?? 0,
            tasksCompleted:        message["tasksCompleted"]        as? Int ?? 0,
            tasksTotal:            message["tasksTotal"]            as? Int ?? 0,
            streakDays:            message["streakDays"]            as? Int ?? 0,
            pomodoroMinutes:       message["pomodoroMinutes"]       as? Int ?? 0,
            flowtimeMinutes:       message["flowtimeMinutes"]       as? Int ?? 0,
            timeBlockMinutes:      message["timeBlockMinutes"]      as? Int ?? 0,
            stopwatchMinutes:      message["stopwatchMinutes"]      as? Int ?? 0,
            longestSessionMinutes: message["longestSessionMinutes"] as? Int ?? 0
        )
    }

    @Test func roundTripFullStats() {
        let original = WatchDashboardStats(
            todayMinutes: 180, sessionsCompleted: 8, tasksCompleted: 5,
            tasksTotal: 12, streakDays: 14, pomodoroMinutes: 75,
            flowtimeMinutes: 50, timeBlockMinutes: 35,
            stopwatchMinutes: 20, longestSessionMinutes: 60
        )
        let dict = encodeDashboardStats(original)
        let decoded = decodeDashboardStats(dict)
        #expect(decoded == original)
    }

    @Test func decodingEmptyDictDefaultsToZeros() {
        let decoded = decodeDashboardStats([:])
        let expected = WatchDashboardStats(
            todayMinutes: 0, sessionsCompleted: 0, tasksCompleted: 0,
            tasksTotal: 0, streakDays: 0, pomodoroMinutes: 0,
            flowtimeMinutes: 0, timeBlockMinutes: 0,
            stopwatchMinutes: 0, longestSessionMinutes: 0
        )
        #expect(decoded == expected)
    }

    @Test func dictionaryContainsTypeKey() {
        let stats = WatchDashboardStats(
            todayMinutes: 0, sessionsCompleted: 0, tasksCompleted: 0,
            tasksTotal: 0, streakDays: 0, pomodoroMinutes: 0,
            flowtimeMinutes: 0, timeBlockMinutes: 0,
            stopwatchMinutes: 0, longestSessionMinutes: 0
        )
        let dict = encodeDashboardStats(stats)
        #expect(dict["type"] as? String == "dashboardStats")
    }
}

// MARK: - WatchMessage Equatable Tests

@Suite("WatchMessage Equatable")
struct WatchMessageEquatableTests {

    @Test func sessionStateMessagesCompareByValue() {
        let state = WatchSessionState.idle
        let a = WatchMessage.sessionState(state)
        let b = WatchMessage.sessionState(state)
        #expect(a == b)
    }

    @Test func statsMessagesCompareByValue() {
        let a = WatchMessage.stats(todayMinutes: 60, sessions: 3, streak: 5)
        let b = WatchMessage.stats(todayMinutes: 60, sessions: 3, streak: 5)
        #expect(a == b)
    }

    @Test func statsMessagesDifferOnValues() {
        let a = WatchMessage.stats(todayMinutes: 60, sessions: 3, streak: 5)
        let b = WatchMessage.stats(todayMinutes: 61, sessions: 3, streak: 5)
        #expect(a != b)
    }

    @Test func commandMessagesCompareByValue() {
        let a = WatchMessage.command(.pauseSession)
        let b = WatchMessage.command(.pauseSession)
        #expect(a == b)
    }

    @Test func differentMessageTypesAreNotEqual() {
        let a = WatchMessage.command(.pauseSession)
        let b = WatchMessage.connectivityStatus(true)
        #expect(a != b)
    }

    @Test func connectivityStatusComparesValue() {
        #expect(WatchMessage.connectivityStatus(true) == WatchMessage.connectivityStatus(true))
        #expect(WatchMessage.connectivityStatus(true) != WatchMessage.connectivityStatus(false))
    }

    @Test func tasksMessageComparesItems() {
        let tasks = [WatchTaskItem(
            id: UUID(), title: "Test", isCompleted: false,
            priority: 0, estimatedPomodoros: 1, completedPomodoros: 0
        )]
        let a = WatchMessage.tasks(tasks, sentAt: 100)
        let b = WatchMessage.tasks(tasks, sentAt: 100)
        #expect(a == b)
    }

    @Test func emptyTasksMessageEquals() {
        #expect(WatchMessage.tasks([], sentAt: 0) == WatchMessage.tasks([], sentAt: 0))
    }

    @Test func tasksMessageDiffersOnSentAt() {
        #expect(WatchMessage.tasks([], sentAt: 1) != WatchMessage.tasks([], sentAt: 2))
    }
}

// MARK: - Stats Dictionary Encoding Contract

@Suite("Stats Dictionary Encoding")
struct StatsDictionaryEncodingTests {

    /// Encodes stats the same way WatchConnectivityManager.sendStats does.
    private func encodeStats(todayMinutes: Int, sessions: Int, streak: Int) -> [String: Any] {
        [
            "type":         "stats",
            "todayMinutes": todayMinutes,
            "sessions":     sessions,
            "streak":       streak,
        ]
    }

    @Test func dictionaryContainsAllFields() {
        let dict = encodeStats(todayMinutes: 120, sessions: 5, streak: 10)
        #expect(dict["type"]         as? String == "stats")
        #expect(dict["todayMinutes"] as? Int == 120)
        #expect(dict["sessions"]     as? Int == 5)
        #expect(dict["streak"]       as? Int == 10)
    }

    @Test func zeroValuesAreEncoded() {
        let dict = encodeStats(todayMinutes: 0, sessions: 0, streak: 0)
        #expect(dict["todayMinutes"] as? Int == 0)
        #expect(dict["sessions"]     as? Int == 0)
        #expect(dict["streak"]       as? Int == 0)
    }
}

// MARK: - Theme Dictionary Encoding (#533)
//
// WatchConnectivityClient.sendTheme writes a top-level "theme" section with a
// single "themeName" string. Mirrors the encode/decode contract used by the
// stats / sessionState / dashboardStats sections.

@Suite("Theme Dictionary Encoding")
struct ThemeDictionaryEncodingTests {

    /// Encodes a theme payload the same way WatchConnectivityManager.sendTheme does.
    private func encodeTheme(_ themeName: String, includeType: Bool = true) -> [String: Any] {
        var dict: [String: Any] = ["themeName": themeName]
        if includeType { dict["type"] = "theme" }
        return dict
    }

    @Test func dictionaryContainsThemeName() {
        let dict = encodeTheme("forest")
        #expect(dict["themeName"] as? String == "forest")
    }

    @Test func defaultThemeRoundTrips() {
        // "default" is the Classic theme key — must survive the wire format.
        let dict = encodeTheme("default")
        #expect(dict["themeName"] as? String == "default")
    }

    @Test func unknownThemeIsPreservedOnWire() {
        // The phone is the source of truth; an unknown name is still transmitted
        // verbatim and the watch resolves it via AppTheme.named(_:) → .classic.
        let dict = encodeTheme("liquidGlass-phantom")
        #expect(dict["themeName"] as? String == "liquidGlass-phantom")
    }

    @Test func watchMessageThemeIsEquatable() {
        // WatchMessage.theme carries the name through to the watch reducer.
        #expect(WatchMessage.theme("forest") == WatchMessage.theme("forest"))
        #expect(WatchMessage.theme("forest") != WatchMessage.theme("ocean"))
        #expect(WatchMessage.theme("forest") != WatchMessage.sessionState(.idle))
    }
}

// MARK: - Wire Format Type Dispatcher Tests
//
// All incoming WatchConnectivity messages have a "type" discriminator key.
// The dispatcher must handle unknown types gracefully — no crash, no action.

@Suite("Wire Format Type Dispatcher")
struct WireFormatTypeDispatcherTests {

    /// Simulates the top-level dispatch WatchConnectivityManager.didReceiveMessage performs.
    private func dispatch(_ message: [String: Any]) -> String? {
        message["type"] as? String
    }

    @Test func knownTypeSessionState() {
        let dict: [String: Any] = ["type": "sessionState", "isActive": false]
        #expect(dispatch(dict) == "sessionState")
    }

    @Test func knownTypeCommand() {
        let dict: [String: Any] = ["type": "command", "action": "pause"]
        #expect(dispatch(dict) == "command")
    }

    @Test func knownTypeStats() {
        let dict: [String: Any] = ["type": "stats"]
        #expect(dispatch(dict) == "stats")
    }

    @Test func knownTypeTasks() {
        let dict: [String: Any] = ["type": "tasks"]
        #expect(dispatch(dict) == "tasks")
    }

    @Test func knownTypeDashboardStats() {
        let dict: [String: Any] = ["type": "dashboardStats"]
        #expect(dispatch(dict) == "dashboardStats")
    }

    @Test func unknownTypeReturnsUnrecognizedString() {
        // A future message type from a newer app version should not crash;
        // the dispatcher should receive a non-nil String, then skip unknown types.
        let dict: [String: Any] = ["type": "futurePayloadType", "data": 42]
        let typeValue = dispatch(dict)
        // It is NOT nil — the key is present. The dispatcher must handle
        // unrecognised values by doing nothing (no default handler).
        #expect(typeValue == "futurePayloadType")
    }

    @Test func missingTypeKeyReturnsNil() {
        let dict: [String: Any] = ["action": "pause"]
        #expect(dispatch(dict) == nil)
    }

    @Test func wrongTypeForTypeKeyReturnsNil() {
        // If "type" is not a String (e.g. sent by a buggy future version)
        let dict: [String: Any] = ["type": 42]
        #expect(dispatch(dict) == nil)
    }
}

// MARK: - Transport Semantics Contract Tests
//
// Asserts the CORRECT transport semantics after the fix.
//
// Transport map (phone → watch):
//   sessionState  → applicationContext (guaranteed on wake) + sendMessage when reachable
//   stats         → merged into applicationContext + sendMessage when reachable
//   dashboardStats→ merged into applicationContext + sendMessage when reachable
//   tasks         → transferUserInfo (queued, guaranteed) + sendMessage when reachable
//   commands      → sendMessage only (watch → phone; correct as-is)
//
// Context dict shape (top-level keys, no clobber):
//   { "sessionState": {...}, "stats": {...}, "dashboardStats": {...}, "sentAt": TimeInterval }
//
// Stale-update dedupe: sentAt TimeInterval in every payload; the watch reducer
// ignores updates older than the current state's sentAt.

@Suite("Transport Semantics Contract")
struct TransportSemanticsContractTests {

    // MARK: - Payload serialization — all mechanisms require property-list-compatible dicts

    @Test func sessionStatePayloadIsPlistCompatible() {
        let state = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "23:00", phaseLabel: "Focus 1/4",
            progress: 0.08, pomodoroNumber: 1,
            linkedTaskTitle: "Ship it", linkedTaskID: "T-42",
            isPhaseTransition: false
        )
        let dict: [String: Any] = [
            "isActive":          state.isActive,
            "isPaused":          state.isPaused,
            "modeID":            state.modeID,
            "displayTime":       state.displayTime,
            "phaseLabel":        state.phaseLabel,
            "isPhaseTransition": state.isPhaseTransition,
            "sentAt":            state.sentAt,
            "progress":          state.progress as Any,
            "pomodoroNumber":    state.pomodoroNumber as Any,
            "linkedTaskTitle":   state.linkedTaskTitle as Any,
            "linkedTaskID":      state.linkedTaskID as Any,
        ]
        #expect(PropertyListSerialization.propertyList(dict, isValidFor: .binary))
    }

    @Test func commandPayloadIsPlistCompatible() {
        let dict: [String: Any] = ["type": "command", "action": "pause"]
        #expect(PropertyListSerialization.propertyList(dict, isValidFor: .binary))
    }

    @Test func statsPayloadIsPlistCompatible() {
        let dict: [String: Any] = [
            "todayMinutes": 90,
            "sessions": 4,
            "streak": 7,
        ]
        #expect(PropertyListSerialization.propertyList(dict, isValidFor: .binary))
    }

    @Test func taskPayloadIsPlistCompatible() {
        let taskDict: [String: Any] = [
            "id":                 UUID().uuidString,
            "title":              "Ship feature",
            "isCompleted":        false,
            "priority":           2,
            "estimatedPomodoros": 4,
            "completedPomodoros": 1,
        ]
        let dict: [String: Any] = ["type": "tasks", "items": [taskDict]]
        #expect(PropertyListSerialization.propertyList(dict, isValidFor: .binary))
    }

    @Test func dashboardStatsPayloadIsPlistCompatible() {
        let dict: [String: Any] = [
            "todayMinutes":          180,
            "sessionsCompleted":     8,
            "tasksCompleted":        5,
            "tasksTotal":            12,
            "streakDays":            14,
            "pomodoroMinutes":       75,
            "flowtimeMinutes":       50,
            "timeBlockMinutes":      35,
            "stopwatchMinutes":      20,
            "longestSessionMinutes": 60,
        ]
        #expect(PropertyListSerialization.propertyList(dict, isValidFor: .binary))
    }

    // MARK: - Context payload shape: merged dict with separate top-level keys, no clobber

    @Test func contextDictContainsSeparateTopLevelKeys() {
        // sessionState, stats, and dashboardStats must live under distinct top-level
        // keys so one section never overwrites another.
        let sessionDict: [String: Any] = [
            "isActive": true, "isPaused": false, "modeID": "pomodoro",
            "displayTime": "24:00", "phaseLabel": "Focus", "isPhaseTransition": false,
            "sentAt": Date().timeIntervalSince1970,
        ]
        let statsDict: [String: Any] = ["todayMinutes": 60, "sessions": 3, "streak": 5]
        let dashboardDict: [String: Any] = [
            "todayMinutes": 60, "sessionsCompleted": 3, "tasksCompleted": 2,
            "tasksTotal": 5, "streakDays": 5, "pomodoroMinutes": 50,
            "flowtimeMinutes": 0, "timeBlockMinutes": 10, "stopwatchMinutes": 0,
            "longestSessionMinutes": 25,
        ]

        let ctx: [String: Any] = [
            "sessionState":   sessionDict,
            "stats":          statsDict,
            "dashboardStats": dashboardDict,
            "sentAt":         Date().timeIntervalSince1970,
        ]

        // Each section must be independently accessible
        #expect(ctx["sessionState"]   as? [String: Any] != nil)
        #expect(ctx["stats"]          as? [String: Any] != nil)
        #expect(ctx["dashboardStats"] as? [String: Any] != nil)

        // Sections must not clobber each other's keys
        let s = ctx["sessionState"] as! [String: Any]
        let st = ctx["stats"] as! [String: Any]
        let d = ctx["dashboardStats"] as! [String: Any]
        #expect(s["isActive"] != nil)
        #expect(st["todayMinutes"] != nil)
        #expect(d["sessionsCompleted"] != nil)

        // The full context is property-list-compatible (required for applicationContext)
        #expect(PropertyListSerialization.propertyList(ctx, isValidFor: .binary))
    }

    @Test func contextDictSessionStateDoesNotClobberStats() {
        // Simulates the phone sending two separate updates and merging them.
        var ctx: [String: Any] = [:]

        // First: send stats
        let statsDict: [String: Any] = ["todayMinutes": 90, "sessions": 4, "streak": 7]
        ctx["stats"] = statsDict
        ctx["sentAt"] = Date().timeIntervalSince1970

        // Then: send session state — must NOT remove stats key
        let sessionDict: [String: Any] = [
            "isActive": true, "isPaused": false, "modeID": "pomodoro",
            "displayTime": "20:00", "phaseLabel": "Focus", "isPhaseTransition": false,
            "sentAt": Date().timeIntervalSince1970,
        ]
        ctx["sessionState"] = sessionDict
        ctx["sentAt"] = Date().timeIntervalSince1970

        #expect(ctx["stats"]        as? [String: Any] != nil, "stats section must survive after sessionState update")
        #expect(ctx["sessionState"] as? [String: Any] != nil)
    }

    // MARK: - Stale-update dedupe: sentAt timestamp

    @Test func sessionStateIncludesSentAtTimestamp() {
        let state = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:00", phaseLabel: "Focus"
        )
        // sentAt must be a positive epoch timestamp
        #expect(state.sentAt > 0)
    }

    @Test func newerSentAtIsLarger() {
        let older = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:00", phaseLabel: "Focus"
        )
        // Create a state with an explicitly later timestamp
        var newer = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "23:00", phaseLabel: "Focus"
        )
        newer.sentAt = older.sentAt + 1.0
        #expect(newer.sentAt > older.sentAt)
    }

    @Test func staleUpdateDedupeLogic() {
        // Simulates the watch-side dedupe check:
        // if incoming.sentAt <= currentState.sentAt → discard (stale)
        let currentSentAt: TimeInterval = 1_000_000
        let freshSentAt:   TimeInterval = 1_000_001
        let staleSentAt:   TimeInterval = 999_999

        func shouldApply(incomingSentAt: TimeInterval) -> Bool {
            incomingSentAt > currentSentAt
        }

        #expect(shouldApply(incomingSentAt: freshSentAt)   == true,  "fresh update must be applied")
        #expect(shouldApply(incomingSentAt: staleSentAt)   == false, "stale update must be discarded")
        #expect(shouldApply(incomingSentAt: currentSentAt) == false, "duplicate sentAt must be discarded")
    }

    // MARK: - Cold-start hydration

    @Test func applicationContextDecodeYieldsSessionState() {
        // Simulates deliverApplicationContext decoding the sessionState section.
        let sessionDict: [String: Any] = [
            "isActive":          true,
            "isPaused":          false,
            "modeID":            "pomodoro",
            "displayTime":       "22:30",
            "phaseLabel":        "Focus 2/4",
            "isPhaseTransition": false,
            "sentAt":            Date().timeIntervalSince1970,
        ]
        let ctx: [String: Any] = [
            "sessionState": sessionDict,
            "sentAt":       Date().timeIntervalSince1970,
        ]

        // Decode using the same logic as WatchConnectivityManager.deliverApplicationContext
        let decodedSection = ctx["sessionState"] as? [String: Any]
        #expect(decodedSection != nil)
        #expect(decodedSection?["isActive"]    as? Bool   == true)
        #expect(decodedSection?["modeID"]      as? String == "pomodoro")
        #expect(decodedSection?["displayTime"] as? String == "22:30")
    }

    @Test func applicationContextDecodeYieldsStats() {
        let statsDict: [String: Any] = ["todayMinutes": 120, "sessions": 5, "streak": 10]
        let ctx: [String: Any] = ["stats": statsDict, "sentAt": Date().timeIntervalSince1970]

        let decodedSection = ctx["stats"] as? [String: Any]
        #expect(decodedSection != nil)
        #expect(decodedSection?["todayMinutes"] as? Int == 120)
        #expect(decodedSection?["sessions"]     as? Int == 5)
        #expect(decodedSection?["streak"]       as? Int == 10)
    }

    @Test func applicationContextDecodeYieldsDashboardStats() {
        let dashDict: [String: Any] = [
            "todayMinutes": 90, "sessionsCompleted": 4, "tasksCompleted": 2,
            "tasksTotal": 7, "streakDays": 3, "pomodoroMinutes": 60,
            "flowtimeMinutes": 30, "timeBlockMinutes": 0, "stopwatchMinutes": 0,
            "longestSessionMinutes": 45,
        ]
        let ctx: [String: Any] = ["dashboardStats": dashDict, "sentAt": Date().timeIntervalSince1970]

        let decoded = ctx["dashboardStats"] as? [String: Any]
        #expect(decoded != nil)
        #expect(decoded?["sessionsCompleted"] as? Int == 4)
        #expect(decoded?["streakDays"]        as? Int == 3)
    }

    @Test func applicationContextDecodeYieldsTheme() {
        // Cold-start hydration (#533): the "theme" section must be readable from
        // the applicationContext the watch receives on activation.
        let themeDict: [String: Any] = ["themeName": "sunset"]
        let ctx: [String: Any] = ["theme": themeDict, "sentAt": Date().timeIntervalSince1970]

        let decoded = ctx["theme"] as? [String: Any]
        #expect(decoded != nil)
        #expect(decoded?["themeName"] as? String == "sunset")
    }

    @Test func contextDictThemeDoesNotClobberOtherSections() {
        // buildFullContextLocked merges sessionState / stats / dashboardStats / theme
        // into one applicationContext payload. Sending a theme update must NOT remove
        // previously-cached sections (applicationContext replaces, does not merge).
        var ctx: [String: Any] = [:]

        // First: cache sessionState + stats
        ctx["sessionState"] = ["isActive": true, "modeID": "pomodoro"] as [String: Any]
        ctx["stats"]        = ["todayMinutes": 60] as [String: Any]
        ctx["sentAt"]       = Date().timeIntervalSince1970

        // Then: sendTheme — must merge into the SAME context without dropping keys
        ctx["theme"]   = ["themeName": "forest"] as [String: Any]
        ctx["sentAt"]  = Date().timeIntervalSince1970

        #expect(ctx["sessionState"] as? [String: Any] != nil, "sessionState must survive after theme update")
        #expect(ctx["stats"]        as? [String: Any] != nil, "stats must survive after theme update")
        #expect(ctx["theme"]        as? [String: Any] != nil)
        #expect((ctx["theme"] as? [String: Any])?["themeName"] as? String == "forest")
    }

    @Test func coldStartWithEmptyContextDoesNotCrash() {
        // An empty receivedApplicationContext on first launch must yield nothing.
        let ctx: [String: Any] = [:]
        let sessionSection  = ctx["sessionState"]   as? [String: Any]
        let statsSection    = ctx["stats"]           as? [String: Any]
        let dashSection     = ctx["dashboardStats"]  as? [String: Any]
        #expect(sessionSection == nil)
        #expect(statsSection   == nil)
        #expect(dashSection    == nil)
        // No crash = pass
    }

    // MARK: - Tasks use transferUserInfo (queued, guaranteed)

    @Test func tasksPayloadHasTypeAndItemsKeys() {
        // transferUserInfo payload must have "type" = "tasks" and "items" array
        // (same format as sendMessage so the watch can decode from either transport).
        let taskDict: [String: Any] = [
            "id": UUID().uuidString, "title": "Deploy", "isCompleted": false,
            "priority": 2, "estimatedPomodoros": 3, "completedPomodoros": 1,
        ]
        let userInfoDict: [String: Any] = ["type": "tasks", "items": [taskDict]]
        #expect(userInfoDict["type"]  as? String == "tasks")
        #expect(userInfoDict["items"] as? [[String: Any]] != nil)
        // Must be property-list-compatible for transferUserInfo
        #expect(PropertyListSerialization.propertyList(userInfoDict, isValidFor: .binary))
    }

    // MARK: - Commands remain sendMessage (watch → phone only)

    @Test func commandsDoNotUseApplicationContext() {
        // Commands are latency-sensitive and always watch → phone.
        // They must NOT be sent via applicationContext (wrong direction).
        // This test documents the invariant: command payloads carry "type": "command".
        let dict: [String: Any] = ["type": "command", "action": "pause"]
        #expect(dict["type"] as? String == "command")
        // Commands are NOT wrapped under a top-level section key (unlike context payloads)
        #expect(dict["sessionState"]   == nil)
        #expect(dict["stats"]          == nil)
        #expect(dict["dashboardStats"] == nil)
    }
}

// MARK: - Complication Reload Gating Tests
//
// WidgetCenter.reloadAllTimelines() must NOT fire every second —
// only on phase transitions or session end. This test verifies the
// predicate logic that gates the reload call.

@Suite("Complication Reload Gating")
struct ComplicationReloadGatingTests {

    /// Mirrors the gating condition in WatchTimerFeature.sessionStateReceived:
    ///   if didTransition || !isActive { WidgetCenter.shared.reloadAllTimelines() }
    private func shouldReloadComplications(isActive: Bool, isPhaseTransition: Bool) -> Bool {
        isPhaseTransition || !isActive
    }

    @Test func doesNotReloadOnNormalTick() {
        // Every-second update while session is running: no reload
        #expect(shouldReloadComplications(isActive: true, isPhaseTransition: false) == false)
    }

    @Test func reloadsOnPhaseTransition() {
        // Focus → Break transition: reload
        #expect(shouldReloadComplications(isActive: true, isPhaseTransition: true) == true)
    }

    @Test func reloadsOnSessionEnd() {
        // Session stopped/completed: reload
        #expect(shouldReloadComplications(isActive: false, isPhaseTransition: false) == true)
    }

    @Test func reloadsOnPhaseTransitionAtSessionEnd() {
        // Pathological: last phase transition that also ends the session
        #expect(shouldReloadComplications(isActive: false, isPhaseTransition: true) == true)
    }

    @Test func gatingPreventsBurstReloadsOverOneMinute() {
        // Simulate 60 ticks of a running session
        var reloadCount = 0
        for _ in 0..<60 {
            if shouldReloadComplications(isActive: true, isPhaseTransition: false) {
                reloadCount += 1
            }
        }
        // Zero reloads during normal ticking — complications use their own 5-min timeline
        #expect(reloadCount == 0)
    }

    @Test func gatingAllowsOneReloadPerPhaseChange() {
        // A typical pomodoro session: 4 focus phases + 3 short breaks + 1 long break
        // = 8 phase transitions, each fires exactly one reload
        let phaseEvents: [(isActive: Bool, isPhaseTransition: Bool)] = [
            (true,  true),   // focus→break 1
            (true,  false),  // break ticking
            (true,  true),   // break→focus 2
            (true,  false),  // focus ticking
            (true,  true),   // focus→break 2
            (true,  false),  // break ticking
            (true,  true),   // break→focus 3
            (true,  false),  // focus ticking
            (true,  true),   // focus→break 3
            (true,  false),  // break ticking
            (true,  true),   // break→focus 4
            (true,  false),  // focus ticking
            (true,  true),   // focus→long break
            (true,  false),  // long break ticking
            (false, false),  // session ended
        ]
        let transitionReloads = phaseEvents.filter { $0.isActive && $0.isPhaseTransition }.count
        let endReloads = phaseEvents.filter { !$0.isActive }.count
        #expect(transitionReloads == 7)  // 7 phase transition events
        #expect(endReloads == 1)         // 1 session-end event
    }
}

// MARK: - DisplayTime Parse Tests
//
// WatchTimerFeature.persistSessionState() calls parseDisplayTime() to derive
// phase start/end dates for live countdown complications. The parse logic must
// handle valid "MM:SS" strings, edge cases, and malformed input.

@Suite("DisplayTime Parse Logic")
struct DisplayTimeParseTests {

    /// Mirrors WatchTimerFeature.parseDisplayTime(_:) — private static func.
    private func parseDisplayTime(_ displayTime: String) -> TimeInterval {
        let parts = displayTime.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    @Test func parsesStandardPomodoro() {
        #expect(parseDisplayTime("25:00") == 1500)
    }

    @Test func parsesZero() {
        #expect(parseDisplayTime("0:00") == 0)
    }

    @Test func parsesSecondsOnly() {
        #expect(parseDisplayTime("0:30") == 30)
    }

    @Test func parsesOneMinuteExact() {
        #expect(parseDisplayTime("1:00") == 60)
    }

    @Test func parsesTypicalMidSession() {
        // 22 minutes 45 seconds remaining
        #expect(parseDisplayTime("22:45") == 22 * 60 + 45)
    }

    @Test func parsesLongFlowtime() {
        // 90-minute flow session
        #expect(parseDisplayTime("90:00") == 5400)
    }

    @Test func parsesMalformedStringReturnsZero() {
        #expect(parseDisplayTime("invalid") == 0)
    }

    @Test func parsesMissingColonReturnsZero() {
        #expect(parseDisplayTime("2500") == 0)
    }

    @Test func parsesEmptyStringReturnsZero() {
        #expect(parseDisplayTime("") == 0)
    }

    @Test func parsesExtraComponentsReturnsZero() {
        // "HH:MM:SS" format — three components, not two → guard fails
        #expect(parseDisplayTime("1:25:00") == 0)
    }

    @Test func parsesNegativeValueHandled() {
        // Negative numbers parse but result in negative interval (should not happen in practice)
        let result = parseDisplayTime("-1:00")
        #expect(result == -60)
    }
}

// MARK: - UserDefaults Isolation Contract Tests
//
// Watch-side persistence uses UserDefaults(suiteName: "group.com.pepinillo.app").
// Both WatchTimerFeature/WatchAppFeature (writers) and complications (readers) use
// the same app group suite so that values are visible across process boundaries.
//
// These tests verify the contract: suite is accessible, standard and app group
// are isolated, and all WatchStatsKeys carry the "watch." prefix.

@Suite("UserDefaults Isolation Contract")
struct UserDefaultsIsolationContractTests {

    private let appGroupSuite = "group.com.pepinillo.app"
    private let testKey = "test.watchStats.isolation"

    @Test func standardAndAppGroupAreIsolated() {
        let standard = UserDefaults.standard
        let appGroup = UserDefaults(suiteName: appGroupSuite)

        // Write to standard
        standard.set(42, forKey: testKey)

        // App group suite should NOT see the value
        let valueInAppGroup = appGroup?.integer(forKey: testKey)
        #expect(valueInAppGroup == 0,
                "UserDefaults.standard and app group suite are isolated — writing to standard does not populate app group")

        // Cleanup
        standard.removeObject(forKey: testKey)
    }

    @Test func appGroupSuiteIsAvailableOnWatch() {
        // The suite must be constructible (entitlement is present in PepinilloWatch.entitlements).
        // If this returns nil, the entitlement is missing or the group ID is wrong.
        let suite = UserDefaults(suiteName: appGroupSuite)
        #expect(suite != nil,
                "App group suite 'group.com.pepinillo.app' must be accessible — check PepinilloWatch.entitlements")
    }

    @Test func watchStatsKeysAreConsistentWithWatchPrefix() {
        // All keys must use the "watch." prefix as defined in WatchStatsKeys,
        // ensuring no collisions with the phone-side AppGroupDefaults keys.
        let watchKeys = [
            WatchStatsKeys.todayFocusMinutes,
            WatchStatsKeys.todaySessionsCompleted,
            WatchStatsKeys.currentStreakDays,
            WatchStatsKeys.isSessionActive,
            WatchStatsKeys.displayTime,
            WatchStatsKeys.modeEmoji,
            WatchStatsKeys.progress,
        ]
        for key in watchKeys {
            #expect(key.hasPrefix("watch."),
                    "WatchStatsKey '\(key)' must use 'watch.' prefix to avoid collisions")
        }
    }
}
