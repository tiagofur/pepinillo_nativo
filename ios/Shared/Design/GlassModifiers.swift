// GlassModifiers.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared Glass modifiers for App and Widgets.
//
// Availability note (Issue #33):
// GlassEffectContainer, .glassEffect(), and .glassEffectID() are defined in the
// SwiftUI SDK shipped with Xcode 16.2+ (forward-declared for the iOS 26 runtime).
// The compiler resolves these symbols at build time against the SDK headers, so
// no compile-time stubs are required.  The #available(iOS 26.0, *) guards at each
// call site are the correct and sufficient mechanism to gate runtime use of these
// APIs to devices running iOS 26 or later.  Builds targeting iOS 17-25 simulators
// compile cleanly and fall through to the else-branch at runtime.

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
                .background(Color.pepinilloSecondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
            #endif
        } else if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
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

// MARK: - Adaptive Glass Capsule (iOS 26+ interactive, iOS 17-25 ultraThinMaterial)

struct AdaptiveGlassCapsuleModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(true), in: .capsule)
                .glassEffectID(id, in: namespace)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

extension View {
    func adaptiveGlassCapsule(id: String, namespace: Namespace.ID) -> some View {
        modifier(AdaptiveGlassCapsuleModifier(id: id, namespace: namespace))
    }
}

// MARK: - Adaptive Glass Circle

struct AdaptiveGlassCircleModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    var tint: Color?
    var tintOpacity: Double
    var foreground: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            #if os(watchOS)
            content
                .foregroundStyle(foreground ?? .primary)
                .background(tint ?? .black.opacity(0.18), in: Circle())
                .contentShape(Circle())
            #else
            content
                .foregroundStyle(foreground ?? .primary)
                .background(tint ?? Color.pepinilloSecondarySystemGroupedBackground, in: Circle())
                .contentShape(Circle())
            #endif
        } else if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            content
                .foregroundStyle(foreground ?? .primary)
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint((tint ?? .clear).opacity(tint == nil ? 0 : tintOpacity)),
                    in: .circle
                )
                .glassEffectID(id, in: namespace)
                .contentShape(Circle())
        } else if let tint {
            content
                .foregroundStyle(foreground ?? .white)
                .background(tint.gradient, in: Circle())
                .contentShape(Circle())
                .shadow(color: tint.opacity(0.22), radius: 10, y: 5)
        } else {
            content
                .foregroundStyle(foreground ?? .primary)
                .background(.ultraThinMaterial, in: Circle())
                .contentShape(Circle())
        }
    }
}

extension View {
    func adaptiveGlassCircle(
        id: String,
        namespace: Namespace.ID,
        tint: Color? = nil,
        tintOpacity: Double = 0.28,
        foreground: Color? = nil
    ) -> some View {
        modifier(AdaptiveGlassCircleModifier(id: id, namespace: namespace, tint: tint, tintOpacity: tintOpacity, foreground: foreground))
    }
}

// MARK: - Glass Effect ID only

struct GlassEffectIDModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            content
                .glassEffectID(id, in: namespace)
        } else {
            content
        }
    }
}

extension View {
    func startButtonGlassID(namespace: Namespace.ID) -> some View {
        modifier(GlassEffectIDModifier(id: "start-button", namespace: namespace))
    }
}

// MARK: - Sheet Presentation Style

extension View {
    func pepinilloSheetStyle() -> some View {
        self
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
    }
}

// MARK: - Button Style

struct PepinilloButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
