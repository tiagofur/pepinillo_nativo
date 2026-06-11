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
                .foregroundStyle(Color.accentColor)

            Text(String(localized: "datamerge.title", defaultValue: "Local Data Found"))
                .font(.title2.bold())

            Text(String(localized: "datamerge.body", defaultValue: "You have data on this device that hasn't been synced. Would you like to merge it with your account, or start fresh with your account data?"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Button(String(localized: "datamerge.merge.button", defaultValue: "Merge Data")) { onMerge() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)

                Button(String(localized: "datamerge.accountonly.button", defaultValue: "Use Account Only")) { onUseAccountOnly() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
            }
        }
        .padding(24)
    }
}
