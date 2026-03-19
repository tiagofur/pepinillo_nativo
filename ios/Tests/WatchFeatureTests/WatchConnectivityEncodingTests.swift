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
        let a = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4"
        )
        let b = WatchSessionState(
            isActive: true, isPaused: false, modeID: "pomodoro",
            displayTime: "24:30", phaseLabel: "Focus 1/4"
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
            isPhaseTransition: message["isPhaseTransition"] as? Bool ?? false
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
        case .toggleTaskCompleted(let id):  dict["action"] = "toggleTask"; dict["taskID"] = id
        case .requestTasks:                 dict["action"] = "requestTasks"
        case .requestDashboard:             dict["action"] = "requestDashboard"
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
        case "toggleTask":       return .toggleTaskCompleted(id: message["taskID"] as? String ?? "")
        case "requestTasks":     return .requestTasks
        case "requestDashboard": return .requestDashboard
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

    @Test func roundTripToggleTaskCompleted() {
        let cmd = WatchCommand.toggleTaskCompleted(id: "task-456")
        let dict = encodeCommand(cmd)
        #expect(dict["action"] as? String == "toggleTask")
        #expect(dict["taskID"] as? String == "task-456")
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
            .toggleTaskCompleted(id: "id-2"),
            .requestTasks,
            .requestDashboard,
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

    @Test func toggleTaskDiffersOnID() {
        #expect(WatchCommand.toggleTaskCompleted(id: "a") != WatchCommand.toggleTaskCompleted(id: "b"))
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
        let a = WatchMessage.tasks(tasks)
        let b = WatchMessage.tasks(tasks)
        #expect(a == b)
    }

    @Test func emptyTasksMessageEquals() {
        #expect(WatchMessage.tasks([]) == WatchMessage.tasks([]))
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
