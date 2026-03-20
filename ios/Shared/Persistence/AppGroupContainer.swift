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
//   3. CloudKit container ID: "iCloud.com.pepinillo.app"
//
// The main app MUST use this factory instead of constructing its own ModelContainer,
// otherwise the widget reads from a different SQLite file.

import Foundation
import SwiftData

// MARK: - App Group Constants

enum AppGroup {
    static let id = "group.com.pepinillo.app"
    static let storeFileName = "Pepinillo.sqlite"

    /// Shared container URL (App Group directory).
    static var containerURL: URL {
        guard let url = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: id
        ) else {
            // Fallback to documents directory when App Group not configured (Simulator / CI)
            return FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)
                .first!
        }
        return url
    }

    /// Full URL to the shared SQLite store.
    static var storeURL: URL {
        containerURL.appendingPathComponent(storeFileName)
    }
}

// MARK: - App Group UserDefaults (cross-process communication)

enum AppGroupDefaults {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.id) }

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

    /// Active session mode name (written by main app on start, read by Shortcuts).
    static var activeModeName: String? {
        get { defaults?.string(forKey: "activeModeName") }
        set { defaults?.set(newValue, forKey: "activeModeName") }
    }

    /// Active session elapsed seconds (written periodically by main app, read by Shortcuts).
    static var activeSessionElapsed: Int {
        get { defaults?.integer(forKey: "activeSessionElapsed") ?? 0 }
        set { defaults?.set(newValue, forKey: "activeSessionElapsed") }
    }

    /// Active session remaining seconds (for countdown modes, written by main app, read by widgets).
    static var activeSessionRemaining: Int? {
        get {
            let val = defaults?.object(forKey: "activeSessionRemaining")
            return val as? Int
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

    /// Clear all external command flags after processing.
    static func clearExternalCommands() {
        defaults?.set(false, forKey: "externalStartRequested")
        defaults?.set(false, forKey: "externalStopRequested")
        defaults?.set(false, forKey: "externalPauseRequested")
        defaults?.set(false, forKey: "externalResumeRequested")
        defaults?.set(false, forKey: "controlCenterToggleRequested")
        defaults?.removeObject(forKey: "requestedMode")
        defaults?.removeObject(forKey: "requestedTaskID")
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
        defaults?.removeObject(forKey: "activeTaskID")
    }
}

// MARK: - Shared Container Factory

/// Call this from every target that needs to read/write shared SwiftData.
/// The CloudKit sync is only activated when running in the main app process
/// (widgets receive `.none` to avoid double-sync writes).
@MainActor
func makeSharedModelContainer(enableCloudKit: Bool = true) throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaV1.self)

    let config = ModelConfiguration(
        schema: schema,
        url: AppGroup.storeURL,
        cloudKitDatabase: enableCloudKit ? .automatic : .none
    )

    return try ModelContainer(
        for: schema,
        migrationPlan: PepinilloMigrationPlan.self,
        configurations: [config]
    )
}

// MARK: - Widget / Extension Container (non-CloudKit, non-MainActor)

/// Non-isolated version for WidgetKit extension process.
/// WidgetKit runs in a separate process — no @MainActor, no CloudKit sync.
/// Includes TaskItem + SubTask + FocusSessionRecord so Tasks and Dashboard widgets can read real data.
func makeWidgetModelContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaV1.self)

    let config = ModelConfiguration(
        schema: schema,
        url: AppGroup.storeURL,
        cloudKitDatabase: .none
    )

    return try ModelContainer(
        for: schema,
        migrationPlan: PepinilloMigrationPlan.self,
        configurations: [config]
    )
}

// MARK: - Intents Extension Container (includes TaskItem for Siri queries)

/// Non-isolated container for the Intents extension (Siri Shortcuts).
/// Includes TaskItem + SubTask so Siri can suggest real user tasks.
func makeIntentsModelContainer() throws -> ModelContainer {
    let schema = Schema(versionedSchema: SchemaV1.self)

    let config = ModelConfiguration(
        schema: schema,
        url: AppGroup.storeURL,
        cloudKitDatabase: .none
    )

    return try ModelContainer(
        for: schema,
        migrationPlan: PepinilloMigrationPlan.self,
        configurations: [config]
    )
}
