// WatchConnectivityClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency wrapping WatchConnectivity.
// Lives in Domain/Clients/ so BOTH targets compile it:
//   - iOS main app: receives WatchCommands, sends WatchSessionState + stats
//   - watchOS app:  sends WatchCommands, receives WatchSessionState + stats
//
// Xcode setup: add this file to BOTH the main app and Watch app targets.

import Foundation
import ComposableArchitecture
#if canImport(WatchConnectivity)
import WatchConnectivity
import os.log
#endif

// MARK: - Shared Value Types

/// State snapshot sent from iOS → Watch every timer tick.
struct WatchSessionState: Equatable, Sendable {
    var isActive: Bool
    var isPaused: Bool
    var modeID: String
    var displayTime: String
    var phaseLabel: String
    var progress: Double?
    var pomodoroNumber: Int?
    var linkedTaskTitle: String?
    var linkedTaskID: String?
    /// True on the first tick after a phase change — triggers haptic on Watch.
    var isPhaseTransition: Bool = false

    static let idle = WatchSessionState(
        isActive: false, isPaused: false, modeID: "pomodoro",
        displayTime: "25:00", phaseLabel: "Ready"
    )
}

/// Lightweight task representation sent iOS → Watch.
struct WatchTaskItem: Equatable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let priority: Int          // maps to TaskPriority raw value
    let estimatedPomodoros: Int
    let completedPomodoros: Int
}

/// Dashboard stats sent iOS → Watch.
struct WatchDashboardStats: Equatable, Sendable {
    let todayMinutes: Int
    let sessionsCompleted: Int
    let tasksCompleted: Int
    let tasksTotal: Int
    let streakDays: Int
    let pomodoroMinutes: Int
    let flowtimeMinutes: Int
    let timeBlockMinutes: Int
    let stopwatchMinutes: Int
    let longestSessionMinutes: Int
}

/// Commands sent from Watch → iOS.
enum WatchCommand: Equatable, Sendable {
    case startSession(mode: String)
    case pauseSession
    case resumeSession
    case stopSession
    case skipPhase
    case linkTask(id: String)
    case unlinkTask
    case toggleTaskCompleted(id: String)
    case requestTasks
    case requestDashboard
}

/// Messages received on each side from the counterpart.
enum WatchMessage: Equatable, Sendable {
    /// iOS → Watch: live session state (every tick).
    case sessionState(WatchSessionState)
    /// iOS → Watch: daily stats (on session complete or app launch).
    case stats(todayMinutes: Int, sessions: Int, streak: Int)
    /// iOS → Watch: today's task list.
    case tasks([WatchTaskItem])
    /// iOS → Watch: dashboard stats.
    case dashboardStats(WatchDashboardStats)
    /// Both sides: reachability changes.
    case connectivityStatus(Bool)
    /// Watch → iOS: user tapped a control on the Watch.
    case command(WatchCommand)
}

// MARK: - WatchConnectivityClient

@DependencyClient
struct WatchConnectivityClient: Sendable {
    /// Infinite stream of messages from the counterpart device.
    var receiveMessages: @Sendable () async -> AsyncStream<WatchMessage> = { .finished }

    /// Watch → iOS: send a session control command.
    var sendCommand: @Sendable (WatchCommand) async -> Void = { _ in }

    /// iOS → Watch: push the latest session state.
    var sendSessionState: @Sendable (WatchSessionState) async -> Void = { _ in }

    /// iOS → Watch: push today's focus stats.
    var sendStats: @Sendable (_ todayMinutes: Int, _ sessions: Int, _ streak: Int) async -> Void = { _, _, _ in }

    /// iOS → Watch: push today's task list.
    var sendTasks: @Sendable (_ tasks: [WatchTaskItem]) async -> Void = { _ in }

    /// iOS → Watch: push dashboard stats.
    var sendDashboardStats: @Sendable (WatchDashboardStats) async -> Void = { _ in }

    /// Whether WatchConnectivity is supported on this device.
    var isSupported: @Sendable () -> Bool = { false }
}

// MARK: - Dependency Keys

extension WatchConnectivityClient: DependencyKey {
    static let liveValue  = WatchConnectivityClient.live
    static let testValue  = WatchConnectivityClient()
}

extension DependencyValues {
    var watchConnectivityClient: WatchConnectivityClient {
        get { self[WatchConnectivityClient.self] }
        set { self[WatchConnectivityClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension WatchConnectivityClient {
    static let live: WatchConnectivityClient = {
#if canImport(WatchConnectivity)
        let manager = WatchConnectivityManager.shared
        return WatchConnectivityClient(
            receiveMessages:  { manager.messageStream() },
            sendCommand:      { cmd   in await manager.sendCommand(cmd) },
            sendSessionState: { state in await manager.sendSessionState(state) },
            sendStats:        { m, c, s in await manager.sendStats(todayMinutes: m, sessions: c, streak: s) },
            sendTasks:        { tasks in await manager.sendTasks(tasks) },
            sendDashboardStats: { stats in await manager.sendDashboardStats(stats) },
            isSupported:      { WCSession.isSupported() }
        )
#else
        return WatchConnectivityClient()
#endif
    }()
}

// MARK: - WatchConnectivityManager

#if canImport(WatchConnectivity)
final class WatchConnectivityManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchConnectivityManager()

    private var session: WCSession?
    private var continuation: AsyncStream<WatchMessage>.Continuation?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        session = s
    }

    // MARK: - Stream

    func messageStream() -> AsyncStream<WatchMessage> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(.connectivityStatus(session?.isReachable ?? false))
        }
    }

