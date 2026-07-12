// UserPreferences.swift
// Pepinillo — Deep Work Companion for Apple
//
// User preferences stored in SwiftData, synced via CloudKit.
// Includes focus config, theme, notification settings, and subscription state.

import Foundation
import SwiftData

@Model
public final class UserPreferences {
    public var id: UUID

    // Focus Configuration (serialized)
    public var pomodoroDuration: TimeInterval
    public var shortBreakDuration: TimeInterval
    public var longBreakDuration: TimeInterval
    public var pomodorosPerCycle: Int
    public var autoStartBreaks: Bool
    public var autoStartWork: Bool
    public var defaultBlockDuration: TimeInterval
    public var blockMidpointCheckIn: Bool
    public var flowtimeMinSessionMinutes: Int
    public var flowtimeShowBreakSuggestion: Bool

    // General
    public var soundEnabled: Bool
    public var hapticEnabled: Bool
    public var keepScreenOn: Bool

    // Default focus mode
    public var defaultMode: String  // FocusMode.rawValue

    // Theme
    public var themeName: String    // "default", "forest", "ocean", "sunset", "liquidGlass"
    public var followSystemAppearance: Bool
    public var appearanceMode: String  // "system", "light", "dark"

    // Notifications
    public var dailyReminderEnabled: Bool
    public var dailyReminderHour: Int       // 0-23
    public var dailyReminderMinute: Int     // 0-59

    // Onboarding
    public var hasCompletedOnboarding: Bool

    // Streak
    public var currentStreakDays: Int
    public var longestStreakDays: Int
    public var lastFocusDate: Date?

    // Sessions
    public var showJournalAfterSession: Bool = true

    // Apple Health
    public var healthLoggingEnabled: Bool

    // Subscription (local cache — source of truth is StoreKit)
    public var isProUser: Bool
    public var subscriptionExpiresAt: Date?

    // ADHD-Friendly Mode (C7)
    public var adhdFriendlyEnabled: Bool = false

    // Calendar Integration (C3)
    public var calendarIntegrationEnabled: Bool = false

    // Sign In with Apple (synced via CloudKit)
    public var appleUserID: String? = nil
    public var displayName: String? = nil
    public var userEmail: String? = nil
    /// Apple authorization code for backend-side token revocation on account
    /// deletion (#196). Not synced via CloudKit (device-local only).
    public var appleAuthorizationCode: String? = nil

    public init() {
        self.id = UUID()
        // Focus defaults
        self.pomodoroDuration = 25 * 60
        self.shortBreakDuration = 5 * 60
        self.longBreakDuration = 15 * 60
        self.pomodorosPerCycle = 4
        self.autoStartBreaks = true
        self.autoStartWork = false
        self.defaultBlockDuration = 60 * 60
        self.blockMidpointCheckIn = false
        self.flowtimeMinSessionMinutes = 5
        self.flowtimeShowBreakSuggestion = true
        // General
        self.soundEnabled = true
        self.hapticEnabled = true
        self.keepScreenOn = false
        // Defaults
        self.defaultMode = FocusMode.pomodoro.rawValue
        self.themeName = "default"
        self.followSystemAppearance = true
        self.appearanceMode = "system"
        // Notifications
        self.dailyReminderEnabled = false
        self.dailyReminderHour = 9
        self.dailyReminderMinute = 0
        // Onboarding
        self.hasCompletedOnboarding = false
        // Streak
        self.currentStreakDays = 0
        self.longestStreakDays = 0
        // Apple Health
        self.healthLoggingEnabled = false
        // Subscription
        self.isProUser = false
    }

    /// Convert stored preferences to a FocusConfig value type.
    public var focusConfig: FocusConfig {
        FocusConfig(
            pomodoroDuration: pomodoroDuration,
            shortBreakDuration: shortBreakDuration,
            longBreakDuration: longBreakDuration,
            pomodorosPerCycle: pomodorosPerCycle,
            autoStartBreaks: autoStartBreaks,
            autoStartWork: autoStartWork,
            defaultBlockDuration: defaultBlockDuration,
            blockMidpointCheckIn: blockMidpointCheckIn,
            flowtimeMinSessionMinutes: flowtimeMinSessionMinutes,
            flowtimeShowBreakSuggestion: flowtimeShowBreakSuggestion,
            soundEnabled: soundEnabled,
            hapticEnabled: hapticEnabled,
            keepScreenOn: keepScreenOn
        )
    }
}
