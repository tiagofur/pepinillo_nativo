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
            ScrollView {
                VStack(spacing: 20) {
                    userSection
                    subscriptionSection
                    configurationSection
                    supportSection
                    accountSection
                }
                .padding(.vertical, 20)
            }
            .navigationTitle(String(localized: "More"))
            .background(Color.clear)
        }
    }

    // MARK: - User Section

    @ViewBuilder
    private var userSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.isSignedIn {
                Button {
                    store.send(.showProfile)
                } label: {
                    signedInLabel
                        .padding(18)
                }
                .buttonStyle(.plain)
            } else {
                guestHeader
            }
        }
        .pepinilloGlass()
        .padding(.horizontal, 16)
    }

    private var signedInLabel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                avatarView
                    .accessibilityHidden(true)

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
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                statusChip(
                    systemImage: store.subscriptionState.isPro ? "crown.fill" : "person.crop.circle.badge.checkmark",
                    title: subscriptionLabel,
                    tint: store.subscriptionState.isPro ? .yellow : theme.pomodoroColor
                )
                .accessibilityLabel("\(subscriptionLabel) subscription")

                if store.analytics.currentStreakDays > 0 {
                    statusChip(
                        systemImage: "flame.fill",
                        title: String(localized: "\(store.analytics.currentStreakDays) day streak"),
                        tint: theme.streakColor
                    )
                    .accessibilityLabel("\(store.analytics.currentStreakDays) day streak")
                }
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(signedInAccessibilityLabel)
        .accessibilityHint(String(localized: "a11y.account.profilecard.hint", defaultValue: "Opens your profile"))
        .accessibilityAddTraits(.isButton)
    }

    private var signedInAccessibilityLabel: String {
        var parts: [String] = [signedInDisplayName]
        if let email = signedInEmail { parts.append(email) }
        parts.append(subscriptionLabel)
        if store.analytics.currentStreakDays > 0 {
            parts.append("\(store.analytics.currentStreakDays) day streak")
        }
        return parts.joined(separator: ", ")
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
                    .accessibilityHidden(true)

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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "a11y.account.guest.label", defaultValue: "Not signed in. Set up your profile to save data across devices."))

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
    }

    // MARK: - Subscription

    @ViewBuilder
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "a11y.account.nav.subscription.hint", defaultValue: "Opens subscription plan options"))
        }
        .pepinilloGlass()
        .padding(.horizontal, 16)
    }

    // MARK: - Configuration

    @ViewBuilder
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
            } label: {
                HStack {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "a11y.account.nav.settings.hint", defaultValue: "Opens app settings"))

            Divider()
                .padding(.leading, 52)

            NavigationLink {
                ExportView(isPro: store.subscriptionState.isPro)
            } label: {
                HStack {
                    Label(String(localized: "Export Data"), systemImage: "square.and.arrow.up")
                    Spacer()
                    if !store.subscriptionState.isPro {
                        proBadge
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "a11y.account.nav.export.hint", defaultValue: "Opens data export options"))
        }
        .pepinilloGlass()
        .padding(.horizontal, 16)
    }

    // MARK: - Support

    @ViewBuilder
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                HelpSupportView()
            } label: {
                HStack {
                    Label(String(localized: "Help & Support"), systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "a11y.account.nav.help.hint", defaultValue: "Opens help and support resources"))

            Divider()
                .padding(.leading, 52)

            NavigationLink {
                AboutView(store: Store(initialState: AboutFeature.State()) { AboutFeature() })
            } label: {
                HStack {
                    Label(String(localized: "About Pepinillo"), systemImage: "info.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "a11y.account.nav.about.hint", defaultValue: "Opens information about this app"))
        }
        .pepinilloGlass()
        .padding(.horizontal, 16)
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        if store.isSignedIn {
            VStack(alignment: .leading, spacing: 0) {
                Button(role: .destructive) {
                    store.send(.signOutTapped)
                } label: {
                    Label(String(localized: "Sign Out"), systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "a11y.account.signout.label", defaultValue: "Sign out"))
                .accessibilityHint(String(localized: "a11y.account.signout.hint", defaultValue: "Ends your session on this device"))
            }
            .pepinilloGlass()
            .padding(.horizontal, 16)
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
