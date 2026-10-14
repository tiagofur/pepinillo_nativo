// AppGroupContainer.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared ModelContainer factory used by:
//   • Main app target (PepinilloApp)
//   • Widget target (PepinilloWidget)
//   • Intents target (PepinilloIntents)
//
// REQUIREMENTS (Xcode project setup):
//   1. Add App Group capability to all three targets: "group.com.pepinillo.app"
//   2. The store URL is inside the shared container directory so WidgetKit can read it.
//   3. The 1.0 release store is local-only. CloudKit reintroduction must not
//      reuse the launch-critical SQLite file.
//
// The main app MUST use this factory instead of constructing its own ModelContainer,
// otherwise the widget reads from a different SQLite file.

import Foundation
import SwiftData
import OSLog
import SQLite3

private let persistenceLogger = Logger(subsystem: "com.pepinillo.app", category: "persistence")

enum ModelContainerOpenTimeoutError: Error {
    case timedOut(label: String, seconds: TimeInterval)
}

private final class ModelContainerOpenContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ModelContainer, Error>?

    init(_ continuation: CheckedContinuation<ModelContainer, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<ModelContainer, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()

        switch result {
        case .success(let container):
            continuation.resume(returning: container)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

/// Opens a SwiftData container away from the main actor and returns on timeout
/// without waiting for the underlying SQLite/CloudKit open to become cancellable.
///
/// Do not implement this with `withThrowingTaskGroup`: structured concurrency waits
/// for cancelled children to finish before leaving the group, so a synchronous
/// `ModelContainer` open that hangs can still block app startup forever.
///
/// Double-resume safety: `ModelContainerOpenContinuationBox` uses an NSLock to
/// guarantee the continuation is resumed exactly once. Whichever GCD block calls
/// `box.resume(with:)` second finds `continuation == nil` and returns immediately,
/// discarding its result without any side effect on the Swift concurrency runtime.
///
/// PERF/SAFETY residual: if the open loses the race (timeout fires first), the
/// `make()` closure keeps running on the GCD thread until SQLite/CoreData returns.
/// That thread holds an open file descriptor to the shared store for the duration.
/// This is safe — the continuation cannot be double-resumed — but the background
/// open may briefly contend with the fallback container's WAL on disk.
/// Making it truly cancellable would require a `Task` with cooperative cancellation,
/// which SwiftData's synchronous `ModelContainer` initialiser does not support.
/// Acceptable risk for launch: the timeout path is the rare failure branch.
func openModelContainerOffMainThread(
    label: String,
    timeout seconds: TimeInterval,
    qos: DispatchQoS.QoSClass = .userInitiated,
    make: @escaping @Sendable () throws -> ModelContainer
) async throws -> ModelContainer {
    try await withCheckedThrowingContinuation { continuation in
        let box = ModelContainerOpenContinuationBox(continuation)

        DispatchQueue.global(qos: qos).async {
            box.resume(with: Result { try make() })
        }

        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + seconds) {
            persistenceLogger.error("Timed out opening ModelContainer '\(label, privacy: .public)' after \(seconds, privacy: .public)s")
            box.resume(with: .failure(ModelContainerOpenTimeoutError.timedOut(label: label, seconds: seconds)))
        }
    }
}

// MARK: - App Group Constants

enum AppGroup {
    static let id = "group.com.pepinillo.app"
    static let cloudKitContainerIdentifier = "iCloud.com.pepinillo.app"
    static let legacyCloudKitStoreFileName = "Pepinillo.sqlite"
    static let storeFileName = "PepinilloLocal.sqlite"
    static let appleCloudStoreFileName = "PepinilloAppleCloud.sqlite"

    /// Shared container URL (App Group directory).
    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: id
        ) else {
            // Fallback to documents directory when App Group not configured (Simulator / CI)
            guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return URL(fileURLWithPath: NSTemporaryDirectory())
            }
            return url
        }
        return url
    }

    /// Full URL to the shared SQLite store.
    static var storeURL: URL {
        containerURL.appendingPathComponent(storeFileName)
    }

    /// CloudKit-backed store used only for Pepinillo+ Apple-to-Apple sync.
    /// It is intentionally separate from the launch-critical local store.
    static var appleCloudStoreURL: URL {
        containerURL.appendingPathComponent(appleCloudStoreFileName)
    }

    /// Standalone app store used as a launch-safe fallback when the shared
    /// App Group SQLite store is unavailable on device.
    static var fallbackStoreURL: URL {
        let baseDirectory =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return baseDirectory.appendingPathComponent("PepinilloFallback.sqlite")
    }

    /// Per-launch fallback store. SwiftData can leave a failed persistent-store
    /// initialization in process-local state; using a fresh URL avoids reusing the
    /// same failed coordinator when the primary App Group store could not open.
    static func freshFallbackStoreURL() -> URL {
        let baseDirectory =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return baseDirectory
            .appendingPathComponent("PepinilloFallbackStores", isDirectory: true)
            .appendingPathComponent("PepinilloFallback-\(UUID().uuidString).sqlite")
    }

    /// Related SQLite sidecar files created by WAL journaling.
    static var storeSupportURLs: [URL] {
        let base = storeURL
        return [
            base,
            URL(fileURLWithPath: base.path + "-shm"),
            URL(fileURLWithPath: base.path + "-wal"),
        ]
    }

    /// Previous CloudKit-backed store kept only for future migration/recovery.
    static var legacyCloudKitStoreURL: URL {
        containerURL.appendingPathComponent(legacyCloudKitStoreFileName)
    }
}

// MARK: - App Group UserDefaults (cross-process communication)

