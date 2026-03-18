// HandoffActivity.swift
// Pepinillo — Deep Work Companion for Apple
//
// NSUserActivity type constants and helpers for Handoff continuity.
// Allows users to seamlessly continue focus sessions across iPhone, iPad, and Mac.

import Foundation

enum HandoffActivity {
    /// Activity type for an active focus session.
    static let focusSession = "com.pepinillo.app.focusSession"

    /// Activity type for viewing analytics.
    static let viewAnalytics = "com.pepinillo.app.viewAnalytics"

    /// Activity type for viewing/editing a task.
    static let viewTask = "com.pepinillo.app.viewTask"

    // MARK: - UserInfo Keys

    enum Key {
        static let modeID = "modeID"
        static let taskID = "taskID"
        static let taskTitle = "taskTitle"
        static let isRunning = "isRunning"
    }

    // MARK: - Factory

    /// Create an NSUserActivity for the current focus state.
    static func makeFocusActivity(
        modeID: String,
        isRunning: Bool,
        taskID: UUID? = nil,
        taskTitle: String? = nil
    ) -> NSUserActivity {
        let activity = NSUserActivity(activityType: focusSession)
        activity.title = isRunning ? "Focus Session — \(modeID)" : "Ready to Focus"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.needsSave = true

        var info: [String: Any] = [
            Key.modeID: modeID,
            Key.isRunning: isRunning,
        ]
        if let taskID { info[Key.taskID] = taskID.uuidString }
        if let taskTitle { info[Key.taskTitle] = taskTitle }
        activity.userInfo = info

        return activity
    }

    /// Create an NSUserActivity for viewing analytics.
    static func makeAnalyticsActivity() -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewAnalytics)
        activity.title = "View Focus Analytics"
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        return activity
    }
}
