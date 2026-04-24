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
        ZStack {
            PepinilloLiquidBackground()

            Form {
                // Hero header section: avatar + name
                Section {
                    userCard
                }

                // Stats section
                Section(String(localized: "profile.lifetimeStats", defaultValue: "Lifetime Stats")) {
                    statsMiniRow
                }

                // Account section
                if store.user != nil {
                    Section(String(localized: "profile.account.section", defaultValue: "Account")) {
                        Button {
                            store.send(.signOutTapped)
                        } label: {
                            HStack(spacing: 14) {
                                Label(String(localized: "profile.signout.button", defaultValue: "Sign Out"),
                                      systemImage: "arrow.right.square")
                                if store.isLoading {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                        .disabled(store.isLoading)
                        .accessibilityLabel(String(localized: "a11y.account.signout.label", defaultValue: "Sign out"))
                        .accessibilityHint(String(localized: "a11y.account.signout.hint", defaultValue: "Ends your session on this device"))
                    }
                }

                // Footer
                Section {
                    Text("Pepinillo v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
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
            if let imageReference = store.user?.imageUrl {
                ProfileAvatarImageView(imageReference: imageReference) {
                    Image(systemName: "person.fill").font(.title).foregroundStyle(.secondary)
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .accessibilityHidden(true)
            } else {
                Circle()
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "person.fill").font(.title).foregroundStyle(.secondary)
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(store.user?.name ?? "Guest User")
                        .font(.title3.weight(.semibold))

                    if store.user != nil {
                        Button { store.send(.editProfileTapped) } label: {
                            Image(systemName: "pencil")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel(String(localized: "a11y.profile.edit.label", defaultValue: "Edit profile"))
                        .accessibilityHint(String(localized: "a11y.profile.edit.hint", defaultValue: "Opens profile editor"))
                    }
                }

                Text(store.user?.email ?? "Sign in to sync your data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let birthDate = formattedBirthDate {
                    Label(birthDate, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(String(localized: "a11y.profile.birthdate.prefix", defaultValue: "Birth date")): \(birthDate)")
                } else if store.user != nil {
                    Label("Add your birth date manually in Edit Profile", systemImage: "calendar.badge.plus")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if store.user?.appleId != nil {
                    Text(String(localized: "profile.apple.disclaimer", defaultValue: "Apple only shares name and email during authorization. Birth date and photo are managed manually in Pepinillo."))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .accessibilityElement(children: .contain)
    }

    private var formattedBirthDate: String? {
        guard let rawBirthDate = store.user?.birthDate, !rawBirthDate.isEmpty,
              let date = ISO8601DateFormatter().date(from: rawBirthDate) else {
            return nil
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    // MARK: - Stats Mini Row (for Form section)

    @ViewBuilder
    private var statsMiniRow: some View {
        HStack(spacing: 12) {
            StatMiniCard(
                icon: "timer",
                value: "\(store.totalFocusMinutes / 60)h",
                label: "Focus time",
                accessibilityLabel: "Focus time: \(store.totalFocusMinutes / 60) hours"
            )
            StatMiniCard(
                icon: "checkmark.circle",
                value: "\(store.totalSessions)",
                label: "Sessions",
                accessibilityLabel: "Sessions: \(store.totalSessions)"
            )
            StatMiniCard(
                icon: "flame",
                value: "\(store.bestStreak)",
                label: "Best streak",
                accessibilityLabel: "Best streak: \(store.bestStreak) days"
            )
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        .listRowBackground(Color.clear)
        .accessibilityLabel(String(localized: "a11y.profile.lifetimestats.label", defaultValue: "Lifetime statistics"))
    }
}

// MARK: - StatMiniCard

private struct StatMiniCard: View {
    let icon: String
    let value: String
    let label: String
    var accessibilityLabel: String = ""

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
        .pepinilloGlass()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel.isEmpty ? "\(label): \(value)" : accessibilityLabel)
    }
}