enum AppGroupDefaults {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.id) }
    private static let userCapabilitiesKey = "userCapabilities"

    enum SyncMode: String, Codable, Sendable {
        case local
        case appleCloud
        case backend
    }

    enum SyncStatus: String, Codable, Sendable {
        case idle
        case activatingAppleCloud
        case appleCloudActive
        case appleCloudUnavailable
        case backendActive
        case localOnly
    }

    /// Whether the user has an active Pro subscription (read by widgets, extensions).
    static var isProUser: Bool {
        get { defaults?.bool(forKey: "isProUser") ?? false }
        set { defaults?.set(newValue, forKey: "isProUser") }
    }

    /// Whether the user tier allows backend VPS sync (Everywhere/AI+).
    static var canBackendSync: Bool {
        get { defaults?.bool(forKey: "canBackendSync") ?? false }
        set { defaults?.set(newValue, forKey: "canBackendSync") }
    }

    /// Whether the user tier allows Apple-only iCloud/CloudKit sync.
    static var canAppleCloudSync: Bool {
        get { defaults?.bool(forKey: "canAppleCloudSync") ?? false }
        set { defaults?.set(newValue, forKey: "canAppleCloudSync") }
    }

    /// The sync stack currently selected by the app.
    static var activeSyncMode: SyncMode {
        get {
            guard let raw = defaults?.string(forKey: "activeSyncMode"),
                  let mode = SyncMode(rawValue: raw) else {
                return .local
            }
            return mode
        }
        set { defaults?.set(newValue.rawValue, forKey: "activeSyncMode") }
    }

    /// Human-readable sync lifecycle state shared with widgets/extensions.
    static var syncStatus: SyncStatus {
        get {
            guard let raw = defaults?.string(forKey: "syncStatus"),
                  let status = SyncStatus(rawValue: raw) else {
                return .idle
            }
            return status
        }
        set { defaults?.set(newValue.rawValue, forKey: "syncStatus") }
    }

    /// Last recoverable CloudKit activation error.
    static var lastAppleCloudActivationError: String? {
        get { defaults?.string(forKey: "lastAppleCloudActivationError") }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: "lastAppleCloudActivationError")
            } else {
                defaults?.removeObject(forKey: "lastAppleCloudActivationError")
            }
        }
    }

    /// Date the subscription entitlement was last successfully verified online.
    static var lastVerifiedDate: Date? {
        get { defaults?.object(forKey: "lastVerifiedDate") as? Date }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: "lastVerifiedDate")
            } else {
                defaults?.removeObject(forKey: "lastVerifiedDate")
            }
        }
    }


    /// Full capability payload shared with widgets and extensions.
    static var userCapabilities: UserCapabilities? {
        get {
            guard let data = defaults?.data(forKey: userCapabilitiesKey) else { return nil }
            return try? JSONDecoder().decode(UserCapabilities.self, from: data)
        }
        set {
            guard let newValue else {
                defaults?.removeObject(forKey: userCapabilitiesKey)
                isProUser = false
                canBackendSync = false
                canAppleCloudSync = false
                return
            }

            if let data = try? JSONEncoder().encode(newValue) {
                defaults?.set(data, forKey: userCapabilitiesKey)
            }
            isProUser = newValue.hasAnyPremium
            canBackendSync = newValue.backendSync
            canAppleCloudSync = newValue.appleCloudSync && !newValue.backendSync
        }
    }

    /// Whether a focus session is currently active (read by widgets, Control Center, Siri).
    static var isSessionActive: Bool {
        get { defaults?.bool(forKey: "isSessionActive") ?? false }
        set { defaults?.set(newValue, forKey: "isSessionActive") }
    }

    /// External start request (from Siri, widget, Control Center).
    static var externalStartRequested: Bool {
        get { defaults?.bool(forKey: "externalStartRequested") ?? false }
        set { defaults?.set(newValue, forKey: "externalStartRequested") }
    }

    /// Unique command identifier used to avoid losing or double-consuming widget commands.
    static var externalCommandID: String? {
        get { defaults?.string(forKey: "externalCommandID") }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: "externalCommandID")
            } else {
                defaults?.removeObject(forKey: "externalCommandID")
            }
        }
    }

    /// Timestamp for the latest external command.
    static var externalCommandIssuedAt: Date? {
        get { defaults?.object(forKey: "externalCommandIssuedAt") as? Date }
        set {
            if let newValue {
                defaults?.set(newValue, forKey: "externalCommandIssuedAt")
            } else {
                defaults?.removeObject(forKey: "externalCommandIssuedAt")
            }
        }
    }

    /// External stop request (from Siri, widget, Control Center).
    static var externalStopRequested: Bool {
        get { defaults?.bool(forKey: "externalStopRequested") ?? false }
        set { defaults?.set(newValue, forKey: "externalStopRequested") }
    }

    /// External pause request (from widget / Siri).
    static var externalPauseRequested: Bool {
        get { defaults?.bool(forKey: "externalPauseRequested") ?? false }
        set { defaults?.set(newValue, forKey: "externalPauseRequested") }
    }

    /// External resume request (from Siri).
    static var externalResumeRequested: Bool {
        get { defaults?.bool(forKey: "externalResumeRequested") ?? false }
        set { defaults?.set(newValue, forKey: "externalResumeRequested") }
    }

    /// Requested focus mode ID (from Siri).
    static var requestedMode: String? {
        get { defaults?.string(forKey: "requestedMode") }
        set { defaults?.set(newValue, forKey: "requestedMode") }
    }

    /// Requested task ID (from Siri).
    static var requestedTaskID: String? {
        get { defaults?.string(forKey: "requestedTaskID") }
        set { defaults?.set(newValue, forKey: "requestedTaskID") }
    }

    /// Focus Filter toggle tracking (S3). The system invokes the filter intent
    /// on both activation AND deactivation with no direction flag.
    static var focusFilterActive: Bool {
        get { defaults?.bool(forKey: "focusFilterActive") ?? false }
        set { defaults?.set(newValue, forKey: "focusFilterActive") }
    }
    /// Widget mode selected before the filter was applied (S3). Restored on
    /// deactivation so the filter never permanently hijacks the widget mode.
    static var focusFilterPreviousMode: String? {
        get { defaults?.string(forKey: "focusFilterPreviousMode") }
        set { defaults?.set(newValue, forKey: "focusFilterPreviousMode") }
    }

    /// Task-completion command from the widget (S7). Unlike pause/resume/stop
    /// this is not time-sensitive, so it carries no TTL and survives
    /// stale-discard: clearExternalCommands() intentionally doesn't know these
    /// keys. The widget never writes SwiftData directly (multi-process lost
    /// updates); the app applies the completion on next activation.
    static var externalCompleteTaskRequested: Bool {
        get { defaults?.bool(forKey: "externalCompleteTaskRequested") ?? false }
        set { defaults?.set(newValue, forKey: "externalCompleteTaskRequested") }
    }
    static var externalCompleteTaskID: String? {
        get { defaults?.string(forKey: "externalCompleteTaskID") }
        set { defaults?.set(newValue, forKey: "externalCompleteTaskID") }
    }
    /// Reads + clears a pending task-completion command atomically (S7).
    /// Single-slot keys dedup repeat taps; setTaskCompleted's guard makes any
    /// redelivery a no-op. Nil when nothing is pending (or the ID is invalid).
    static func takeExternalCompleteTask() -> UUID? {
        guard externalCompleteTaskRequested,
              let idString = externalCompleteTaskID,
              let id = UUID(uuidString: idString) else {
            return nil
        }
        externalCompleteTaskRequested = false
        externalCompleteTaskID = nil
        return id
    }

    /// The focus mode currently selected in the widget (interactive selection).
    static var widgetSelectedMode: String? {
        get { defaults?.string(forKey: "widgetSelectedMode") }
        set { defaults?.set(newValue, forKey: "widgetSelectedMode") }
    }

    /// Cached pomodoro duration for widget proactive starts.
    static var pomodoroDuration: Double {
        get { positiveDouble(forKey: "pomodoroDuration", defaultValue: 25 * 60) }
        set { defaults?.set(newValue, forKey: "pomodoroDuration") }
    }

    /// Cached block duration for widget proactive starts.
    static var blockDuration: Double {
        get { positiveDouble(forKey: "blockDuration", defaultValue: 60 * 60) }
        set { defaults?.set(newValue, forKey: "blockDuration") }
    }

    /// Optional Siri/Shortcuts duration override for the next external start (#224).
    static var externalStartDurationMinutes: Int? {
        get {
            guard let value = defaults?.object(forKey: "externalStartDurationMinutes") as? Int,
                  value > 0 else { return nil }
            return value
        }
        set {
            if let value = newValue, value > 0 {
                defaults?.set(value, forKey: "externalStartDurationMinutes")
            } else {
                defaults?.removeObject(forKey: "externalStartDurationMinutes")
            }
        }
    }

    private static func positiveDouble(forKey key: String, defaultValue: Double) -> Double {
        guard let value = defaults?.object(forKey: key) as? Double, value > 0 else {
            return defaultValue
        }
        return value
    }

    /// Active session mode name (written by main app on start, read by Shortcuts).
    static var activeModeName: String? {
        get { defaults?.string(forKey: "activeModeName") }
        set { defaults?.set(newValue, forKey: "activeModeName") }
    }

    /// Active session elapsed seconds (written periodically by main app, read by Shortcuts).
    static var activeSessionElapsed: Double {
        get { defaults?.double(forKey: "activeSessionElapsed") ?? 0 }
        set { defaults?.set(newValue, forKey: "activeSessionElapsed") }
    }

    /// Active session remaining seconds (for countdown modes, written by main app, read by widgets).
    static var activeSessionRemaining: Double? {
        get {
            let val = defaults?.object(forKey: "activeSessionRemaining")
            return val as? Double
        }
        set {
            if let v = newValue {
                defaults?.set(v, forKey: "activeSessionRemaining")
            } else {
                defaults?.removeObject(forKey: "activeSessionRemaining")
            }
        }
    }

    /// Active session phase label (e.g. "Focus 2/4", "Short Break").
    static var activeSessionPhase: String? {
        get { defaults?.string(forKey: "activeSessionPhase") }
        set { defaults?.set(newValue, forKey: "activeSessionPhase") }
    }

    /// Active session progress (0.0–1.0 for countdown modes, nil for count-up).
    static var activeSessionProgress: Double? {
        get {
            let val = defaults?.object(forKey: "activeSessionProgress")
            return val as? Double
        }
        set {
            if let v = newValue {
                defaults?.set(v, forKey: "activeSessionProgress")
            } else {
                defaults?.removeObject(forKey: "activeSessionProgress")
            }
        }
    }

    /// Current pomodoro number (e.g. 2 in a 4-pomodoro cycle).
    static var activeSessionPomodoroNumber: Int? {
        get {
            let val = defaults?.object(forKey: "activeSessionPomodoroNumber")
            return val as? Int
        }
        set {
            if let v = newValue {
                defaults?.set(v, forKey: "activeSessionPomodoroNumber")
            } else {
                defaults?.removeObject(forKey: "activeSessionPomodoroNumber")
            }
        }
    }

    /// Total pomodoros per cycle.
    static var activeSessionTotalPomodoros: Int? {
        get {
            let val = defaults?.object(forKey: "activeSessionTotalPomodoros")
            return val as? Int
        }
        set {
            if let v = newValue {
                defaults?.set(v, forKey: "activeSessionTotalPomodoros")
            } else {
                defaults?.removeObject(forKey: "activeSessionTotalPomodoros")
            }
        }
    }

    /// Linked task title for the active session.
    static var activeSessionTaskTitle: String? {
        get { defaults?.string(forKey: "activeSessionTaskTitle") }
        set { defaults?.set(newValue, forKey: "activeSessionTaskTitle") }
    }

    /// Whether the active session is currently paused (read by widgets for Pause/Resume button).
    static var activeSessionIsPaused: Bool {
        get { defaults?.bool(forKey: "activeSessionIsPaused") ?? false }
        set { defaults?.set(newValue, forKey: "activeSessionIsPaused") }
    }

    /// Whether the engine is in the "waiting for next phase" hold (tick suspended,
    /// pendingNextPhase set). Widgets and intents read this to suppress pause/resume
    /// controls that would be misleading or harmful during the hold.
    static var activeSessionIsWaiting: Bool {
        get { defaults?.bool(forKey: "activeSessionIsWaiting") ?? false }
        set { defaults?.set(newValue, forKey: "activeSessionIsWaiting") }
    }

    /// Whether the visible session was started optimistically by a widget before
    /// the app reconciled it into the FocusEngine.
    static var activeSessionStartedFromWidget: Bool {
        get { defaults?.bool(forKey: "activeSessionStartedFromWidget") ?? false }
        set { defaults?.set(newValue, forKey: "activeSessionStartedFromWidget") }
    }

    /// Timestamp of an externally-applied pause. The app uses this to reconcile
    /// the engine as if the pause happened when the widget was tapped.
    static var activeSessionPausedAt: Date? {
        get { defaults?.object(forKey: "activeSessionPausedAt") as? Date }
        set { defaults?.set(newValue, forKey: "activeSessionPausedAt") }
    }

    /// Linked task ID for the active session (UUID string, read by Tasks widget for highlight).
    static var activeTaskID: String? {
        get { defaults?.string(forKey: "activeTaskID") }
        set { defaults?.set(newValue, forKey: "activeTaskID") }
    }

    /// Timestamp when current timer phase started (used by widgets for live Text(.timer) countdown).
    static var activeSessionTimerStart: Date? {
        get { defaults?.object(forKey: "activeSessionTimerStart") as? Date }
        set { defaults?.set(newValue, forKey: "activeSessionTimerStart") }
    }

    /// Target end date for countdown modes (used by widgets for Text(.timer) countdown).
    static var activeSessionTimerEnd: Date? {
        get { defaults?.object(forKey: "activeSessionTimerEnd") as? Date }
        set { defaults?.set(newValue, forKey: "activeSessionTimerEnd") }
    }

    /// Elapsed seconds derived from the current widget timer anchors.
    static func activeSessionLiveElapsed(at date: Date = Date.now) -> TimeInterval {
        if activeSessionIsPaused {
            return activeSessionElapsed
        }
        if let start = activeSessionTimerStart {
            return max(0, date.timeIntervalSince(start))
        }
        return activeSessionElapsed
    }

    /// Remaining seconds derived from the current widget timer anchors.
    static func activeSessionLiveRemaining(at date: Date = Date.now) -> TimeInterval? {
        if activeSessionIsPaused {
            return activeSessionRemaining
        }
        if let end = activeSessionTimerEnd {
            return max(0, end.timeIntervalSince(date))
        }
        return activeSessionRemaining
    }

    /// Freeze live elapsed/remaining and request an external pause (widget, Siri, etc.).
    /// Returns `false` when no active, unpaused session exists.
    @discardableResult
    static func requestExternalPause(at now: Date = .now) -> Bool {
        guard isSessionActive, !activeSessionIsPaused else { return false }

        let elapsed = activeSessionLiveElapsed(at: now)
        let remaining = activeSessionLiveRemaining(at: now)
        activeSessionElapsed = elapsed
        activeSessionRemaining = remaining

        if let remaining {
            let duration = max(elapsed + remaining, 1)
            activeSessionProgress = min(max(elapsed / duration, 0), 1)
        }

        externalCommandID = UUID().uuidString
        externalCommandIssuedAt = now
        externalResumeRequested = false
        externalPauseRequested = true
        activeSessionIsPaused = true
        activeSessionPausedAt = now
        return true
    }

    /// Re-anchor timers and request an external resume (widget, Siri, etc.).
    /// Returns `false` when no active, paused session exists.
    @discardableResult
    static func requestExternalResume(at now: Date = .now) -> Bool {
        guard isSessionActive, activeSessionIsPaused else { return false }

        if let remaining = activeSessionRemaining {
            let elapsed = activeSessionElapsed
            let duration = max(elapsed + remaining, 1)
            activeSessionTimerEnd = now.addingTimeInterval(remaining)
            activeSessionTimerStart = now.addingTimeInterval(-elapsed)
            activeSessionProgress = min(max(elapsed / duration, 0), 1)
            activeSessionRemaining = nil
        } else {
            activeSessionTimerStart = now.addingTimeInterval(-activeSessionElapsed)
        }

        activeSessionElapsed = activeSessionLiveElapsed(at: now)
        externalCommandID = UUID().uuidString
        externalCommandIssuedAt = now
        externalPauseRequested = false
        externalResumeRequested = true
        activeSessionIsPaused = false
        activeSessionPausedAt = nil
        return true
    }

    /// Write a complete optimistic session snapshot so widgets can switch to
    /// running immediately, while the app later starts the real FocusEngine.
    static func startWidgetSession(
        modeID: String,
        taskID: String? = nil,
        taskTitle: String? = nil,
        durationMinutes: Int? = nil,
        issuedAt: Date = Date.now
    ) {
        let duration: TimeInterval
        switch modeID {
        case "pomodoro":
            duration = durationMinutes.map { TimeInterval($0 * 60) } ?? pomodoroDuration
        case "timeBlock":
            duration = durationMinutes.map { TimeInterval($0 * 60) } ?? blockDuration
        default:
            duration = 0
        }

        if let durationMinutes, durationMinutes > 0 {
            externalStartDurationMinutes = durationMinutes
        }

        externalCommandID = UUID().uuidString
        externalCommandIssuedAt = issuedAt
        externalStopRequested = false
        externalPauseRequested = false
        externalResumeRequested = false
        requestedMode = modeID
        requestedTaskID = taskID

        isSessionActive = true
        activeSessionStartedFromWidget = true
        activeModeName = modeID
        widgetSelectedMode = modeID
        activeTaskID = taskID
        activeSessionTaskTitle = taskTitle
        activeSessionTimerStart = issuedAt
        activeSessionElapsed = 0
        activeSessionIsPaused = false
        activeSessionIsWaiting = false
        activeSessionPausedAt = nil

        if duration > 0 {
            activeSessionTimerEnd = issuedAt.addingTimeInterval(duration)
            activeSessionRemaining = duration
            activeSessionProgress = 0
        } else {
            activeSessionTimerEnd = nil
            activeSessionRemaining = nil
            activeSessionProgress = nil
        }

        activeSessionPhase = nil
        activeSessionPomodoroNumber = modeID == "pomodoro" ? 1 : nil
        activeSessionTotalPomodoros = nil
        externalStartRequested = true
    }

    /// Maximum age for an unprocessed external command before it is discarded (#221).
    static let externalCommandTTL: TimeInterval = 5 * 60

    /// True when a pending external command is older than `externalCommandTTL`.
    static var isExternalCommandStale: Bool {
        let hasCommand = externalStartRequested
            || externalStopRequested
            || externalPauseRequested
            || externalResumeRequested
        guard hasCommand else { return false }
        guard let issued = externalCommandIssuedAt else { return true }
        return Date.now.timeIntervalSince(issued) > externalCommandTTL
    }

    /// Drop expired Siri/widget/Focus Filter commands and any ghost session snapshot.
    static func discardStaleExternalCommandsIfNeeded() {
        guard isExternalCommandStale else { return }
        clearExternalCommands()
        clearActiveSession()
    }

    /// Queue an external start from Siri or Focus Filter.
    /// Premium modes for free users do not write optimistic `isSessionActive` (#220).
    /// - Returns: `true` when the start was queued; `false` when Pro is required.
    @discardableResult
    static func queueExternalStart(
        modeID: String,
        taskID: String? = nil,
        taskTitle: String? = nil,
        durationMinutes: Int? = nil
    ) -> Bool {
        let isProMode = modeID == "flowtime" || modeID == "timeBlock"
        if isProUser || !isProMode {
            startWidgetSession(
                modeID: modeID,
                taskID: taskID,
                taskTitle: taskTitle,
                durationMinutes: durationMinutes
            )
            return true
        }

        externalCommandID = UUID().uuidString
        externalCommandIssuedAt = .now
        externalStopRequested = false
        externalPauseRequested = false
        externalResumeRequested = false
        requestedMode = modeID
        requestedTaskID = taskID
        externalStartRequested = true
        return false
    }

    /// Mirror widget stop semantics for Siri (#222).
    static func queueExternalStop() {
        externalCommandID = UUID().uuidString
        externalCommandIssuedAt = .now
        externalPauseRequested = false
        externalResumeRequested = false
        externalStopRequested = true
        clearActiveSession()
    }

    /// Clear all external command flags after processing.
    static func clearExternalCommands() {
        defaults?.set(false, forKey: "externalStartRequested")
        defaults?.set(false, forKey: "externalStopRequested")
        defaults?.set(false, forKey: "externalPauseRequested")
        defaults?.set(false, forKey: "externalResumeRequested")
        defaults?.set(false, forKey: "controlCenterToggleRequested")
        defaults?.removeObject(forKey: "requestedMode")
        defaults?.removeObject(forKey: "requestedTaskID")
        defaults?.removeObject(forKey: "externalCommandID")
        defaults?.removeObject(forKey: "externalCommandIssuedAt")
        defaults?.removeObject(forKey: "externalStartDurationMinutes")
    }

    /// Cold-launch reconciliation for App Group session snapshots vs the in-process Focus engine.
    ///
    /// **Restore** — when `externalStartRequested` is true, a widget/Siri/Control Center
    /// action wrote an optimistic snapshot and `AppFeature.consumeExternalCommands` adopts it
    /// into `FocusEngine` via `startTapped(timerStart:timerEnd:)`. Do not clear in that case.
    ///
    /// **Clear** — when `isSessionActive` is true but the engine is not running and there is
    /// no pending external start, the previous process was killed mid-session. The App Group
    /// snapshot is a ghost: widgets, Control Center, and Live Activity must return to idle.
    /// Call this *before* `LiveActivityManager.reconcileOnLaunch()` on cold launch so orphan
    /// activities are dismissed rather than adopted.
    ///
    /// Manual QA (#173): start a Pomodoro from Focus, force-quit mid-session, relaunch — Focus
    /// tab is idle and home/lock widgets show idle (not a running timer).
    /// Point-in-time snapshot of a killed focus session (S5). Primitives only —
    /// this file compiles into extension targets, so it cannot reference app models.
    /// The app layer maps it to FocusSessionResult (see init(ghost:) in FocusModels).
    struct GhostSessionSnapshot: Sendable, Equatable {
        var modeName: String?
        /// True when the full session window was served (S6 backfill). Ghost
        /// abandonments (S5) always persist this as false.
        var wasCompleted: Bool = false
        var startedAt: Date
        var endedAt: Date
        var targetDuration: TimeInterval?
        var actualDuration: TimeInterval
        var pomodoroNumber: Int?
        var totalPomodoros: Int?
        var taskID: String?
    }

    enum SessionReconcilePolicy {
        /// Returns `true` when a ghost session was cleared.
        static func clearGhostSessionIfNeeded(engineIsRunning: Bool) -> Bool {
            guard isSessionActive,
                  !engineIsRunning,
                  !externalStartRequested else {
                return false
            }
            clearActiveSession()
            clearExternalCommands()
            return true
        }

        /// Minimum ghost focus time worth persisting (S5). Shorter ghosts are
        /// cleared silently: a seconds-long record would pollute stats and could
        /// grant a streak day via DailyStats.hadFocusSession.
        static let minimumGhostPersistSeconds: TimeInterval = 60

        /// Reads the App Group anchors and snapshots a ghost session WITHOUT
        /// clearing (S5). The caller clears via clearGhostSessionIfNeeded and
        /// persists the snapshot. Nil when there is no ghost.
        static func ghostSnapshotIfNeeded(engineIsRunning: Bool) -> GhostSessionSnapshot? {
            guard isSessionActive,
                  !engineIsRunning,
                  !externalStartRequested else {
                return nil
            }
            return validatedGhostSnapshot(
                isSessionActive: true,
                isWaiting: activeSessionIsWaiting,
                modeName: activeModeName,
                elapsed: activeSessionElapsed,
                timerStart: activeSessionTimerStart,
                timerEnd: activeSessionTimerEnd,
                pomodoroNumber: activeSessionPomodoroNumber,
                totalPomodoros: activeSessionTotalPomodoros,
                taskID: activeTaskID
            )
        }

        /// Pure ghost-snapshot validator (S5). Returns nil when nothing should
        /// persist: no ghost, a waiting hold (its phase already completed), or a
        /// trivial sub-minute ghost. Pass `now` explicitly in tests.
        static func validatedGhostSnapshot(
            isSessionActive: Bool,
            isWaiting: Bool,
            modeName: String?,
            elapsed: TimeInterval,
            timerStart: Date?,
            timerEnd: Date?,
            pomodoroNumber: Int?,
            totalPomodoros: Int?,
            taskID: String?,
            now: Date = Date.now
        ) -> GhostSessionSnapshot? {
            guard isSessionActive, !isWaiting else { return nil }
            let endedAt = now
            let startedAt = timerStart ?? endedAt.addingTimeInterval(-max(0, elapsed))
            let maxElapsed = max(0, endedAt.timeIntervalSince(startedAt))
            let actual = min(max(0, elapsed), maxElapsed)
            guard actual >= minimumGhostPersistSeconds else { return nil }
            let target: TimeInterval? = {
                guard let timerStart = timerStart, let timerEnd = timerEnd else { return nil }
                let duration = timerEnd.timeIntervalSince(timerStart)
                return duration > 0 ? duration : nil
            }()
            return GhostSessionSnapshot(
                modeName: modeName,
                startedAt: startedAt,
                endedAt: endedAt,
                targetDuration: target,
                actualDuration: actual,
                pomodoroNumber: pomodoroNumber,
                totalPomodoros: totalPomodoros,
                taskID: taskID
            )
        }

        /// Maximum backfill for open-ended (target-less) stale starts (S6).
        /// Without a target the served time is unbounded (e.g. days); the cap
        /// keeps a stale widget tap from corrupting stats. Count-up sessions
        /// adopted normally are unaffected — only phantom ones are capped.
        static let maximumOpenEndedBackfillSeconds: TimeInterval = 12 * 3600

        /// Atomically snapshots + clears a stale external start for backfill (S6).
        /// Only what discardStaleExternalCommandsIfNeeded would silently drop: a
        /// start command older than the TTL with timer anchors. Fresh snapshots
        /// (the normal adopt path) are never touched. Nil when there is nothing
        /// to backfill. The engine-running guard lives with the callers: a live
        /// session already covers this wall-clock time.
        static func takeStaleExternalStartBackfill(now: Date = Date.now) -> GhostSessionSnapshot? {
            guard externalStartRequested, isExternalCommandStale else { return nil }
            guard let snapshot = validatedStaleStartBackfill(
                modeName: activeModeName,
                timerStart: activeSessionTimerStart,
                timerEnd: activeSessionTimerEnd,
                pomodoroNumber: activeSessionPomodoroNumber,
                totalPomodoros: activeSessionTotalPomodoros,
                taskID: requestedTaskID ?? activeTaskID,
                now: now
            ) else { return nil }
            clearExternalCommands()
            clearActiveSession()
            return snapshot
        }

        /// Pure stale-start backfill validator (S6). Fully served windows become
        /// completed records; partially served windows become abandoned partials;
        /// target-less modes are capped. Pass `now` explicitly in tests.
        static func validatedStaleStartBackfill(
            modeName: String?,
            timerStart: Date?,
            timerEnd: Date?,
            pomodoroNumber: Int?,
            totalPomodoros: Int?,
            taskID: String?,
            now: Date = Date.now
        ) -> GhostSessionSnapshot? {
            guard let timerStart = timerStart else { return nil }
            let elapsed = max(0, now.timeIntervalSince(timerStart))
            if let timerEnd = timerEnd {
                let target = timerEnd.timeIntervalSince(timerStart)
                guard target > 0 else { return nil }
                if now >= timerEnd {
                    return GhostSessionSnapshot(
                        modeName: modeName,
                        startedAt: timerStart,
                        endedAt: timerEnd,
                        targetDuration: target,
                        actualDuration: target,
                        pomodoroNumber: pomodoroNumber,
                        totalPomodoros: totalPomodoros,
                        taskID: taskID,
                        wasCompleted: true
                    )
                }
                guard elapsed >= minimumGhostPersistSeconds else { return nil }
                return GhostSessionSnapshot(
                    modeName: modeName,
                    startedAt: timerStart,
                    endedAt: now,
                    targetDuration: target,
                    actualDuration: elapsed,
                    pomodoroNumber: pomodoroNumber,
                    totalPomodoros: totalPomodoros,
                    taskID: taskID,
                    wasCompleted: false
                )
            }
            let actual = min(elapsed, maximumOpenEndedBackfillSeconds)
            guard actual >= minimumGhostPersistSeconds else { return nil }
            return GhostSessionSnapshot(
                modeName: modeName,
                startedAt: timerStart,
                endedAt: timerStart.addingTimeInterval(actual),
                targetDuration: nil,
                actualDuration: actual,
                pomodoroNumber: pomodoroNumber,
                totalPomodoros: totalPomodoros,
                taskID: taskID,
                wasCompleted: false
            )
        }
    }

    /// Clear active session info when session ends.
    static func clearActiveSession() {
        defaults?.set(false, forKey: "isSessionActive")
        defaults?.removeObject(forKey: "activeModeName")
        defaults?.set(0, forKey: "activeSessionElapsed")
        defaults?.removeObject(forKey: "activeSessionRemaining")
        defaults?.removeObject(forKey: "activeSessionPhase")
        defaults?.removeObject(forKey: "activeSessionProgress")
        defaults?.removeObject(forKey: "activeSessionPomodoroNumber")
        defaults?.removeObject(forKey: "activeSessionTotalPomodoros")
        defaults?.removeObject(forKey: "activeSessionTaskTitle")
        defaults?.removeObject(forKey: "activeSessionTimerStart")
        defaults?.removeObject(forKey: "activeSessionTimerEnd")
        defaults?.set(false, forKey: "activeSessionIsPaused")
        defaults?.set(false, forKey: "activeSessionIsWaiting")
        defaults?.set(false, forKey: "activeSessionStartedFromWidget")
        defaults?.removeObject(forKey: "activeSessionPausedAt")
        defaults?.removeObject(forKey: "activeTaskID")
        defaults?.removeObject(forKey: "externalStartDurationMinutes")
    }
}

