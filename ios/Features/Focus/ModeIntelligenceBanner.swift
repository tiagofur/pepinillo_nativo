// ModeIntelligenceBanner.swift
// Pepinillo — Deep Work Companion for Apple
//
// Non-intrusive banner that appears in FocusView when Mode Intelligence
// has a suggestion for the linked task. Dismissible with a single tap.

import SwiftUI

struct ModeIntelligenceBanner: View {
    let suggestion: ModeSuggestion
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Try \(suggestion.suggestedMode.displayName)"))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button {
                onAccept()
            } label: {
                Image(systemName: suggestion.suggestedMode.systemImage)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                String(
                    format: String(localized: "Accept %@ suggestion"),
                    suggestion.suggestedMode.displayName
                )
            )
            .accessibilityHint(
                String(localized: "Double tap to switch to the suggested focus mode")
            )

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Dismiss suggestion"))
            .accessibilityHint(String(localized: "Double tap to dismiss the mode suggestion"))
        }
        .padding(12)
        .pepinilloGlass(cornerRadius: GlassCornerRadius.tile)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            String(
                format: String(localized: "Mode suggestion: Try %@. %@"),
                suggestion.suggestedMode.displayName,
                suggestion.reason
            )
        )
        .accessibilityHint(
            String(localized: "Accept to switch modes, or dismiss to keep your current selection")
        )
    }
}
