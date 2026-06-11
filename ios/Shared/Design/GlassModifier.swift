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

    /// Logical phase [0, 1] that drives mesh point offsets.
    /// Updated by TimelineView at 2s intervals so the gradient drifts slowly and
    /// the system can idle between frames (no 60fps animation loop).
    @State private var phase: Double = 0
    /// Raw reference time from the first timeline beat; used to compute smooth phase.
    @State private var referenceDate: Date? = nil

    // Full drift period: 30 s forward + 30 s back = 60 s cycle (matches old duration).
    private static let cycleDuration: TimeInterval = 60

    var body: some View {
        ZStack {
            baseLayer

            if !reduceTransparency {
                if reduceMotion {
                    // Static snapshot at phase = 0 — no animation, no timeline.
                    atmosphericLayer(phase: 0)
                        .opacity(atmosphereOpacity)
                } else {
                    // TimelineView fires every 2 s while the view is visible, then
                    // suspends automatically when the view disappears — no runaway
                    // 60fps display link.
                    TimelineView(.periodic(from: .now, by: 2)) { context in
                        atmosphericLayer(phase: currentPhase(at: context.date))
                            .opacity(atmosphereOpacity)
                            // Interpolate smoothly between 2s beats so the drift looks
                            // continuous rather than stepped.
                            .animation(.smooth(duration: 2), value: phase)
                    }
                    .onAppear { referenceDate = .now }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// Maps wall-clock time to a phase value that ping-pongs 0 → 1 → 0 over `cycleDuration`.
    private func currentPhase(at date: Date) -> Double {
        let ref = referenceDate ?? date
        let elapsed = date.timeIntervalSince(ref).truncatingRemainder(dividingBy: Self.cycleDuration)
        let half = Self.cycleDuration / 2
        // 0…half → 0…1, half…cycle → 1…0
        return elapsed < half ? elapsed / half : 2 - elapsed / half
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
    private func atmosphericLayer(phase p: Double) -> some View {
        if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *) {
            meshGradient(phase: p)
        } else {
            linearFallback(phase: p)
        }
    }

    @available(iOS 18.0, macOS 15.0, watchOS 11.0, *)
    private func meshGradient(phase p: Double) -> some View {
        MeshGradient(
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

    private func linearFallback(phase p: Double) -> some View {
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
            .offset(x: p * 20, y: p * -10)

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
            .offset(x: p * -20, y: p * 15)
        }
    }
}
