// ReviewClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// In-app rating seam (#979, parity with Android's #716). The system
// throttles requestReview (~3 prompts / 365 days); the app-level gate
// (3 completed sessions + once-per-device) lives in AppFeature so tests
// assert eligibility, not OS behavior.
//
// The seam is @MainActor async: SKStoreReviewController/AppStore touch
// UIKit/AppKit UI state, and callers (TCA .run effects) are nonisolated.
// StoreKit 2's AppStore.requestReview takes an NSViewController on macOS
// (SK1's NSWindow overload does not exist on macOS — verified against the
// SDK) and a UIWindowScene on iOS. watchOS has no rating flow: no-op.

import ComposableArchitecture
import Foundation
import StoreKit

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Milestone at which the first review prompt fires.
enum ReviewPrompt {
    /// Parity with Android: 3 completed focus sessions.
    static let completedSessionsThreshold = 3
}

struct ReviewClient: Sendable {
    var requestReview: @MainActor @Sendable () async -> Void = {}
}

extension ReviewClient: DependencyKey {
    static let liveValue: ReviewClient = {
        #if os(macOS)
        return ReviewClient(
            requestReview: {
                guard let window = NSApp.keyWindow,
                      let controller = window.contentViewController else { return }
                AppStore.requestReview(in: controller)
            }
        )
        #elseif os(iOS) || os(visionOS)
        return ReviewClient(
            requestReview: {
                let scenes = UIApplication.shared.connectedScenes
                guard
                    let scene = scenes.first(where: { ($0 as? UIWindowScene)?.activationState == .foregroundActive }) as? UIWindowScene
                        ?? scenes.first as? UIWindowScene
                else { return }
                AppStore.requestReview(in: scene)
            }
        )
        #else
        // watchOS: no review flow.
        return ReviewClient()
        #endif
    }()

    static let testValue = ReviewClient()
}

extension DependencyValues {
    var reviewClient: ReviewClient {
        get { self[ReviewClient.self] }
        set { self[ReviewClient.self] = newValue }
    }
}
