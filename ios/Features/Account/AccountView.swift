// AccountView.swift
// Pepinillo — Deep Work Companion for Apple
//
// Fourth tab ("...") — Account & Admin Hub.
// Centralized access to Profile, Settings, Subscription,
// Export, Help, and About. All options push as full-screen
// destinations in the NavigationStack.

import SwiftUI
import AuthenticationServices
import ComposableArchitecture

struct AccountView: View {
    @Bindable var store: StoreOf<AppFeature>
    @Environment(\.appTheme) private var theme
    @State private var currentAppleNonce = ""

    var body: some View {
        NavigationStack {
            List {
                userSection
                subscriptionSection
                configurationSection
                supportSection
                accountSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(String(localized: "More"))
        }
    }

    // MARK: - User Section

    @ViewBuilder
    private var userSection: some View {
        Section {
            if store.isSignedIn {
                Button {
                    store.send(.showProfile)
                } label: {
                    signedInLabel
                }
                .buttonStyle(.plain)
            } else {
                guestHeader
            }
        }
    }

    private var signedInLabel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                avatarView

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(signedInDisplayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if store.subscriptionState.isPro {
                            proBadge
                        }
                    }

                    if let email = signedInEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(String(localized: "Profile, subscription, and sync settings"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                statusChip(
                    systemImage: store.subscriptionState.isPro ? "crown.fill" : "person.crop.circle.badge.checkmark",
                    title: subscriptionLabel,
                    tint: store.subscriptionState.isPro ? .yellow : theme.pomodoroColor
                )

                if store.analytics.currentStreakDays > 0 {
                    statusChip(
                        systemImage: "flame.fill",
                        title: String(localized: "\(store.analytics.currentStreakDays) day streak"),
                        tint: theme.streakColor
                    )
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.12),
                            Color(.secondarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var guestHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Circle()
                    .fill(theme.pomodoroColor.opacity(0.14))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundStyle(theme.pomodoroColor)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(String(localized: "Set up your profile"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(String(localized: "Add your name, account, and subscription details now so More is ready for sync."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SignInWithAppleButton(.continue) { request in
                let nonce = AppleAuthHelper.generateNonce()
                currentAppleNonce = nonce
                request.nonce = AppleAuthHelper.sha256Hex(nonce)
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                        store.send(.signInWithAppleFailed)
                        return
                    }
                    guard !currentAppleNonce.isEmpty else {
                        store.send(.signInWithAppleFailed)
                        return
                    }

                    let identityToken = credential.identityToken
                        .flatMap { String(data: $0, encoding: .utf8) }

                    store.send(.signInWithAppleSucceeded(
                        AppleUserInfo(
                            userID: credential.user,
                            displayName: credential.fullName?.formatted(),
                            email: credential.email,
                            identityToken: identityToken,
                            nonce: currentAppleNonce
                        )
                    ))
                    currentAppleNonce = ""

                case .failure:
                    currentAppleNonce = ""
                    store.send(.signInWithAppleFailed)
                }
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 46)

            Button {
                store.send(.showAuth)
            } label: {
                Label(String(localized: "Use Email or Create Account"), systemImage: "envelope.badge")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.pomodoroColor.opacity(0.10),
                            Color(.secondarySystemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(theme.pomodoroColor.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Subscription

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            NavigationLink {
                PaywallContent(
                    store: Store(initialState: PaywallFeature.State()) {
                        PaywallFeature()
                    }
                )
            } label: {
                HStack {
                    Label {
                        Text(String(localized: "Subscription"))
                    } icon: {
                        Image(systemName: store.subscriptionState.isPro ? "crown.fill" : "crown")
                            .foregroundStyle(store.subscriptionState.isPro ? .yellow : .secondary)
                    }

                    Spacer()

                    Text(subscriptionLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configurationSection: some View {
        Section {
            NavigationLink {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            } label: {
                Label(String(localized: "Settings"), systemImage: "gearshape")
            }

            NavigationLink {
                ExportView(isPro: store.subscriptionState.isPro)
            } label: {
                HStack {
                    Label(String(localized: "Export Data"), systemImage: "square.and.arrow.up")
                    Spacer()
                    if !store.subscriptionState.isPro {
                        proBadge
                    }
                }
            }
        }
    }

    // MARK: - Support

    @ViewBuilder
    private var supportSection: some View {
        Section {
            NavigationLink {
                HelpSupportView()
            } label: {
                Label(String(localized: "Help & Support"), systemImage: "questionmark.circle")
            }

            NavigationLink {
                AboutView(store: Store(initialState: AboutFeature.State()) { AboutFeature() })
            } label: {
                Label(String(localized: "About Pepinillo"), systemImage: "info.circle")
            }
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        if store.isSignedIn {
            Section {
                Button(role: .destructive) {
                    store.send(.signOutTapped)
                } label: {
                    Label(String(localized: "Sign Out"), systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var avatarView: some View {
        if let imageReference = store.profileSummaryUser?.imageUrl {
            ProfileAvatarImageView(imageReference: imageReference) {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                    }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            let initials = initialsFrom(store.profileSummaryUser?.name ?? store.profileSummaryUser?.email)
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 56, height: 56)
                .overlay {
                    Text(initials)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }

    private var proBadge: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
    }

    private func initialsFrom(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "?" }
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var signedInDisplayName: String {
        let resolvedName = store.profileSummaryUser?.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let resolvedName, !resolvedName.isEmpty {
            return resolvedName
        }
        return store.profileSummaryUser?.email.components(separatedBy: "@").first
            ?? String(localized: "User")
    }

    private var signedInEmail: String? {
        guard let email = store.profileSummaryUser?.email.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return nil
        }
        return email
    }

    private func statusChip(systemImage: String, title: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return String(localized: "Good morning,")
        case 12..<18: return String(localized: "Good afternoon,")
        default: return String(localized: "Good evening,")
        }
    }

    private var subscriptionLabel: String {
        return store.subscriptionState.tierName
    }
}

// MARK: - PaywallContent
// PaywallView inner content WITHOUT its own NavigationStack.
// Used when pushing from AccountView's existing NavigationStack.

private struct PaywallContent: View {
    @Bindable var store: StoreOf<PaywallFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PaywallHeaderSection()
                PaywallPepinilloPlusSection()
                PaywallEverywhereSection()
                PaywallProductCardsSection(store: store)
                PaywallPurchaseButton(store: store)
                PaywallLegalFooter(store: store)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle(String(localized: "Choose Your Plan"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Close")) { store.send(.closeTapped) }
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                    .accessibilityLabel(String(localized: "Loading purchase options"))
            }
        }
        .alert(
            store.subscriptionState.isPro
                ? String(localized: "Welcome to Pepinillo+!")
                : String(localized: "Purchase Status"),
            isPresented: Binding(
                get: { store.purchaseResult != nil },
                set: { if !$0 { store.send(.alertDismissed) } }
            )
        ) {
            Button(String(localized: "OK")) { store.send(.alertDismissed) }
            if store.purchaseResult?.isSuccess == true {
                Button(String(localized: "Start Focusing")) { store.send(.closeTapped) }
                    .keyboardShortcut(.defaultAction)
            }
        } message: {
            Text(store.purchaseResult?.message ?? "")
        }
        .task { store.send(.appeared) }
    }
}
