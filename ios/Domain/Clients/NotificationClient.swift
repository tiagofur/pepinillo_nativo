// NotificationClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency wrapping UNUserNotificationCenter.
// Handles scheduling session-completion, break, and streak-reminder notifications.

import Foundation
import UserNotifications
import ComposableArchitecture

// MARK: - Notification Client

@DependencyClient
struct NotificationClient: Sendable {
    /// Request notification authorization (alert + sound + badge).
    var requestAuthorization: @Sendable () async -> Bool = { false }

    /// Check current authorization status (.authorized, .denied, .notDetermined, .provisional).
    var authorizationStatus: @Sendable () async -> UNAuthorizationStatus = { .notDetermined }

    /// Schedule a notification when a focus session completes.
    var scheduleSessionComplete: @Sendable (_ mode: String, _ taskTitle: String?) async -> Void = { _, _ in }

    /// Schedule a notification when a Pomodoro work phase ends (transition to break).
    var scheduleWorkPhaseEnd: @Sendable (_ pomodoroNumber: Int, _ isLongBreak: Bool, _ taskTitle: String?) async -> Void = { _, _, _ in }

    /// Schedule a break-end reminder after `minutes` minutes.
    var scheduleBreakEnd: @Sendable (_ minutes: Int) async -> Void = { _ in }

    /// Schedule a daily streak reminder at a given hour:minute (local time).
    var scheduleDailyReminder: @Sendable (_ hour: Int, _ minute: Int) async -> Void = { _, _ in }

    /// Update the active session notification with current timer display (fallback when Live Activity unavailable).
    var updateActiveSession: @Sendable (_ displayTime: String, _ mode: String, _ phase: String) async -> Void = { _, _, _ in }

    /// Clear the active session notification.
    var clearActiveSession: @Sendable () async -> Void = {}

    /// Observe notification action taps (START_BREAK, START_SESSION, etc.).
    var observeActions: @Sendable () -> AsyncStream<NotificationAction> = { .finished }

    /// Cancel all pending Pepinillo notifications.
    var cancelAll: @Sendable () async -> Void = {}

    /// Cancel only the daily streak reminder (#225).
    var cancelDailyReminder: @Sendable () async -> Void = {}

    /// After the user completes a focus session today, skip today's daily nag (#223).
    var rescheduleDailyReminderAfterFocus: @Sendable (_ hour: Int, _ minute: Int) async -> Void = { _, _ in }
}

// MARK: - Dependency Keys

extension NotificationClient: DependencyKey {
    static let liveValue = NotificationClient.live
    static let testValue = NotificationClient()
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

// MARK: - Live Implementation

extension NotificationClient {
    static let live: NotificationClient = {
        // Use a getter to avoid capturing a non-Sendable UNUserNotificationCenter in @Sendable closures
        @Sendable func center() -> UNUserNotificationCenter { UNUserNotificationCenter.current() }

        return NotificationClient(
            requestAuthorization: {
                do {
                    return try await center().requestAuthorization(options: [.alert, .sound, .badge])
                } catch {
                    return false
                }
            },

            authorizationStatus: {
                let settings = await center().notificationSettings()
                return settings.authorizationStatus
            },

            scheduleSessionComplete: { mode, taskTitle in
                let content = UNMutableNotificationContent()
                content.categoryIdentifier = "SESSION_COMPLETE"
                content.sound = .default

                let modeEmoji: String
                let modeName: String
                switch mode {
                case "pomodoro":  modeEmoji = "🍅"; modeName = "Pomodoro"
                case "flowtime":  modeEmoji = "🌊"; modeName = "Flowtime"
                case "timeBlock": modeEmoji = "📦"; modeName = "Time Block"
                case "stopwatch": modeEmoji = "⏱️"; modeName = "Stopwatch"
                default:           modeEmoji = "🧠"; modeName = "Focus"
                }

                if let task = taskTitle, !task.isEmpty {
                    content.title = "\(modeEmoji) \(String(localized: "Session complete!"))"
                    content.body = String(localized: "Great work on \(task). Take a well-deserved break.")
                } else {
                    content.title = "\(modeEmoji) \(String(localized: "\(modeName) complete!"))"
                    content.body = String(localized: "Nice work! Time to step away for a bit.")
                }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "session-complete-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                try? await center().add(request)
            },

            scheduleWorkPhaseEnd: { pomodoroNumber, isLongBreak, taskTitle in
                let content = UNMutableNotificationContent()
                content.sound = .default

                if isLongBreak {
                    content.title = "🍅 \(String(localized: "Great cycle! Time for a long break"))"
                    content.body = taskTitle.map { String(localized: "You completed \(pomodoroNumber) pomodoros on \($0).") }
                        ?? String(localized: "You completed \(pomodoroNumber) pomodoros. Take a longer break.")
                } else {
                    content.title = "🍅 \(String(localized: "Pomodoro \(pomodoroNumber) done!"))"
                    content.body = String(localized: "Take a short break, you've earned it.")
                }

                content.categoryIdentifier = "SESSION_COMPLETE"
                content.interruptionLevel = .timeSensitive

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "phase-end-\(UUID().uuidString)",
                    content: content,
                    trigger: trigger
                )
                try? await center().add(request)
            },

            scheduleBreakEnd: { minutes in
                let content = UNMutableNotificationContent()
                content.title = "⏰ \(String(localized: "Break time's up!"))"
                content.body = String(localized: "Ready to dive back in? Your next session is waiting.")
                content.sound = .default
                content.categoryIdentifier = "BREAK_END"

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: TimeInterval(minutes * 60),
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: "break-end",
                    content: content,
                    trigger: trigger
                )
                // Remove any existing break-end notification first
                center().removePendingNotificationRequests(withIdentifiers: ["break-end"])
                try? await center().add(request)
            },

