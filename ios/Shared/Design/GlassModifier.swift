// GlassModifier.swift
// Pepinillo — Deep Work Companion for Apple
//
// Centralised Liquid Glass ViewModifier for iOS 26+.
// Falls back to ultraThinMaterial on earlier OS versions.
// One modifier → one place to update when Apple changes the API.

import SwiftUI

struct PepinilloGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            #if os(watchOS)
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            #else
            content
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
            #endif
        } else if #available(iOS 26, macOS 26, watchOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    func pepinilloGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(PepinilloGlassModifier(cornerRadius: cornerRadius))
    }
}
