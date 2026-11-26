// EnergySuggestionPrompt.swift
// Pepinillo — Deep Work Companion for Apple
//
// Issue #990: the hour-based energy suggestion promoted from an informative
// banner to an actionable filter (S2–S4). Shared by Plan on iOS and macOS.
//
// UX brief (issue comment): same anatomy as the existing EnergySuggestionBanner
// (rounded 12, level tint, icon + "X · suggested now" + reason); tap anywhere
// filters the list to that level; while active the same surface becomes the
// active-filter bar ("Filtered by X · Show all ✕"); hidden when the level has
// no candidate tasks in Today (S3); dismiss (✕) only hides the suggestion for
// the session. Level tint only — never the brand green.

import SwiftUI
import ComposableArchitecture

struct EnergySuggestionPrompt: View {
    let suggestedLevel: EnergyLevel
    let hour: Int
    let isActive: Bool
    let hasCandidates: Bool
    let onFilter: () -> Void
    let onClear: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        if hasCandidates {
            if isActive {
                activeBar
            } else {
                promptButton
            }
        }
    }

    // Tap target: the whole banner filters (S4). ≥44 pt tall (S7).
    private var promptButton: some View {
        Button {
            onFilter()
            HapticManager.impact(.light)
        } label: {
            bannerContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Filter by \(suggestedLevel.displayName)"))
        .accessibilityHint(Text(suggestionReason))
    }

    private var activeBar: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestedLevel.icon)
                .font(.title3)
                .foregroundStyle(suggestedLevel.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                (Text(suggestedLevel.displayName)
                    .foregroundStyle(suggestedLevel.color)
                + Text(String(localized: " · showing only this level"))
                    .foregroundStyle(.secondary))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 0)

            Button {
                onClear()
                HapticManager.selection()
            } label: {
                Text(String(localized: "Show all"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(suggestedLevel.color)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Show all levels"))

            Button {
                onDismiss()
                HapticManager.impact(.light)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.quaternary, in: Circle())
                    .frame(minWidth: 44, minHeight: 44)  // HIG 44pt minimum (issue #90)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Dismiss energy suggestion"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(suggestedLevel.color.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(suggestedLevel.color.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.opacity)
        .accessibilityElement(children: .contain)
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            Image(systemName: suggestedLevel.icon)
                .font(.title3)
                .foregroundStyle(suggestedLevel.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                (Text(suggestedLevel.displayName)
                    .foregroundStyle(suggestedLevel.color)
                + Text(String(localized: " · suggested now"))
                    .foregroundStyle(.secondary))
                    .font(.subheadline.weight(.semibold))

                Text(EnergySuggestion.suggestionReason(forHour: hour))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(6)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(suggestedLevel.color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(suggestedLevel.color.opacity(0.22), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }

    private var suggestionReason: String {
        EnergySuggestion.suggestionReason(forHour: hour)
    }
}
