// NotificationDelegate.swift
// Pepinillo — Deep Work Companion for Apple
//
// UNUserNotificationCenter delegate that bridges notification action taps
// into an AsyncStream consumable by TCA effects.

import Foundation
import UserNotifications

// MARK: - Notification Action

enum NotificationAction: Sendable, Equatable {
    case startBreak
    case startSession
    case pauseSession
    case stopSession
    case extendSession
    case dismissed
}

// MARK: - Notification Delegate

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationDelegate()

    /// Category of the opt-in weekly recap (#735) — tapping it should land on
    /// the Dashboard (never the Weekly Review behind the paywall).
    static let weeklyRecapCategoryID = "WEEKLY_RECAP"

    /// Posted when the user taps the weekly recap notification itself.
    static let openDashboardFromRecap = Notification.Name("pepinillo.recap.openDashboard")

    private let (stream, continuation) = AsyncStream<NotificationAction>.makeStream()

    /// AsyncStream of notification actions for TCA to observe.
    var actions: AsyncStream<NotificationAction> { stream }

    private override init() {
        super.init()
    }

    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when the user taps a notification action button.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        switch response.actionIdentifier {
        case "START_BREAK":
            continuation.yield(.startBreak)
        case "START_SESSION":
            continuation.yield(.startSession)
        case "PAUSE_SESSION":
            continuation.yield(.pauseSession)
        case "STOP_SESSION":
            continuation.yield(.stopSession)
        case "EXTEND_SESSION":
            continuation.yield(.extendSession)
        case UNNotificationDismissActionIdentifier:
            continuation.yield(.dismissed)
        default:
            // A plain tap on the weekly recap lands on the Dashboard (#735);
            // plain taps on other notifications keep system behavior.
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
               response.notification.request.content.categoryIdentifier == Self.weeklyRecapCategoryID {
                NotificationCenter.default.post(name: Self.openDashboardFromRecap, object: nil)
            }
        }
    }

    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
