// WidgetGlassBackground.swift
// Pepinillo — Deep Work Companion for Apple
//
// Shared background for all widgets using Liquid Glass design.
// Optimized for WidgetKit constraints.

import SwiftUI

struct PepinilloWidgetBackground: View {
    let mode: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Base layer
            #if os(watchOS)
            Color.black
            #else
            Color.pepinilloSystemBackground
            #endif

            // Liquid Atmosphere
            if #available(iOS 18.0, macOS 15.0, watchOS 11.0, *) {
                meshGradient
                    .opacity(colorScheme == .dark ? 0.25 : 0.15)
            } else {
                linearFallback
                    .opacity(colorScheme == .dark ? 0.20 : 0.12)
            }
        }
    }

    private var modeColor: Color {
        if let mode {
            return ModeColors.color(for: mode)
        }
        return .accentColor
    }

    @available(iOS 18.0, macOS 15.0, watchOS 11.0, *)
    private var meshGradient: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: [
                modeColor.opacity(0.6), .clear, modeColor.opacity(0.4),
                .clear, modeColor.opacity(0.2), .clear,
                modeColor.opacity(0.4), .clear, modeColor.opacity(0.5)
            ]
        )
    }

    private var linearFallback: some View {
        LinearGradient(
            colors: [modeColor.opacity(0.3), .clear, modeColor.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension View {
    func pepinilloWidgetBackground(mode: String? = nil) -> some View {
        self.containerBackground(for: .widget) {
            PepinilloWidgetBackground(mode: mode)
        }
    }
}