    // MARK: - Send (Watch → iOS direction)

    private static let log = Logger(subsystem: "com.pepinillo.app", category: "WatchConnectivity")

    func sendCommand(_ command: WatchCommand) async {
        guard let session, session.isReachable else { return }
        session.sendMessage(encodeCommand(command), replyHandler: nil) { error in
            Self.log.error("Watch sendCommand failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Send (iOS → Watch direction)

    func sendSessionState(_ state: WatchSessionState) async {
        guard let session, session.isReachable else { return }
        var dict: [String: Any] = [
            "type":             "sessionState",
            "isActive":         state.isActive,
            "isPaused":         state.isPaused,
            "modeID":           state.modeID,
            "displayTime":      state.displayTime,
            "phaseLabel":       state.phaseLabel,
            "isPhaseTransition": state.isPhaseTransition,
        ]
        if let p = state.progress        { dict["progress"]       = p }
        if let n = state.pomodoroNumber  { dict["pomodoroNumber"] = n }
        if let t = state.linkedTaskTitle { dict["linkedTaskTitle"] = t }
        if let t = state.linkedTaskID    { dict["linkedTaskID"]   = t }
        session.sendMessage(dict, replyHandler: nil) { error in
            Self.log.error("Watch sendSessionState failed: \(error.localizedDescription)")
        }
    }

    func sendStats(todayMinutes: Int, sessions: Int, streak: Int) async {
        guard let session, session.isReachable else { return }
        let dict: [String: Any] = [
            "type":         "stats",
            "todayMinutes": todayMinutes,
            "sessions":     sessions,
            "streak":       streak,
        ]
        session.sendMessage(dict, replyHandler: nil) { error in
            Self.log.error("Watch sendStats failed: \(error.localizedDescription)")
        }
    }

    func sendTasks(_ tasks: [WatchTaskItem]) async {
        guard let session, session.isReachable else { return }
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
        let dict: [String: Any] = [
            "type":  "tasks",
            "items": encoded,
        ]
        session.sendMessage(dict, replyHandler: nil) { error in
            Self.log.error("Watch sendTasks failed: \(error.localizedDescription)")
        }
    }

    func sendDashboardStats(_ stats: WatchDashboardStats) async {
        guard let session, session.isReachable else { return }
        let dict: [String: Any] = [
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
        session.sendMessage(dict, replyHandler: nil) { error in
            Self.log.error("Watch sendDashboardStats failed: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        continuation?.yield(.connectivityStatus(state == .activated))
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        continuation?.yield(.connectivityStatus(session.isReachable))
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "command":
            if let cmd = decodeCommand(message) {
                continuation?.yield(.command(cmd))
            }
        case "sessionState":
            if let state = decodeSessionState(message) {
                continuation?.yield(.sessionState(state))
            }
        case "stats":
            continuation?.yield(.stats(
                todayMinutes: message["todayMinutes"] as? Int ?? 0,
                sessions:     message["sessions"]     as? Int ?? 0,
                streak:       message["streak"]       as? Int ?? 0
            ))
        case "tasks":
            if let items = decodeTasks(message) {
                continuation?.yield(.tasks(items))
            }
        case "dashboardStats":
            if let stats = decodeDashboardStats(message) {
                continuation?.yield(.dashboardStats(stats))
            }
        default:
            break
        }
    }

    // Required on iOS (not on watchOS)
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    // MARK: - Encode / Decode

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

    private func decodeCommand(_ message: [String: Any]) -> WatchCommand? {
        guard let action = message["action"] as? String else { return nil }
        switch action {
        case "start":         return .startSession(mode: message["mode"] as? String ?? "pomodoro")
        case "pause":         return .pauseSession
        case "resume":        return .resumeSession
        case "stop":          return .stopSession
        case "skip":          return .skipPhase
        case "linkTask":      return .linkTask(id: message["taskID"] as? String ?? "")
        case "unlinkTask":    return .unlinkTask
        case "toggleTask":    return .toggleTaskCompleted(id: message["taskID"] as? String ?? "")
        case "requestTasks":  return .requestTasks
        case "requestDashboard": return .requestDashboard
        default:              return nil
        }
    }

    private func decodeSessionState(_ message: [String: Any]) -> WatchSessionState? {
        guard let isActive    = message["isActive"]    as? Bool,
              let isPaused    = message["isPaused"]    as? Bool,
              let modeID      = message["modeID"]      as? String,
              let displayTime = message["displayTime"] as? String,
              let phaseLabel  = message["phaseLabel"]  as? String
        else { return nil }

        return WatchSessionState(
            isActive:         isActive,
            isPaused:         isPaused,
            modeID:           modeID,
            displayTime:      displayTime,
            phaseLabel:       phaseLabel,
            progress:         message["progress"]        as? Double,
            pomodoroNumber:   message["pomodoroNumber"]  as? Int,
            linkedTaskTitle:  message["linkedTaskTitle"] as? String,
            linkedTaskID:     message["linkedTaskID"]    as? String,
            isPhaseTransition: message["isPhaseTransition"] as? Bool ?? false
        )
    }

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

    private func decodeDashboardStats(_ message: [String: Any]) -> WatchDashboardStats? {
        return WatchDashboardStats(
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
}
#endif
