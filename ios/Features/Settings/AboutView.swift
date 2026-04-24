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
        ZStack {
            PepinilloLiquidBackground()

            Form {
                // MARK: App Identity (hero header as a section)
                Section {
                    VStack(spacing: 16) {
                        if let icon = UIImage(named: "AppIcon") {
                            Image(uiImage: icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        } else {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 40))
                                .frame(width: 80, height: 80)
                                .foregroundStyle(Color.accentColor)
                                .background(Circle().fill(Color.accentColor.opacity(0.1)))
                        }

                        VStack(spacing: 4) {
                            Text("Pepinillo")
                                .font(.title2.bold())
                                .foregroundStyle(.primary)

                            Text(String(localized: "Deep Work Companion"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(String(localized: "Version \(store.appVersion) (\(store.buildNumber))"))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().stroke(.tertiary, lineWidth: 0.5))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // MARK: Subscription
                Section(String(localized: "Subscription")) {
                    if store.isProUser {
                        LabeledContent {
                            Text(String(localized: "Active"))
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                        } label: {
                            Label {
                                Text(String(localized: "Pepinillo Pro"))
                                    .fontWeight(.medium)
                            } icon: {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                            }
                        }
                    } else {
                        Label {
                            Text(String(localized: "Pepinillo Free"))
                                .fontWeight(.medium)
                        } icon: {
                            Image(systemName: "star.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Legal
                Section(String(localized: "Legal")) {
                    Button {
                        store.send(.privacyPolicyTapped)
                    } label: {
                        Label(String(localized: "Privacy Policy"), systemImage: "doc.text")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        store.send(.termsOfServiceTapped)
                    } label: {
                        Label(String(localized: "Terms of Service"), systemImage: "doc.plaintext")
                            .foregroundStyle(.primary)
                    }
                }

                // Footer
                Section {
                    Text("© \(Calendar.current.component(.year, from: Date())) Creapolis Dev")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle(String(localized: "About"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