// MARK: - Widget Pro Gate

/// Returns the mode that should actually be started, applying Pro gating.
/// Free users who have a Pro mode selected (flowtime / timeBlock) fall back to pomodoro
/// so that CC/widget toggles always produce a sensible result instead of silently failing.
/// Pure function — no side effects, fully testable.
func widgetResolvedMode(requested: String, isPro: Bool) -> String {
    let isProMode = (requested == "flowtime" || requested == "timeBlock")
    return (isProMode && !isPro) ? "pomodoro" : requested
}

// MARK: - Shared Container Factory

/// Call this from every target that needs to read/write shared SwiftData.
/// Keep this container local-only for the 1.0 release. Devices that previously
/// opened `Pepinillo.sqlite` with CloudKit can hang while SwiftData validates or
/// migrates that store before the first SwiftUI frame, so the launch path uses a
/// fresh local store file and leaves the legacy file untouched for later recovery.
func makeSharedModelContainer() throws -> ModelContainer {
    try ensureDirectoryExists(for: AppGroup.storeURL)
    let walBytes = walFileSizeBytes(for: AppGroup.storeURL)
    if walBytes > 0 {
        persistenceLogger.info("Shared store WAL size before open: \(walBytes) bytes — checkpointing now")
        // Checkpoint before opening SwiftData so the migration plan evaluator sees
        // a near-empty WAL and does not need to replay potentially megabytes of frames.
        checkpointWAL(at: AppGroup.storeURL)
        let walBytesAfter = walFileSizeBytes(for: AppGroup.storeURL)
        persistenceLogger.info("Shared store WAL size after checkpoint: \(walBytesAfter) bytes")
    }
    persistenceLogger.info("Opening shared ModelContainer at: \(AppGroup.storeURL.path, privacy: .public)")
    do {
        return try makeModelContainer(at: AppGroup.storeURL)
    } catch {
        persistenceLogger.error("Failed to open shared ModelContainer: \(String(describing: error), privacy: .public)")

        if isDatabaseCorrupted(at: AppGroup.storeURL) {
            persistenceLogger.warning("Shared database is verified corrupted. Initiating quarantine...")
            try quarantineCorruptedStoreIfPresent()
            
            persistenceLogger.info("Retrying shared ModelContainer after quarantine...")
            do {
                return try makeModelContainer(at: AppGroup.storeURL)
            } catch {
                persistenceLogger.fault("Critical failure: Could not open shared ModelContainer even after quarantine. Error: \(String(describing: error), privacy: .public)")
                throw error
            }
        } else {
            persistenceLogger.warning("ModelContainer failed to open, but database is not verified corrupted (might be locked or permissions issue). Skipping quarantine.")
            throw error
        }
    }
}

