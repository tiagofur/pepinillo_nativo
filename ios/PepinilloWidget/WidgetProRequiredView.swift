// WidgetProRequiredView.swift
// Pepinillo — Deep Work Companion for Apple

import SwiftUI
import WidgetKit

struct WidgetProRequiredView: View {
    let title: String

    var body: some View {
        VStack(spacing: SpacingTokens.sm) {
            Image(systemName: "lock.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(localized: "Pepinillo+ required"))
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(String(localized: "Upgrade to Pepinillo+ to unlock"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(0)
    }
}
