// ConditionalAnimation.swift
// Pepinillo — Deep Work Companion for Apple

import SwiftUI

// MARK: - Conditional Animation Modifier

struct ConditionalAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Applies the given animation only when Reduce Motion is disabled.
    func conditionalAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ConditionalAnimationModifier(animation: animation, value: value))
    }
}