/// Opens the CloudKit-backed store used for Pepinillo+ Apple sync.
/// Call this only after the first SwiftUI frame is visible.
func makeAppleCloudModelContainer() throws -> ModelContainer {
    try ensureDirectoryExists(for: AppGroup.appleCloudStoreURL)
    persistenceLogger.info("Opening Apple Cloud ModelContainer at: \(AppGroup.appleCloudStoreURL.path, privacy: .public)")
    return try makeModelContainer(
        at: AppGroup.appleCloudStoreURL,
        cloudKitDatabase: .private(AppGroup.cloudKitContainerIdentifier)
    )
}

// MARK: - Widget / Extension Container (non-CloudKit, non-MainActor)

/// Selects the SQLite store extensions should read based on the app's active sync mode.
/// Widgets and Siri run in separate processes and open the store without CloudKit sync,
/// but they must target the same on-disk file the main app is writing to.
func extensionModelStoreURL(for syncMode: AppGroupDefaults.SyncMode) -> URL {
    switch syncMode {
    case .appleCloud:
        return AppGroup.appleCloudStoreURL
    case .local, .backend:
        return AppGroup.storeURL
    }
}

private final class SharedModelContainerCache: @unchecked Sendable {
    static let shared = SharedModelContainerCache()
    private let lock = NSLock()
    private var container: ModelContainer?
    private var cachedSyncMode: AppGroupDefaults.SyncMode?

