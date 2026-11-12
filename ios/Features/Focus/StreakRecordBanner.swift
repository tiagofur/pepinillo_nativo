// StreakRecordBanner.swift
// Pepinillo — Deep Work Companion for Apple
//
// Quiet non-blocking banner shown on the Focus stage when a session sets a new
// streak record but the post-session journal is disabled (#734). Mirrors the
// ModeIntelligenceBanner idiom — minus the dismiss button: the reducer
// auto-dismisses it after 8 s and a tap dismisses too, so it never asks for
// attention louder than the suggestion banner does. Compiles on macOS too
// (the Mac target includes Features/) — no direct UIKit calls.

import SwiftUI
import ComposableArchitecture

struct StreakRecordBanner: View {
    let days: Int
    let onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .foregroundStyle(theme.streakColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "streakrecord.banner.title", defaultValue: "New record"))
                    .font(.subheadline.weight(.semibold))
                Text(String(localized: "%lld day streak"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: GlassCornerRadius.tile)
                .fill(theme.streakColor.opacity(0.10))
        )
        .contentShape(RoundedRectangle(cornerRadius: GlassCornerRadius.tile))
        .onTapGesture {
            // Tap-to-dismiss — the banner must not require finding a button.
            onDismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "New record: \(days) day streak. Your longest streak yet."))
        .task {
            #if os(iOS)
            // The banner appears without a modal — VoiceOver needs an explicit
            // announcement to know it exists.
            UIAccessibility.post(
                notification: .announcement,
                argument: String(localized: "New record: \(days) day streak. Your longest streak yet.")
            )
            #endif
        }
        .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
    }
}
