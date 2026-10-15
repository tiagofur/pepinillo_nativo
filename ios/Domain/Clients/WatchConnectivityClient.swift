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
    /// True when the current phase is any break phase (short, long, or flow break).
    /// Carried as a typed flag so watch UI never has to parse localised strings.
    var isBreakPhase: Bool = false
    /// True only when the current phase is a long break.
    /// Allows watch UI to select the long-break colour variant without string parsing.
    var isLongBreakPhase: Bool = false
    /// True when the engine is holding for the user to manually start the next phase
    /// (autoStartBreaks/autoStartWork is OFF). The watch must suppress Pause/Resume
    /// and show a phase-aware "Start …" CTA instead.
    var isWaiting: Bool = false
    /// Timestamp of when this state was generated (for stale-update dedupe on watch).
    var sentAt: TimeInterval = Date().timeIntervalSince1970
    /// Absolute phase anchors from the phone engine (countdown families / local watch tick).
    var phaseStartDate: Date? = nil
    var phaseEndDate: Date? = nil
    /// When false, complications should not treat phaseEnd as a countdown target.
    var countsDown: Bool = true

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
    /// Absolute completion state — avoids double-toggle races with stale task payloads (#243).
    case setTaskCompleted(id: String, isCompleted: Bool)
    case requestTasks
    case requestDashboard
    /// Watch → iOS: request a fresh session snapshot (connect / cold-start hydration).
    case requestSession
    /// Watch → iOS: user tapped the "Start Break / Start Focus" CTA during a waiting hold.
    case startNextPhase
}

/// Messages received on each side from the counterpart.
enum WatchMessage: Equatable, Sendable {
    /// iOS → Watch: live session state (every tick).
    case sessionState(WatchSessionState)
    /// iOS → Watch: daily stats (on session complete or app launch).
    case stats(todayMinutes: Int, sessions: Int, streak: Int)
    /// iOS → Watch: today's task list.
    case tasks([WatchTaskItem], sentAt: TimeInterval)
    /// iOS → Watch: dashboard stats.
    case dashboardStats(WatchDashboardStats)
    /// iOS → Watch: theme identity (themeName, e.g. "default" / "forest" / "ocean" / "sunset").
    /// Pushed on theme change and on cold-start hydration so the watch can resolve
    /// accents via `AppTheme.named(_:)`. Rare event — never at tick rate.
    case theme(String)
    /// Both sides: reachability changes.
    case connectivityStatus(Bool)
    /// Watch → iOS: user tapped a control on the Watch.
    case command(WatchCommand)
}

// MARK: - WatchConnectivityClient

struct WatchConnectivityClient: Sendable {
    /// Infinite stream of messages from the counterpart device.
    var receiveMessages: @Sendable () async -> AsyncStream<WatchMessage> = { .finished }

    /// Watch → iOS: send a session control command. Returns whether an immediate delivery was attempted.
    var sendCommand: @Sendable (WatchCommand) async -> Bool = { _ in false }

    /// iOS → Watch: push the latest session state.
    /// - Parameter publishContext: when true, also writes `applicationContext` (transitions/connect).
    var sendSessionState: @Sendable (WatchSessionState, Bool) async -> Void = { _, _ in }

    /// iOS → Watch: push today's focus stats.
    var sendStats: @Sendable (_ todayMinutes: Int, _ sessions: Int, _ streak: Int) async -> Void = { _, _, _ in }

    /// iOS → Watch: push today's task list.
    var sendTasks: @Sendable (_ tasks: [WatchTaskItem]) async -> Void = { _ in }

    /// iOS → Watch: push dashboard stats.
    var sendDashboardStats: @Sendable (WatchDashboardStats) async -> Void = { _ in }

    /// iOS → Watch: push the selected theme name so the watch can resolve accents.
    /// Merged into `applicationContext` (cold-start hydration) + `sendMessage` when reachable.
    var sendTheme: @Sendable (_ themeName: String) async -> Void = { _ in }

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
            sendSessionState: { state, publishContext in await manager.sendSessionState(state, publishContext: publishContext) },
            sendStats:        { m, c, s in await manager.sendStats(todayMinutes: m, sessions: c, streak: s) },
            sendTasks:        { tasks in await manager.sendTasks(tasks) },
            sendDashboardStats: { stats in await manager.sendDashboardStats(stats) },
            sendTheme:        { themeName in await manager.sendTheme(themeName) },
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