    func getOrCreateContainer() throws -> ModelContainer {
        lock.lock()
        defer { lock.unlock() }

        let activeMode = AppGroupDefaults.activeSyncMode
        if let container, let cachedSyncMode, cachedSyncMode == activeMode {
            return container
        }

        let storeURL = extensionModelStoreURL(for: activeMode)
        try ensureDirectoryExists(for: storeURL)
        persistenceLogger.info(
            "SharedModelContainerCache: Opening extension container for mode \(activeMode.rawValue, privacy: .public) at: \(storeURL.path, privacy: .public)"
        )
        let newContainer = try makeModelContainer(at: storeURL)
        container = newContainer
        cachedSyncMode = activeMode
        return newContainer
    }

    #if DEBUG
    /// Clears the in-process extension container cache so tests can observe mode switches.
    func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        container = nil
        cachedSyncMode = nil
    }
    #endif
}

#if DEBUG
/// Test hook for verifying extension store routing across sync-mode changes.
func resetExtensionModelContainerCacheForTesting() {
    SharedModelContainerCache.shared.resetForTesting()
}
#endif

/// Non-isolated version for WidgetKit extension process.
/// WidgetKit runs in a separate process — no @MainActor, no CloudKit sync.
/// Includes TaskItem + SubTask + FocusSessionRecord so Tasks and Dashboard widgets can read real data.
func makeWidgetModelContainer() throws -> ModelContainer {
    try SharedModelContainerCache.shared.getOrCreateContainer()
}

