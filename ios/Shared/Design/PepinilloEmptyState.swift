// PepinilloEmptyState.swift
// Pepinillo — Deep Work Companion for Apple
//
// Reusable glass hero empty state for Plan, Dashboard, Achievements, and Export.

import SwiftUI

struct PepinilloEmptyState: View {
    let title: String
    let description: String
    let systemImage: String
    var tint: Color = .accentColor
    var cornerRadius: CGFloat = GlassCornerRadius.hero

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44

    var body: some View {
        VStack(spacing: SpacingTokens.md) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.sm) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, SpacingTokens.xl)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
        .pepinilloGlass(cornerRadius: cornerRadius, tint: tint, tintOpacity: 0.06)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}