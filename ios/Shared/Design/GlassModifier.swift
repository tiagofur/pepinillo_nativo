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
    func systemContentBackground(grouped: Bool = false) -> some View {
        self.background(
            grouped ? Color.pepinilloSystemGroupedBackground : Color.pepinilloSystemBackground,
            ignoresSafeAreaEdges: .all
        )
    }
    #endif
}

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