// MARK: - Intents Extension Container (includes TaskItem for Siri queries)

/// Non-isolated container for the Intents extension (Siri Shortcuts).
/// Includes TaskItem + SubTask so Siri can suggest real user tasks.
func makeIntentsModelContainer() throws -> ModelContainer {
    try SharedModelContainerCache.shared.getOrCreateContainer()
}

/// Refresh cached pomodoro/block durations from SwiftData before external starts (#224, #232).
func refreshDurationsFromSharedStore() throws {
    let container = try makeIntentsModelContainer()
    let context = ModelContext(container)
    let descriptor = FetchDescriptor<UserPreferences>()
    guard let preferences = try context.fetch(descriptor).first else { return }

    if preferences.pomodoroDuration > 0 {
        AppGroupDefaults.pomodoroDuration = preferences.pomodoroDuration
    }
    if preferences.defaultBlockDuration > 0 {
        AppGroupDefaults.blockDuration = preferences.defaultBlockDuration
    }
}

private func makeModelContainer(at url: URL) throws -> ModelContainer {
    try makeModelContainer(at: url, cloudKitDatabase: .none)
}

private func makeModelContainer(
    at url: URL,
    cloudKitDatabase: ModelConfiguration.CloudKitDatabase
) throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaV5.self)

    let config = ModelConfiguration(
        schema: schema,
        url: url,
        cloudKitDatabase: cloudKitDatabase
    )

    return try ModelContainer(
        for: schema,
        migrationPlan: PepinilloMigrationPlan.self,
        configurations: [config]
    )
}

