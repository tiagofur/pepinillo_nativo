// AboutView.swift
// Pepinillo — Deep Work Companion for Apple
//
// About screen: app identity, subscription status, and legal links.

import SwiftUI
import ComposableArchitecture

struct AboutView: View {
    let store: StoreOf<AboutFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            // MARK: App Identity
            Section {
                HStack(spacing: 14) {
                    if let icon = UIImage(named: "AppIcon") {
                        Image(uiImage: icon)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 32))
                            .frame(width: 60, height: 60)
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pepinillo")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(String(localized: "Deep Work Companion"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Version \(store.appVersion) (\(store.buildNumber))"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: Subscription
            Section {
                if store.isProUser {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text(String(localized: "Pepinillo Pro"))
                            .fontWeight(.medium)
                        Spacer()
                        Text(String(localized: "Active"))
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                } else {
                    HStack {
                        Image(systemName: "star.circle")
                            .foregroundStyle(.secondary)
                        Text(String(localized: "Pepinillo Free"))
                            .fontWeight(.medium)
                    }
                }
            }

            // MARK: Legal
            Section {
                Button {
                    store.send(.privacyPolicyTapped)
                } label: {
                    HStack {
                        Label(String(localized: "Privacy Policy"), systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)

                Button {
                    store.send(.termsOfServiceTapped)
                } label: {
                    HStack {
                        Label(String(localized: "Terms of Service"), systemImage: "doc.plaintext")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text(String(localized: "Legal"))
            }
        }
        .navigationTitle(String(localized: "About"))
    }
}
