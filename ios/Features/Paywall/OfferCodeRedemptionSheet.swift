// OfferCodeRedemptionSheet.swift
// Pepinillo — Deep Work Companion for Apple
//
// TCA dependency presenting Apple's system offer-code redemption sheet.
// StoreKit 2 has no SwiftUI environment action for redemption and the API
// differs per platform (UIWindowScene on iOS, NSViewController/NSWindow on
// macOS), so the presentation lives behind a dependency to keep
// PaywallFeature fully testable. After the sheet completes a code, the
// feature syncs RevenueCat via SubscriptionClient.syncPurchases (#957).

import ComposableArchitecture
import StoreKit

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Dependency

@DependencyClient
struct OfferCodeRedemptionSheet: Sendable {
    /// Presents the App Store offer-code redemption sheet. Throws when the
    /// user cancels (detect with `isOfferCodeCancellation`) or when no
    /// window/scene is available to present from.
    var present: @MainActor () async throws -> Void = {}
}

extension OfferCodeRedemptionSheet: DependencyKey {
    static let liveValue: Self = .live
}

extension DependencyValues {
    var offerCodeRedemptionSheet: OfferCodeRedemptionSheet {
        get { self[OfferCodeRedemptionSheet.self] }
        set { self[OfferCodeRedemptionSheet.self] = newValue }
    }
}

// MARK: - Live Implementation

extension OfferCodeRedemptionSheet {
    static let live: Self = Self(
        present: { @MainActor in
            #if os(macOS)
            if #available(macOS 27.0, *) {
                guard let window = NSApp.keyWindow else {
                    throw OfferCodeSheetError.noWindow
                }
                _ = try await AppStore.presentOfferCodeRedeemSheet(from: window, options: [])
            } else {
                guard let controller = NSApp.keyWindow?.contentViewController else {
                    throw OfferCodeSheetError.noWindow
                }
                try await AppStore.presentOfferCodeRedeemSheet(from: controller)
            }
            #elseif os(iOS) || os(visionOS)
            let scenes = UIApplication.shared.connectedScenes
            guard
                let scene = scenes.first(where: { ($0 as? UIWindowScene)?.activationState == .foregroundActive }) as? UIWindowScene
                    ?? scenes.first as? UIWindowScene
            else {
                throw OfferCodeSheetError.noWindow
            }
            // `in:` exists on every SDK (iOS 16+) and keeps CI green on runners
            // still resolving latest-stable to Xcode 26.3, where the 27-only
            // `from:options:` overload is a hard compile error — availability
            // guards cannot hide a missing overload from the compiler.
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            #else
            throw OfferCodeSheetError.unsupportedPlatform
            #endif
        }
    )
}

// MARK: - Errors

enum OfferCodeSheetError: LocalizedError {
    case noWindow
    case unsupportedPlatform

    var errorDescription: String? {
        switch self {
        case .noWindow:
            String(localized: "Could not open the code redemption screen. Please try again.")
        case .unsupportedPlatform:
            String(localized: "Offer code redemption is not available on this device.")
        }
    }
}

// MARK: - Cancellation Detection

extension Error {
    /// Whether this error represents the user dismissing the redemption sheet
    /// without redeeming. Apple throws `StoreKitError.cancelled` on modern
    /// platforms and the legacy `SKError.paymentCancelled` elsewhere; both
    /// must stay silent in the paywall (#957 S3).
    var isOfferCodeCancellation: Bool {
        if let storeKitError = self as? StoreKitError, case .userCancelled = storeKitError {
            return true
        }
        if let skError = self as? SKError {
            return skError.code == .paymentCancelled
        }
        return self is CancellationError
    }
}
