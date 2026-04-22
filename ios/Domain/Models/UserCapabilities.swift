// UserCapabilities.swift
// Pepinillo — Deep Work Companion for Apple
//
// Capability-based entitlement model replacing the legacy isProUser boolean.
// Each capability maps to a specific feature set, enabling granular gating
// between Pepinillo+ (one-time) and Everywhere/AI+ (subscription).

import Foundation

// MARK: - User Capabilities

struct UserCapabilities: Equatable, Sendable, Codable {
    // MARK: Pepinillo+ (one-time purchase)
    /// Flowtime, Time Block, unlimited tasks, subtasks, recurrence,
    /// premium themes, premium soundscapes, all widgets, watchOS companion.
    var localPremium: Bool

    /// iCloud / CloudKit sync between Apple devices.
    var appleCloudSync: Bool

    /// Apple Intelligence / Foundation Models — on-device AI, no API cost.
    var localAI: Bool

    /// CSV / PDF data export.
    var exportAccess: Bool

    // MARK: Everywhere/AI+ (subscription)
    /// Go backend sync — cross-platform (iOS + Android + Web).
    var backendSync: Bool

    /// Cloud AI credits per billing cycle (Gemini/OpenAI APIs).
    /// 0 = no cloud AI access. Everywhere tier gets 100/month.
    var aiCreditsMonthly: Int

    /// Account-based entitlement portability across stores.
    var crossDeviceRestore: Bool

    // MARK: Computed

    /// True if user has ANY paid tier (for legacy isPro backward compat).
    var hasAnyPremium: Bool {
        localPremium || backendSync
    }

    /// True if user has the Everywhere tier specifically.
    var isEverywhere: Bool {
        backendSync
    }

    /// True if user has at least Pepinillo+ (or higher).
    var hasPepinilloPlus: Bool {
        localPremium
    }

    /// Backward-compat alias for hasPepinilloPlus.
    var hasAppleUnlock: Bool { hasPepinilloPlus }

    /// Remaining AI credits for current billing cycle.
    var hasCloudAI: Bool {
        aiCreditsMonthly > 0
    }

    // MARK: Static Presets

    /// Free tier — no paid capabilities.
    static let free = UserCapabilities(
        localPremium: false,
        appleCloudSync: false,
        localAI: false,
        exportAccess: false,
        backendSync: false,
        aiCreditsMonthly: 0,
        crossDeviceRestore: false
    )

    /// Pepinillo+ — one-time purchase. Full local features + iCloud sync.
    static let pepinilloPlus = UserCapabilities(
        localPremium: true,
        appleCloudSync: true,
        localAI: true,
        exportAccess: true,
        backendSync: false,
        aiCreditsMonthly: 0,
        crossDeviceRestore: false
    )

    /// Everywhere+ — subscription. Everything in Pepinillo+ + backend + cloud AI.
    static let everywherePlus = UserCapabilities(
        localPremium: true,
        appleCloudSync: true,
        localAI: true,
        exportAccess: true,
        backendSync: true,
        aiCreditsMonthly: 100,
        crossDeviceRestore: true
    )
}

// MARK: - Feature Gating Helpers

extension UserCapabilities {
    /// Whether the user can use a specific premium focus mode (Flowtime, TimeBlock).
    var canUsePremiumModes: Bool { localPremium }

    /// Whether the user can create unlimited tasks.
    var canCreateUnlimitedTasks: Bool { localPremium }

    /// Whether the user can use subtasks and recurring tasks.
    var canUseAdvancedTasks: Bool { localPremium }

    /// Whether the user can access advanced analytics (30d, 1yr, weekly/monthly reviews).
    var canUseAdvancedAnalytics: Bool { localPremium }

    /// Whether the user can use premium themes (Forest, Ocean, Sunset).
    var canUsePremiumThemes: Bool { localPremium }

    /// Whether the user can access reviews (weekly + monthly).
    var canUseReviews: Bool { localPremium }

    /// Whether the user can generate AI reports (local on-device).
    var canUseLocalAI: Bool { localAI }

    /// Whether the user can consume cloud AI credits.
    var canUseCloudAI: Bool { aiCreditsMonthly > 0 }

    /// Whether the user can sync via the Go backend.
    var canUseBackendSync: Bool { backendSync }

    /// Whether the user can export data (CSV/PDF).
    var canExportData: Bool { exportAccess }

    /// Whether the user can use all watchOS companion features.
    var canUseFullWatchCompanion: Bool { localPremium }

    /// Whether the user can use premium soundscapes.
    var canUsePremiumSoundscapes: Bool { localPremium }

    /// Whether the user can use health integration (Apple Health).
    var canUseHealthIntegration: Bool { localPremium }

    /// Whether the user can use calendar integration.
    var canUseCalendarIntegration: Bool { localPremium }
}

// MARK: - Tier Display Name

extension UserCapabilities {
    /// Human-readable tier name for UI display.
    var tierDisplayName: String {
        if isEverywhere {
            return String(localized: "Everywhere/AI+")
        } else if hasAppleUnlock {
            return String(localized: "Pepinillo+")
        } else {
            return String(localized: "Free")
        }
    }

    /// Short tier identifier for analytics / debugging.
    var tierIdentifier: String {
        if isEverywhere { return "everywhere_plus" }
        if hasPepinilloPlus { return "pepinillo_plus" }
        return "free"
    }
}
