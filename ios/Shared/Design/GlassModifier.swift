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

// MARK: - Liquid Background

struct PepinilloLiquidBackground: View {
    @Environment(\.appTheme) private var theme
    @State private var animate = false

    var body: some View {
        ZStack {
            // Base background
            Group {
                #if os(watchOS)
                Color.black
                #else
                Color(.systemBackground)
                #endif
            }
            .ignoresSafeArea()

            // Animated Blobs
            GeometryReader { geo in
                ZStack {
                    blob(
                        color: theme.pomodoroColor.opacity(0.15),
                        size: geo.size.width * 0.8,
                        offset: animate ? CGSize(width: -20, height: -40) : CGSize(width: 20, height: 40)
                    )
                    .position(x: geo.size.width * 0.2, y: geo.size.height * 0.2)

                    blob(
                        color: theme.flowtimeColor.opacity(0.12),
                        size: geo.size.width * 0.7,
                        offset: animate ? CGSize(width: 30, height: 20) : CGSize(width: -30, height: -20)
                    )
                    .position(x: geo.size.width * 0.8, y: geo.size.height * 0.4)

                    blob(
                        color: theme.streakColor.opacity(0.1),
                        size: geo.size.width * 0.9,
                        offset: animate ? CGSize(width: -10, height: 50) : CGSize(width: 10, height: -50)
                    )
                    .position(x: geo.size.width * 0.4, y: geo.size.height * 0.8)
                }
                .blur(radius: 60)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }

    private func blob(color: Color, size: CGFloat, offset: CGSize) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(offset)
    }
}


