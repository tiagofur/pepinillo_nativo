// PaywallCommercialClaims.swift
// Pepinillo — Deep Work Companion for Apple

import Foundation

struct PaywallCommercialClaim: Identifiable, Sendable {
    enum ID: String, Sendable {
        case appleCloudSync
        case onDeviceAI
        case fullLocalApp
        case exportAccess
        case pepinilloCloudSync
        case accountRecovery
        case pepinilloPlusIncluded
    }

    let id: ID
    let icon: String
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
}

/// The production value copy rendered by the iOS paywall.
///
/// Future capabilities must not enter this source of truth until their
/// production client path and release operations are verified.
enum PaywallCommercialClaims {
    static let headerBody: LocalizedStringResource = "Pepinillo+ unlocks local premium features and private iCloud sync. Everywhere/AI+ includes those benefits plus Pepinillo account sync and recovery."
    static let pepinilloPlusSummary: LocalizedStringResource = "Best for focus on iPhone and iPad, with Apple Watch and private iCloud sync."
    static let everywhereSummary: LocalizedStringResource = "Best if you want Pepinillo account sync and recovery on iPhone and iPad."

    static let pepinilloPlus: [PaywallCommercialClaim] = [
        .init(id: .appleCloudSync, icon: "icloud.fill", title: "iCloud sync", subtitle: "Tasks, sessions, settings, and analytics sync between iPhone and iPad."),
        .init(id: .onDeviceAI, icon: "sparkles", title: "On-device AI", subtitle: "Apple Intelligence when available, with private local reports and a built-in fallback."),
        .init(id: .fullLocalApp, icon: "checklist", title: "Full local app", subtitle: "Unlimited tasks, subtasks, recurrence, themes, widgets, Watch."),
        .init(id: .exportAccess, icon: "square.and.arrow.up", title: "Export access", subtitle: "Keep your focus history portable with data exports."),
    ]

    static let everywhere: [PaywallCommercialClaim] = [
        .init(id: .pepinilloCloudSync, icon: "server.rack", title: "Pepinillo cloud sync", subtitle: "Sync tasks, focus sessions, and settings through your Pepinillo account."),
        .init(id: .accountRecovery, icon: "person.crop.circle.badge.checkmark", title: "Account recovery", subtitle: "Recover synced data after signing in again."),
        .init(id: .pepinilloPlusIncluded, icon: "plus.circle.fill", title: "Everything in Pepinillo+", subtitle: "Local premium features remain included."),
    ]

    static let lifetimeProductSummary: LocalizedStringResource = "One purchase for full local features, on-device AI, export, Apple Watch, widgets, and iCloud sync."
    static let everywhereProductSummary: LocalizedStringResource = "Everything in Pepinillo+ plus Pepinillo account sync and recovery."
    static let everywhereAnnualProductSummary: LocalizedStringResource = "Everything in Pepinillo+ plus Pepinillo account sync and recovery. Best value."
    static let lifetimeCompliance: LocalizedStringResource = "Not a subscription. iPhone and iPad sync uses your iCloud account."
    static let everywhereCompliance: LocalizedStringResource = "Auto-renewing subscription. A Pepinillo account is required for cloud sync."

    /// English source keys for deterministic commercial-claim regression tests.
    static var productionPaywallSourceCopy: [String] {
        [
            headerBody,
            pepinilloPlusSummary,
            everywhereSummary,
            lifetimeProductSummary,
            everywhereProductSummary,
            everywhereAnnualProductSummary,
            lifetimeCompliance,
            everywhereCompliance,
        ].map(\.key) + (pepinilloPlus + everywhere).flatMap {
            [$0.title.key, $0.subtitle.key]
        }
    }
}
