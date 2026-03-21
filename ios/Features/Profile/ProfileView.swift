// ProfileView.swift
// Pepinillo — Deep Work Companion for Apple
//
// SwiftUI view for the user profile screen.
// Shows user card, lifetime stats, and account actions.

import SwiftUI
import ComposableArchitecture

// MARK: - ProfileView

struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                Text("Profile")
                    .font(.title.bold())
                Text("Your productivity journey")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // User card
                userCard

                // Stats
                statsSection

                // Account actions
                accountSection

                // Footer
                Text("Pepinillo v1.0.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.onAppear) }
        .sheet(item: $store.scope(state: \.editProfile, action: \.editProfile)) { editStore in
            NavigationStack {
                EditProfileView(store: editStore)
            }
        }
    }

    // MARK: - User Card

    @ViewBuilder
    private var userCard: some View {
        HStack(spacing: 16) {
            if let imageUrl = store.user?.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.fill").font(.title).foregroundStyle(.secondary)
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "person.fill").font(.title).foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(store.user?.name ?? "Guest User")
                        .font(.title3.weight(.semibold))

                    if store.user != nil {
                        Button { store.send(.editProfileTapped) } label: {
                            Image(systemName: "pencil")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text(store.user?.email ?? "Sign in to sync your data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Stats Section

    @ViewBuilder
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lifetime Stats")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            HStack(spacing: 12) {
                StatMiniCard(
                    icon: "timer",
                    value: "\(store.totalFocusMinutes / 60)h",
                    label: "Focus time"
                )
                StatMiniCard(
                    icon: "checkmark.circle",
                    value: "\(store.totalSessions)",
                    label: "Sessions"
                )
                StatMiniCard(
                    icon: "flame",
                    value: "\(store.bestStreak)",
                    label: "Best streak"
                )
            }
        }
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            VStack(spacing: 0) {
                if store.user != nil {
                    ActionRow(
                        icon: "arrow.right.square",
                        label: "Sign Out",
                        subtitle: store.user?.email ?? "",
                        isLoading: store.isLoading
                    ) {
                        store.send(.signOutTapped)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

// MARK: - StatMiniCard

private struct StatMiniCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

// MARK: - ActionRow

private struct ActionRow: View {
    let icon: String
    let label: String
    let subtitle: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.body)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
