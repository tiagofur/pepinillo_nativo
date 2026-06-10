// GlassModifier.swift
// Pepinillo — Deep Work Companion for Apple
//
// Atmospheric backgrounds for the App.
// (Liquid MeshGradient depends on AppTheme environment).

import SwiftUI

// MARK: - Tab Scene Background

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
    ///
    /// On iOS 26+ we deliberately do NOT apply an opaque full-screen background on
    /// TabView child views.  The system Liquid Glass tab bar composites a blur of
    /// whatever sits behind the bar — an opaque `.all`-edge fill blocks that path and
    /// forces the bar to render as plain white.  Instead we let the system material
    /// show through and only paint the content area (safe area insets, NOT the
    /// tab-bar region).  On iOS 17-25 the old full-bleed behavior is preserved.
    func systemContentBackground(grouped: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            // On iOS 26+: let the system glass bar look through — no opaque fill
            // behind the bar.  Apply the color only to the safe-area content area.
            return self.background(
                grouped ? Color.pepinilloSystemGroupedBackground : Color.pepinilloSystemBackground
            )
        } else {
            return self.background(
                grouped ? Color.pepinilloSystemGroupedBackground : Color.pepinilloSystemBackground,
                ignoresSafeAreaEdges: .all
            )
        }
    }
    #endif
}

// MARK: - iOS 26 Scroll Edge Effect

#if !os(watchOS)
extension View {
    /// Applies a soft scroll-edge effect at the top of a scroll view on iOS 26+.
    /// No-op on earlier OS versions.
    @ViewBuilder
    func primaryScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}
#endif

// MARK: - iOS 26 Tab Bar Minimize Behavior

#if !os(watchOS)
extension View {
    /// Hides/minimizes the tab bar when the user scrolls down (iOS 26+).
    /// No-op on earlier OS versions — no availability guard at call site required.
    @ViewBuilder
    func conditionalTabBarMinimize() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
#endif

// MARK: - Ambient Background (PepinilloLiquidBackground)

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

    private var baseLayer: some View {
        #if os(watchOS)
        Color.black
        #else
        Color.pepinilloSystemBackground
        #endif
    }

    private var atmosphereOpacity: Double {
        colorScheme == .dark ? 0.22 : 0.12
    }

    @ViewBuilder
    private var atmosphericLayer: some View {
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *) {
            meshGradient
        } else {
            linearFallback
        }
    }

    @available(iOS 18.0, macOS 15.0, watchOS 11.0, *)
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