    // Multicast: all active subscribers receive every message.
    // Keyed by UUID so terminated streams can be removed (Continuation is a
    // struct — identity comparison via AnyObject boxing never matches).
    private var continuations: [UUID: AsyncStream<WatchMessage>.Continuation] = [:]
    private let continuationsLock = NSLock()

    // Phone-side context cache: always send a FULL context dict so applicationContext
    // merging never leaves stale keys from prior sends.  The phone holds the last
    // known values for every key and merges before each updateApplicationContext call.
    private var cachedSessionStateDict: [String: Any] = [:]
    private var cachedStatsDict: [String: Any] = [:]
    private var cachedDashboardStatsDict: [String: Any] = [:]
    private var cachedThemeDict: [String: Any] = [:]
    private let contextCacheLock = NSLock()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        session = s
    }

    // MARK: - Stream

    /// Returns an AsyncStream that receives all messages from the counterpart.
    ///
    /// Multiple callers are safe: each gets an independent stream.  The continuation
    /// is added to the multicast list and removed when the stream is cancelled.
    func messageStream() -> AsyncStream<WatchMessage> {
        AsyncStream { continuation in
            let id = UUID()
            continuationsLock.lock()
            continuations[id] = continuation
            continuationsLock.unlock()

            // Deliver current reachability immediately so the subscriber has initial state.
            continuation.yield(.connectivityStatus(session?.isReachable ?? false))

            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.continuationsLock.lock()
                self.continuations[id] = nil
                self.continuationsLock.unlock()
            }
        }
    }

    // MARK: - Send (Watch → iOS direction: always sendMessage — correct)

    private static let log = Logger(subsystem: "com.pepinillo.app", category: "WatchConnectivity")

    @discardableResult
    func sendCommand(_ command: WatchCommand) async -> Bool {
        guard let session else { return false }
        let payload = encodeCommand(command)
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                Self.log.error("Watch sendCommand failed: \(error.localizedDescription)")
            }
            return true
        }

        // Queue critical commands for delivery when the phone wakes (#238).
        var queued = payload
        queued["type"] = "command"
        session.transferUserInfo(queued)
        return false
    }

    // MARK: - Send (iOS → Watch direction)
    //
    // Transport semantics (changed from all-sendMessage to per-payload strategy):
    //
    //   sessionState  → updateApplicationContext (guaranteed on wake) +
    //                   sendMessage when reachable (low-latency live updates)
    //   stats         → merged into applicationContext (same updateApplicationContext call)
    //   dashboardStats→ merged into applicationContext
    //   tasks         → transferUserInfo (queued, guaranteed) +
    //                   sendMessage when reachable for latency
    //   commands      → sendMessage (Watch→phone only, correct as-is)
    //
    // Context dict shape (top-level keys, never clobber each other):
    //   "sessionState": { ... }
    //   "stats":        { ... }
    //   "dashboardStats": { ... }
    //   "sentAt": TimeInterval   (for stale-update dedupe on the watch side)
    //
    // The phone maintains a cache of the last-sent values per section so it can
    // always write the FULL context dict (applicationContext does not merge — it
    // replaces, so we must send all sections together every time).

    func sendSessionState(_ state: WatchSessionState, publishContext: Bool) async {
        guard let session else { return }

        var sessionDict: [String: Any] = [
            "isActive":          state.isActive,
            "isPaused":          state.isPaused,
            "modeID":            state.modeID,
            "displayTime":       state.displayTime,
            "phaseLabel":        state.phaseLabel,
            "isPhaseTransition": state.isPhaseTransition,
            "isBreakPhase":      state.isBreakPhase,
            "isLongBreakPhase":  state.isLongBreakPhase,
            "isWaiting":         state.isWaiting,
            "sentAt":            state.sentAt,
            "countsDown":        state.countsDown,
        ]
        if let p = state.progress        { sessionDict["progress"]        = p }
        if let n = state.pomodoroNumber  { sessionDict["pomodoroNumber"]  = n }
        if let t = state.linkedTaskTitle { sessionDict["linkedTaskTitle"] = t }
        if let t = state.linkedTaskID    { sessionDict["linkedTaskID"]    = t }
        if let start = state.phaseStartDate {
            sessionDict["phaseStartDate"] = start.timeIntervalSince1970
        }
        if let end = state.phaseEndDate {
            sessionDict["phaseEndDate"] = end.timeIntervalSince1970
        }

        if publishContext {
            // Transitions / connect / launch: persist full snapshot for cold-start hydration (#239).
            let fullContext = updateContextCache { self.cachedSessionStateDict = sessionDict }
            do {
                try session.updateApplicationContext(fullContext)
            } catch {
                Self.log.error("updateApplicationContext(sessionState) failed: \(error.localizedDescription)")
            }
        }

        // Live ticks use sendMessage only — avoids ~1Hz applicationContext thrash (#246).
        if session.isReachable {
            var messageDict = sessionDict
            messageDict["type"] = "sessionState"
            session.sendMessage(messageDict, replyHandler: nil) { error in
                Self.log.error("sendMessage(sessionState) failed: \(error.localizedDescription)")
            }
        }
    }

    func sendStats(todayMinutes: Int, sessions: Int, streak: Int) async {
        guard let session else { return }

        let statsDict: [String: Any] = [
            "todayMinutes": todayMinutes,
            "sessions":     sessions,
            "streak":       streak,
        ]

        let fullContext = updateContextCache { self.cachedStatsDict = statsDict }

        do {
            try session.updateApplicationContext(fullContext)
        } catch {
            Self.log.error("updateApplicationContext(stats) failed: \(error.localizedDescription)")
        }

        // Also send via message for low-latency update if reachable
        if session.isReachable {
            var messageDict = statsDict
            messageDict["type"] = "stats"
            session.sendMessage(messageDict, replyHandler: nil) { error in
                Self.log.error("sendMessage(stats) failed: \(error.localizedDescription)")
            }
        }
    }

    func sendTasks(_ tasks: [WatchTaskItem]) async {
        guard let session else { return }

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
            "type":   "tasks",
            "items":  encoded,
            "sentAt": Date().timeIntervalSince1970,
        ]

        // Guaranteed delivery: transferUserInfo queues the payload and delivers
        // it in order even when the watch app is not reachable.
        session.transferUserInfo(dict)

        // Low-latency: also sendMessage when reachable
        if session.isReachable {
            session.sendMessage(dict, replyHandler: nil) { error in
                Self.log.error("sendMessage(tasks) failed: \(error.localizedDescription)")
            }
        }
    }

    func sendDashboardStats(_ stats: WatchDashboardStats) async {
        guard let session else { return }

        let dashboardDict: [String: Any] = [
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

        let fullContext = updateContextCache { self.cachedDashboardStatsDict = dashboardDict }

        do {
            try session.updateApplicationContext(fullContext)
        } catch {
            Self.log.error("updateApplicationContext(dashboardStats) failed: \(error.localizedDescription)")
        }

        if session.isReachable {
            var messageDict = dashboardDict
            messageDict["type"] = "dashboardStats"
            session.sendMessage(messageDict, replyHandler: nil) { error in
                Self.log.error("sendMessage(dashboardStats) failed: \(error.localizedDescription)")
            }
        }
    }

    /// iOS → Watch: push the selected theme name.
    ///
    /// Theme changes are rare (a few times ever), so we always republish the full
    /// `applicationContext` (cold-start hydration for the watch) AND `sendMessage`
    /// when reachable for low-latency live update. Merged into the same
    /// applicationContext as sessionState/stats/dashboardStats via `updateContextCache`
    /// — the top-level `"theme"` key never clobbers the other sections.
    func sendTheme(_ themeName: String) async {
        guard let session else { return }

        let themeDict: [String: Any] = [
            "themeName": themeName,
        ]

        let fullContext = updateContextCache { self.cachedThemeDict = themeDict }

        do {
            try session.updateApplicationContext(fullContext)
        } catch {
            Self.log.error("updateApplicationContext(theme) failed: \(error.localizedDescription)")
        }

        if session.isReachable {
            var messageDict = themeDict
            messageDict["type"] = "theme"
            session.sendMessage(messageDict, replyHandler: nil) { error in
                Self.log.error("sendMessage(theme) failed: \(error.localizedDescription)")
            }
        }
    }

    /// Applies a cache mutation under the lock and returns the merged full context.
    /// Synchronous on purpose: NSLock.lock()/unlock() is unavailable in async
    /// contexts under Swift 6, and no suspension may occur while holding the lock.
    private func updateContextCache(_ mutate: () -> Void) -> [String: Any] {
        contextCacheLock.lock()
        defer { contextCacheLock.unlock() }
        mutate()
        return buildFullContextLocked()
    }

    /// Merges all cached section dicts into a single applicationContext payload.
    /// Must be called while holding contextCacheLock.
    private func buildFullContextLocked() -> [String: Any] {
        var ctx: [String: Any] = [:]
        if !cachedSessionStateDict.isEmpty {
            ctx["sessionState"] = cachedSessionStateDict
        }
        if !cachedStatsDict.isEmpty {
            ctx["stats"] = cachedStatsDict
        }
        if !cachedDashboardStatsDict.isEmpty {
            ctx["dashboardStats"] = cachedDashboardStatsDict
        }
        if !cachedThemeDict.isEmpty {
            ctx["theme"] = cachedThemeDict
        }
        ctx["sentAt"] = Date().timeIntervalSince1970
        return ctx
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        // Drive watch UI from reachability, not activation alone (#238).
        yield(.connectivityStatus(state == .activated && session.isReachable))

        // Cold-start hydration: when activation completes on the WATCH side,
        // read any previously delivered applicationContext and surface it as messages.
        // On iOS this is a no-op (receivedApplicationContext is empty there).
        if state == .activated {
            let ctx = session.receivedApplicationContext
            if !ctx.isEmpty {
                deliverApplicationContext(ctx)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        yield(.connectivityStatus(session.isReachable))
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "command":
            if let cmd = decodeCommand(message) {
                yield(.command(cmd))
            }
        case "sessionState":
            if let state = decodeSessionState(message) {
                yield(.sessionState(state))
            }
        case "stats":
            yield(.stats(
                todayMinutes: message["todayMinutes"] as? Int ?? 0,
                sessions:     message["sessions"]     as? Int ?? 0,
                streak:       message["streak"]       as? Int ?? 0
            ))
        case "tasks":
            if let items = decodeTasks(message) {
                let sentAt = message["sentAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                yield(.tasks(items, sentAt: sentAt))
            }
        case "dashboardStats":
            if let stats = decodeDashboardStats(message) {
                yield(.dashboardStats(stats))
            }
        case "theme":
            if let themeName = message["themeName"] as? String {
                yield(.theme(themeName))
            }
        default:
            break
        }
    }

    /// Handles applicationContext delivery (watch waking, cold-start hydration).
    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        deliverApplicationContext(applicationContext)
    }

    /// Maximum age of a queued watch command before it is dropped (S7). A tap
    /// made while the phone is dead must not execute hours later (e.g. an
    /// obsolete Start). Mirrors the 5-minute App Group command TTL.
    static let commandTTLSeconds: TimeInterval = 5 * 60

    /// Whether a queued watch command arrived too late to execute (S7).
    /// Missing stamps (older watch apps) are delivered, as before.
    static func isStaleCommand(sentAt: TimeInterval?, now: Date = Date.now) -> Bool {
        guard let sentAt = sentAt else { return false }
        return now.timeIntervalSince1970 - sentAt > commandTTLSeconds
    }

    /// Handles transferUserInfo delivery (guaranteed queued delivery for tasks).
    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "tasks":
            if let items = decodeTasks(userInfo) {
                let sentAt = userInfo["sentAt"] as? TimeInterval ?? Date().timeIntervalSince1970
                yield(.tasks(items, sentAt: sentAt))
            }
        case "command":
            // S7: drop commands queued longer than the TTL — e.g. Start tapped
            // with the phone dead would otherwise execute hours later.
            // Real-time sendMessage commands are fresh by construction.
            if Self.isStaleCommand(sentAt: userInfo["sentAt"] as? TimeInterval) {
                Self.log.info("Dropping stale queued watch command")
                break
            }
            if let cmd = decodeCommand(userInfo) {
                yield(.command(cmd))
            }
        default:
            break
        }
    }

    /// Unpacks a full applicationContext dict and yields one message per section present.
    /// Ignores sections whose sentAt is older than the most recently processed state
    /// (dedupe: the watch compares sentAt against its own current state timestamp
    ///  in the reducer; we surface the values here unconditionally and let the reducer
    ///  decide whether to apply them).
    private func deliverApplicationContext(_ ctx: [String: Any]) {
        if let sessionDict = ctx["sessionState"] as? [String: Any],
           let state = decodeSessionState(sessionDict) {
            yield(.sessionState(state))
        }
        if let statsDict = ctx["stats"] as? [String: Any] {
            yield(.stats(
                todayMinutes: statsDict["todayMinutes"] as? Int ?? 0,
                sessions:     statsDict["sessions"]     as? Int ?? 0,
                streak:       statsDict["streak"]       as? Int ?? 0
            ))
        }
        if let dashDict = ctx["dashboardStats"] as? [String: Any],
           let stats = decodeDashboardStats(dashDict) {
            yield(.dashboardStats(stats))
        }
        if let themeDict = ctx["theme"] as? [String: Any],
           let themeName = themeDict["themeName"] as? String {
            yield(.theme(themeName))
        }
    }

    // Required on iOS (not on watchOS)
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    // MARK: - Multicast yield helper

    private func yield(_ message: WatchMessage) {
        continuationsLock.lock()
        let snapshot = continuations
        continuationsLock.unlock()
        for continuation in snapshot.values {
            continuation.yield(message)
        }
    }

    // MARK: - Encode / Decode

    private func encodeCommand(_ command: WatchCommand) -> [String: Any] {
        // S7: stamp commands so stale queued deliveries can be dropped on receipt.
        var dict: [String: Any] = ["type": "command", "sentAt": Date().timeIntervalSince1970]
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
        case "setTaskCompleted":
            return .setTaskCompleted(
                id: message["taskID"] as? String ?? "",
                isCompleted: message["isCompleted"] as? Bool ?? false
            )
        case "requestTasks":    return .requestTasks
        case "requestDashboard": return .requestDashboard
        case "requestSession":  return .requestSession
        case "startNextPhase": return .startNextPhase
        default:               return nil
        }
    }

    private func decodeSessionState(_ message: [String: Any]) -> WatchSessionState? {
        guard let isActive    = message["isActive"]    as? Bool,
              let isPaused    = message["isPaused"]    as? Bool,
              let modeID      = message["modeID"]      as? String,
              let displayTime = message["displayTime"] as? String,
              let phaseLabel  = message["phaseLabel"]  as? String
        else { return nil }

        let isLongBreak = message["isLongBreakPhase"] as? Bool ?? false
        // Invariant: isLongBreakPhase implies isBreakPhase.
        // An inconsistent payload (isLongBreakPhase=true, isBreakPhase=false) would
        // hide the Skip button while showing the long-break colour; normalise here.
        let isBreak = isLongBreak || (message["isBreakPhase"] as? Bool ?? false)

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
            isBreakPhase:      isBreak,
            isLongBreakPhase:  isLongBreak,
            isWaiting:         message["isWaiting"]        as? Bool ?? false,
            sentAt:            message["sentAt"]           as? TimeInterval ?? Date().timeIntervalSince1970,
            phaseStartDate:    (message["phaseStartDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            phaseEndDate:      (message["phaseEndDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            countsDown:        message["countsDown"] as? Bool ?? true
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
