// DrawerView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Side drawer overlay. Slides in from the left on top of the TabView.
// Triggered by the hamburger button in the navigation bar.

import SwiftUI
import AuthenticationServices
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
        .animation(.easeInOut(duration: 0.28), value: store.isDrawerOpen)
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
                .padding(.horizontal, 20)
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
            Rectangle()
                .pepinilloGlass(cornerRadius: 0)
                .ignoresSafeArea(edges: .vertical)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var drawerHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Time-based greeting
            Text(greeting)
                .font(.title3)
                .foregroundStyle(.secondary)

            // User name or app name
            Text(store.displayName ?? String(localized: "Pepinillo"))
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            // Streak badge
            if store.analytics.currentStreakDays > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(theme.streakColor)
                        .accessibilityHidden(true)

                    Text(String(localized: "\(store.analytics.currentStreakDays) day streak"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.streakColor)
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "\(store.analytics.currentStreakDays) day focus streak"))
            }

            // Sign In with Apple (when not signed in)
            if !store.isSignedIn {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let auth):
                        guard let cred = auth.credential as? ASAuthorizationAppleIDCredential else {
                            store.send(.signInWithAppleFailed)
                            return
                        }
                        let identityToken: String? = cred.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                        store.send(.signInWithAppleSucceeded(AppleUserInfo(
                            userID: cred.user,
                            displayName: cred.fullName?.formatted(),
                            email: cred.email,
                            identityToken: identityToken
                        )))
                    case .failure:
                        store.send(.signInWithAppleFailed)
                    }
                }
                .signInWithAppleButtonStyle(.whiteOutline)
                .frame(height: 44)
                .padding(.top, 8)
            }
        }
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
