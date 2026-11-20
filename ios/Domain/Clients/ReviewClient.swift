// ReviewClient.swift
// Pepinillo — Deep Work Companion for Apple
//
// In-app rating seam (#979, parity with Android's #716). The system
// throttles requestReview (~3 prompts / 365 days); the app-level gate
// (3 completed sessions + once-per-device) lives in AppFeature so tests
// assert eligibility, not OS behavior.
//
// watchOS has no rating flow: the client is a no-op there (the gate lives
// in the iOS/macOS AppFeature, which the watch target does not compile).

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
    var requestReview: @Sendable () -> Void = {}
}

extension ReviewClient: DependencyKey {
    static let liveValue: ReviewClient = {
        #if os(macOS)
        return ReviewClient(
            requestReview: {
                guard let window = NSApp.keyWindow else { return }
                SKStoreReviewController.requestReview(in: window)
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
                SKStoreReviewController.requestReview(in: scene)
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