            scheduleDailyReminder: { hour, minute in
                let content = UNMutableNotificationContent()
                content.title = "🔥 \(String(localized: "Keep your streak alive!"))"
                content.body = String(localized: "Haven't focused today yet. Open Pepinillo and get a session in.")
                content.sound = .default
                content.categoryIdentifier = "DAILY_REMINDER"

                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )
                let request = UNNotificationRequest(
                    identifier: "daily-reminder",
                    content: content,
                    trigger: trigger
                )
                center().removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
                try? await center().add(request)
            },

            updateActiveSession: { displayTime, mode, phase in
                let content = UNMutableNotificationContent()

                let modeEmoji: String
                switch mode {
                case "pomodoro":  modeEmoji = "🍅"
                case "flowtime":  modeEmoji = "🌊"
                case "timeBlock": modeEmoji = "📦"
                case "stopwatch": modeEmoji = "⏱️"
                default:          modeEmoji = "🧠"
                }

                content.title = "\(modeEmoji) \(displayTime)"
                content.body = phase
                content.sound = nil
                content.interruptionLevel = .passive
                content.categoryIdentifier = "ACTIVE_SESSION"

                let request = UNNotificationRequest(
                    identifier: "active-session",
                    content: content,
                    trigger: nil
                )

                center().removeDeliveredNotifications(withIdentifiers: ["active-session"])
                try? await center().add(request)
            },

            clearActiveSession: {
                center().removeDeliveredNotifications(withIdentifiers: ["active-session"])
                center().removePendingNotificationRequests(withIdentifiers: ["active-session"])
            },

            observeActions: {
                NotificationDelegate.shared.actions
            },

            cancelAll: {
                center().removeAllPendingNotificationRequests()
                center().removeAllDeliveredNotifications()
            },

            cancelDailyReminder: {
                let notificationCenter = center()
                notificationCenter.removeDeliveredNotifications(withIdentifiers: ["daily-reminder"])
                notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])
            },

            rescheduleDailyReminderAfterFocus: { hour, minute in
                let notificationCenter = center()
                notificationCenter.removeDeliveredNotifications(withIdentifiers: ["daily-reminder"])
                notificationCenter.removePendingNotificationRequests(withIdentifiers: ["daily-reminder"])

                let calendar = Calendar.current
                let now = Date.now
                var nextComponents = DateComponents(hour: hour, minute: minute)
                guard var nextDate = calendar.nextDate(
                    after: now,
                    matching: nextComponents,
                    matchingPolicy: .nextTime
                ) else { return }

                if calendar.isDateInToday(nextDate) {
                    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: nextDate) else { return }
                    nextDate = tomorrow
                }

                let fireComponents = calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: nextDate
                )
                let content = UNMutableNotificationContent()
                content.title = "🔥 \(String(localized: "Keep your streak alive!"))"
                content.body = String(localized: "Haven't focused today yet. Open Pepinillo and get a session in.")
                content.sound = .default
                content.categoryIdentifier = "DAILY_REMINDER"

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: fireComponents,
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: "daily-reminder",
                    content: content,
                    trigger: trigger
                )
                try? await notificationCenter.add(request)
            }
        )
    }()
}

// MARK: - Notification Categories (call once at app launch)

extension NotificationClient {
    static func registerCategories() {
        let completeAction = UNNotificationAction(
            identifier: "START_BREAK",
            title: "Start Break Timer",
            options: []
        )
        let startSessionAction = UNNotificationAction(
            identifier: "START_SESSION",
            title: "Start Session",
            options: [.foreground]
        )
        let breakEndCategory = UNNotificationCategory(
            identifier: "BREAK_END",
            actions: [startSessionAction],
            intentIdentifiers: [],
            options: []
        )

        let stopAction = UNNotificationAction(
            identifier: "STOP_SESSION",
            title: "End Session",
            options: [.destructive]
        )
        let extendAction = UNNotificationAction(
            identifier: "EXTEND_SESSION",
            title: String(localized: "+5 min"),
            options: []
        )
        let sessionCompleteWithStopCategory = UNNotificationCategory(
            identifier: "SESSION_COMPLETE",
            actions: [completeAction, extendAction, stopAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let pauseAction = UNNotificationAction(
            identifier: "PAUSE_SESSION",
            title: "Pause",
            options: []
        )
        let activeSessionCategory = UNNotificationCategory(
            identifier: "ACTIVE_SESSION",
            actions: [pauseAction, stopAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            sessionCompleteWithStopCategory,
            breakEndCategory,
            activeSessionCategory
        ])
    }
}

