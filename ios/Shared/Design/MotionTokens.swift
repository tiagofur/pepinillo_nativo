// MotionTokens.swift
// Pepinillo — Deep Work Companion for Apple
//
// Canonical spring/animation presets. Use these instead of inline spring literals
// so the whole app moves with one consistent feel. Three levels:
//
//   • snappy  — quick, responsive UI state changes (tab switch, button tap feedback)
//   • bouncy  — celebratory / playful transitions (selection, onboarding page flip)
//   • smooth  — large layout transitions, content entering the screen
//
// Usage:
//   .animation(MotionTokens.snappy, value: someState)
//   withAnimation(MotionTokens.bouncy) { ... }

import SwiftUI

enum MotionTokens {
    // MARK: - Presets

    /// Fast, tight spring for interactive UI state changes (tab switches, button states, pickers).
    static let snappy: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    /// Springy, playful animation for selections and onboarding moments.
    static let bouncy: Animation = .spring(response: 0.3, dampingFraction: 0.7)

    /// Smooth easing for larger layout transitions and content reveals.
    static let smooth: Animation = .smooth(duration: 0.32)

    // MARK: - Celebratory (staggered entrance used in CelebrationView / Onboarding)

    /// Slow, weighty spring for hero entrance animations.
    static let heroEntrance: Animation = .spring(response: 0.8, dampingFraction: 0.7)

    /// Standard press-scale feedback for interactive elements.
    static let pressScale: Animation = .spring(response: 0.35, dampingFraction: 0.7)
}
