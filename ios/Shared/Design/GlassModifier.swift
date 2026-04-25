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

// MARK: - Adaptive Glass Capsule (iOS 26+ interactive, iOS 17-25 ultraThinMaterial)
//
// On iOS 26+: applies .glassEffect(.interactive, in: .capsule) with a shared
// glassEffectID so multiple controls inside a GlassEffectContainer morph
// fluidly together (connected refraction between state changes).
// On iOS 17-25: falls back to .ultraThinMaterial in a Capsule shape.
//
// Usage: add .adaptiveGlassCapsule(id: "unique-id", namespace: glassNS)
// to each interactive control inside the Focus core column.

private struct AdaptiveGlassCapsuleModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, watchOS 26.0, *) {
            content
                .glassEffect(.regular, in: .capsule)
                .glassEffectID(id, in: namespace)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

extension View {
    /// On iOS 26+: interactive capsule glass with glassEffectID for fluid morphing inside a GlassEffectContainer.
    /// On iOS 17-25: ultraThinMaterial capsule fallback.
    func adaptiveGlassCapsule(id: String, namespace: Namespace.ID) -> some View {
        modifier(AdaptiveGlassCapsuleModifier(id: id, namespace: namespace))
    }
}

// MARK: - Glass Effect ID only (for controls with their own styled background)
//
// Use when a control already has a fully styled background (e.g. colored gradient + clipShape)
// and should participate in GlassEffectContainer morphing without replacing its background.

private struct GlassEffectIDModifier: ViewModifier {
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
    /// On iOS 26+: register this view in the shared glass namespace for morphing, without applying a glass background.
    /// Use for controls that already have a custom styled background (colored gradient, etc.).
    func startButtonGlassID(namespace: Namespace.ID) -> some View {
        modifier(GlassEffectIDModifier(id: "start-button", namespace: namespace))
    }
}

// MARK: - Sheet Presentation Style
//
// Unifies modal chrome across the app: regular material background,
// 28pt corner radius, and visible drag indicator.
// Apply on the ROOT content of every .sheet presentation.
// Composes safely with .presentationDetents([...]), .iPadSheetSizing(),
// and .interactiveDismissDisabled().

extension View {
    /// Applies standard Pepinillo sheet chrome: .regularMaterial bg, 28pt corner radius, visible drag indicator.
    func pepinilloSheetStyle() -> some View {
        self
            .presentationBackground(.regularMaterial)
            .presentationCornerRadius(28)
            .presentationDragIndicator(.visible)
    }
}

// MARK: - Tab Scene Background
//
// Wraps the view in a ZStack with PepinilloLiquidBackground at the base.
// Use on EACH Tab's content because iOS 26's .tabViewStyle(.sidebarAdaptable)
// renders each tab in its own scene that paints systemBackground — which
// would otherwise hide the AppView root liquid background.

extension View {
    func withAmbientBackground() -> some View {
        ZStack {
            PepinilloLiquidBackground()
                .ignoresSafeArea()
            self
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if !os(watchOS)
    /// Apple-native content background for non-atmospheric screens.
    /// Use systemGroupedBackground for grouped lists/Forms (Plan, Dashboard, More, Settings family).
    /// Use systemBackground for plain content (Onboarding, Paywall, detail views).
    func systemContentBackground(grouped: Bool = false) -> some View {
        self.background(
            grouped ? Color(.systemGroupedBackground) : Color(.systemBackground),
            ignoresSafeAreaEdges: .all
        )
    }
    #endif
}

// MARK: - Ambient Background (PepinilloLiquidBackground)
//
// iOS 18+: animated MeshGradient 3×3, colors from the active AppTheme.
// iOS 17: two blurred cross-LinearGradients (same atmospheric intent).
// Accessibility: Reduce Motion freezes the phase. Reduce Transparency
//               falls back to a flat system background.
//
// Applied once at the AppView ZStack root — no per-screen duplication.

struct PepinilloLiquidBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: Double = 0

    var body: some View {
        ZStack {
            baseLayer

            if !reduceTransparency {
                atmosphericLayer
                    .opacity(atmosphereOpacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.smooth(duration: 30).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    // MARK: - Layers

    private var baseLayer: some View {
        #if os(watchOS)
        Color.black
        #else
        // Match systemBackground so Focus feels visually continuous with the
        // other neutral-bg screens — only a hint of atmosphere on top.
        Color(.systemBackground)
        #endif
    }

    private var atmosphereOpacity: Double {
        // Very subtle: barely visible tint. Mindfulness-level calm.
        colorScheme == .dark ? 0.22 : 0.12
    }

    @ViewBuilder
    private var atmosphericLayer: some View {
        if #available(iOS 18.0, watchOS 11.0, *) {
            meshGradient
        } else {
            linearFallback
        }
    }

    // MARK: - iOS 18+ MeshGradient

    @available(iOS 18.0, watchOS 11.0, *)
    private var meshGradient: some View {
        let p = phase
        return MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0],                          [Float(0.5 + 0.05 * p), 0.0],       [1.0, 0.0],
                [0.0, Float(0.5 - 0.05 * p)],        [0.5, 0.5],                           [1.0, Float(0.5 + 0.05 * p)],
                [0.0, 1.0],                          [Float(0.5 - 0.05 * p), 1.0],        [1.0, 1.0]
            ],
            colors: [
                theme.pomodoroColor.opacity(0.6),  theme.streakColor.opacity(0.5),    theme.flowtimeColor.opacity(0.55),
                theme.flowtimeColor.opacity(0.5),  theme.pomodoroColor.opacity(0.4),  theme.timeBlockColor.opacity(0.5),
                theme.timeBlockColor.opacity(0.55), theme.flowtimeColor.opacity(0.5), theme.streakColor.opacity(0.5)
            ]
        )
    }

    // MARK: - iOS 17 fallback

    private var linearFallback: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.pomodoroColor.opacity(0.4),
                    Color.clear,
                    theme.flowtimeColor.opacity(0.35)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 70)
            .offset(x: phase * 20, y: phase * -10)

            LinearGradient(
                colors: [
                    theme.streakColor.opacity(0.3),
                    Color.clear,
                    theme.timeBlockColor.opacity(0.3)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .blur(radius: 70)
            .offset(x: phase * -20, y: phase * 15)
        }
    }
}