func makeFallbackModelContainer() throws -> ModelContainer {
    try ensureDirectoryExists(for: AppGroup.fallbackStoreURL)
    persistenceLogger.warning("Opening stable fallback ModelContainer at: \(AppGroup.fallbackStoreURL.path, privacy: .public)")
    return try makeModelContainer(at: AppGroup.fallbackStoreURL)
}

func makeFreshFallbackModelContainer() throws -> ModelContainer {
    let fallbackURL = AppGroup.freshFallbackStoreURL()
    try ensureDirectoryExists(for: fallbackURL)

    persistenceLogger.info("Opening fresh fallback ModelContainer at: \(fallbackURL.path, privacy: .public)")
    return try makeModelContainer(at: fallbackURL)
}

func makeInMemoryModelContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaV5.self)
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )

    persistenceLogger.warning("Opening in-memory emergency ModelContainer")
    return try ModelContainer(
        for: schema,
        configurations: [config]
    )
}

private func isDatabaseCorrupted(at url: URL) -> Bool {
    let path = url.path
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: path) else {
        return false // File doesn't exist, nothing to be corrupted
    }

    var db: OpaquePointer?
    let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
    let rc = sqlite3_open_v2(path, &db, flags, nil)
    if rc != SQLITE_OK {
        if let db {
            sqlite3_close(db)
        }
        // SQLITE_CORRUPT or SQLITE_NOTADB indicates file format/integrity corruption.
        // Other codes (like SQLITE_BUSY or SQLITE_CANTOPEN) are typically transient locks or sandbox restrictions.
        return rc == SQLITE_CORRUPT || rc == SQLITE_NOTADB
    }
    defer { sqlite3_close(db) }

    var stmt: OpaquePointer?
    let query = "PRAGMA integrity_check;"
    if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            if let cString = sqlite3_column_text(stmt, 0) {
                let result = String(cString: cString)
                if result == "ok" {
                    return false
                } else {
                    persistenceLogger.error("isDatabaseCorrupted: integrity check failed with result '\(result, privacy: .public)'")
                    return true
                }
            }
        }
    } else {
        let errCode = sqlite3_errcode(db)
        if errCode == SQLITE_CORRUPT || errCode == SQLITE_NOTADB {
            return true
        }
    }

    return false
}

