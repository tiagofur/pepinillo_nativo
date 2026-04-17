// DrawerView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Side drawer overlay. Slides in from the left on top of the TabView.
// Triggered by the hamburger button in the navigation bar.

import SwiftUI
import ComposableArchitecture

// MARK: - Drawer Overlay Container

struct DrawerOverlayView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        GeometryReader { geo in
            let drawerWidth = min(geo.size.width * 0.78, 340)

            ZStack(alignment: .leading) {
                // Dimmed background
                if store.isDrawerOpen {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            store.send(.drawerClosed, animation: .easeInOut(duration: 0.28))
                        }
                        .transition(.opacity)
                        .zIndex(10)
                        .accessibilityLabel(String(localized: "Close menu"))
                        .accessibilityAddTraits(.isButton)
                }

                // Drawer panel
                if store.isDrawerOpen {
                    DrawerView(store: store)
                        .frame(width: drawerWidth)
                        .transition(.move(edge: .leading))
                        .zIndex(11)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .conditionalAnimation(.easeInOut(duration: 0.28), value: store.isDrawerOpen)
    }
}

// MARK: - Drawer Panel

struct DrawerView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: Header — greeting + sign in
            drawerHeader
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            Divider()

            // MARK: Navigation rows
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    DrawerRow(icon: "calendar.badge.clock", label: String(localized: "Weekly Review")) {
                        store.send(.weeklyReviewDrawerTapped)
                    }

                    DrawerRow(icon: "calendar", label: String(localized: "Calendar")) {
                        store.send(.calendarDrawerTapped)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

            Spacer()

            // MARK: Footer — pinned to bottom
            VStack(alignment: .leading, spacing: 4) {
                Divider()

                if !store.subscriptionState.isPro {
                    DrawerRow(icon: "crown", label: String(localized: "Upgrade to Pro"), accent: true) {
                        store.send(.upgradeDrawerTapped)
                    }
                }

                if store.isSignedIn {
                    DrawerRow(
                        icon: "rectangle.portrait.and.arrow.right",
                        label: String(localized: "Sign out"),
                        destructive: true
                    ) {
                        store.send(.signOutTapped)
                    }
                }

                DrawerRow(icon: "gearshape", label: String(localized: "Settings")) {
                    store.send(.settingsDrawerTapped)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxHeight: .infinity)
        .background {
            Color(.secondarySystemBackground)
                .ignoresSafeArea(edges: .vertical)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var drawerHeader: some View {
        if store.isSignedIn {
            signedInHeader
        } else {
            guestHeader
        }
    }

    @ViewBuilder
    private var signedInHeader: some View {
        Button {
            store.send(.showProfile)
        } label: {
            HStack(spacing: 14) {
                // Avatar with initials
                avatarView

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.displayName ?? store.userEmail?.components(separatedBy: "@").first ?? "Apple User")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let email = store.userEmail, !email.isEmpty {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Streak badge
                    if store.analytics.currentStreakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(theme.streakColor)
                                .accessibilityHidden(true)
                            Text(String(localized: "\(store.analytics.currentStreakDays) day streak"))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.streakColor)
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel(String(localized: "View Profile"))
        .accessibilityHint(String(localized: "Opens your profile"))
    }

    @ViewBuilder
    private var guestHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                // Guest avatar placeholder
                Circle()
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(String(localized: "Pepinillo"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }

            Button {
                store.send(.showAuth)
            } label: {
                Label(String(localized: "Sign In or Create Account"), systemImage: "person.crop.circle.badge.plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        let initials = initialsFrom(store.displayName ?? store.userEmail)
        Circle()
            .fill(Color.accentColor.opacity(0.15))
            .frame(width: 48, height: 48)
            .overlay {
                Text(initials)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
    }

    private func initialsFrom(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    // MARK: - Greeting

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return String(localized: "Good morning,")
        case 12..<18:
            return String(localized: "Good afternoon,")
        default:
            return String(localized: "Good evening,")
        }
    }
}

// MARK: - Drawer Row

private struct DrawerRow: View {
    let icon: String
    let label: String
    var accent: Bool = false
    var destructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 22)
                    .foregroundStyle(destructive ? .red : accent ? Color.accentColor : .primary)
                    .accessibilityHidden(true)
                Text(label)
                    .foregroundStyle(destructive ? .red : .primary)
                Spacer()
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Menu Button (used in nav bar)

struct AvatarNavButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel(String(localized: "Open menu"))
    }
}
