// DataMergeView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Dialog shown when an anonymous user with local data signs into
// an existing account. Offers to merge local data or use account only.

import SwiftUI

struct DataMergeView: View {
    let onMerge: () -> Void
    let onUseAccountOnly: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.accentColor)

            Text("Local Data Found")
                .font(.title2.bold())

            Text("You have data on this device that hasn't been synced. Would you like to merge it with your account, or start fresh with your account data?")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button("Merge Data") { onMerge() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)

                Button("Use Account Only") { onUseAccountOnly() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
        }
        .padding(24)
    }
}