private func quarantineCorruptedStoreIfPresent() throws {
    let fileManager = FileManager.default
    let existingURLs = AppGroup.storeSupportURLs.filter { fileManager.fileExists(atPath: $0.path) }
    guard existingURLs.isEmpty == false else { return }

    let timestamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")

    for sourceURL in existingURLs {
        let recoveredURL = sourceURL.deletingLastPathComponent().appendingPathComponent(
            "\(sourceURL.lastPathComponent).recovered-\(timestamp)"
        )

        if fileManager.fileExists(atPath: recoveredURL.path) {
            try fileManager.removeItem(at: recoveredURL)
        }

        try fileManager.moveItem(at: sourceURL, to: recoveredURL)
    }
}

private func ensureDirectoryExists(for storeURL: URL) throws {
    let fileManager = FileManager.default
    let directory = storeURL.deletingLastPathComponent()
    if fileManager.fileExists(atPath: directory.path) == false {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

// MARK: - WAL Utilities

/// Returns the on-disk byte size of the SQLite WAL sidecar for `storeURL`,
/// or 0 if the WAL file is absent or unreadable.
func walFileSizeBytes(for storeURL: URL) -> Int {
    let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
    let size = (try? FileManager.default.attributesOfItem(atPath: walURL.path)[.size] as? Int) ?? 0
    return size
}

/// Issues a passive WAL checkpoint against the SQLite file at `storeURL`.
///
/// A passive checkpoint writes as many WAL frames as possible without waiting
/// for readers to vacate, then returns immediately. It is safe to call from any
/// thread and from any process that shares the WAL (the widget/intents extension),
/// because SQLite file-coordination serialises concurrent checkpoints.
///
/// Call this:
///  • After a successful ModelContainer open (so the next cold launch reads a
///    near-empty WAL instead of replaying megabytes).
///  • When the app enters background (via `scenePhase` change in AppBootstrap).
///
/// If the checkpoint fails (e.g. a reader has a long-lived transaction) it logs
/// the WAL page counts and returns without throwing; the WAL is still valid.
func checkpointWAL(at storeURL: URL) {
    let path = storeURL.path
    var db: OpaquePointer?
    // Open read-write (no CREATE) — WAL checkpoint requires write access to
    // copy frames from the WAL into the main database file.
    // NOMUTEX is safe here because this function is only called from one thread at a time.
    let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
    let openRc = sqlite3_open_v2(path, &db, flags, nil)
    if openRc != SQLITE_OK {
        persistenceLogger.warning("checkpointWAL: could not open '\(path, privacy: .public)' read-write — skipping checkpoint")
        if let db {
            sqlite3_close(db)
        }
        return
    }
    defer { sqlite3_close(db) }

    // Ensure the connection uses WAL mode. This is a no-op if WAL mode is
    // already active (the existing WAL file causes the connection to adopt it
    // automatically); it enables WAL if the file was created without it.
    sqlite3_exec(db, "PRAGMA journal_mode=WAL", nil, nil, nil)

    var logSize: Int32 = 0
    var framesCheckpointed: Int32 = 0
    // TRUNCATE: after checkpointing, reset the WAL file to zero length so the
    // next open does not need to replay any frames. Requires no active readers,
    // but is non-blocking — if a reader holds the WAL it returns SQLITE_BUSY and
    // we fall through gracefully.
    let rc = sqlite3_wal_checkpoint_v2(
        db,
        nil,                        // checkpoint all attached databases
        SQLITE_CHECKPOINT_TRUNCATE,  // compact WAL to zero after checkpointing
        &logSize,
        &framesCheckpointed
    )
    if rc == SQLITE_OK {
        persistenceLogger.info("WAL checkpoint (TRUNCATE) complete: \(framesCheckpointed)/\(logSize) frames flushed")
        let walBytesAfter = walFileSizeBytes(for: storeURL)
        persistenceLogger.info("WAL size after TRUNCATE checkpoint: \(walBytesAfter) bytes")
    } else if rc == SQLITE_BUSY {
        // A reader is holding the WAL — try PASSIVE (non-blocking, leaves WAL as-is)
        let rcPassive = sqlite3_wal_checkpoint_v2(
            db, nil, SQLITE_CHECKPOINT_PASSIVE, &logSize, &framesCheckpointed
        )
        if rcPassive == SQLITE_OK {
            persistenceLogger.info("WAL checkpoint (PASSIVE fallback): \(framesCheckpointed)/\(logSize) frames flushed")
        } else {
            let msg = String(cString: sqlite3_errmsg(db))
            persistenceLogger.warning("WAL checkpoint PASSIVE fallback returned \(rcPassive): \(msg, privacy: .public)")
        }
    } else {
        let msg = String(cString: sqlite3_errmsg(db))
        persistenceLogger.warning("WAL checkpoint returned \(rc): \(msg, privacy: .public) (log=\(logSize) frames=\(framesCheckpointed))")
    }
}
