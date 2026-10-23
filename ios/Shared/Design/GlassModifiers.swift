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
    var tint: Color? = nil
    var tintOpacity: Double = 0.08
    
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if reduceTransparency {
            #if os(watchOS)
            if let tint {
                content
                    .background(tint, in: RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                content
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            }
            #else
            content
                .background(tint?.opacity(tintOpacity) ?? Color.pepinilloSecondarySystemGroupedBackground, in: RoundedRectangle(cornerRadius: cornerRadius))
            #endif
        } else if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            // System Liquid Glass already renders its own specular highlights;
            // the hand-rolled glare overlays are only for the pre-26 material
            // fallback (stacking them over real glass read as fake gloss).
            content
                .glassEffect(
                    .regular
                        .tint((tint ?? .clear).opacity(tint == nil ? 0 : tintOpacity)),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .background(tint?.opacity(tintOpacity) ?? .clear, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    specularHighlight(cornerRadius: cornerRadius)
                }
                .overlay {
                    glareSheen(cornerRadius: cornerRadius)
                }
        }
    }

    @ViewBuilder
    private func specularHighlight(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(
                LinearGradient(
                    colors: [
                        .white.opacity(colorScheme == .dark ? 0.24 : 0.40),
                        .white.opacity(colorScheme == .dark ? 0.08 : 0.15),
                        .clear,
                        .white.opacity(colorScheme == .dark ? 0.04 : 0.10),
                        .white.opacity(colorScheme == .dark ? 0.16 : 0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func glareSheen(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(colorScheme == .dark ? 0.03 : 0.06),
                        .clear,
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }
}

extension View {
    func pepinilloGlass(
        cornerRadius: CGFloat = 24,
        tint: Color? = nil,
        tintOpacity: Double = 0.08
    ) -> some View {
        modifier(PepinilloGlassModifier(cornerRadius: cornerRadius, tint: tint, tintOpacity: tintOpacity))
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

// MARK: - Matte Content Card (macOS content areas)

/// The macOS 26 material rule: Liquid Glass belongs to chrome and floating
/// standout controls; content areas stay matte. Dashboard/stat cards use this
/// instead of `pepinilloGlass` so they sit quietly under the window's real
/// glass toolbar (and still read as cards via the grouped background fill).
struct PepinilloMatteCardModifier: ViewModifier {
    // Literal (not GlassCornerRadius.card) because this file also compiles
    // into widget/CC targets that don't include GlassTokens.swift. The value
    // mirrors the card token.
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                matteFill,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }

    private var matteFill: Color {
        #if os(watchOS)
        // The system-color extension is gated to !os(watchOS); watch never
        // renders matte content cards, this only keeps the file compiling.
        Color.white.opacity(0.12)
        #else
        Color.pepinilloSecondarySystemGroupedBackground
        #endif
    }
}

extension View {
    func pepinilloMatteCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(PepinilloMatteCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Primary Focus Action (shared iOS + macOS hero CTA)

/// Solid mode-accent CTA — confident fill on every OS generation.
/// iOS/macOS 26: tinted glass at 0.72 opacity so the mode color reads strongly
///               over the Liquid Glass system while preserving the glass language.
/// Earlier: solid gradient fill with drop shadow.
extension View {
    @ViewBuilder
    func primaryFocusActionGlass(tint: Color, namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            self
                .foregroundStyle(.white)
                .glassEffect(
                    .regular
                        .interactive(true)
                        .tint(tint.opacity(0.72)),
                    in: .capsule
                )
                .glassEffectID("start-button", in: namespace)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
        } else {
            self
                .foregroundStyle(.white)
                .background(tint.gradient)
                .clipShape(Capsule())
                .shadow(color: tint.opacity(0.35), radius: 14, y: 7)
        }
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
