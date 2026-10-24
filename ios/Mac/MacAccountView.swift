// MacAccountView.swift
// Pepinillo — native macOS account surface
//
// v1 shipped without an account surface on Mac; this restores it natively.
// Signed-out users get a sign-in entry point; the auth sheet reuses the
// shared AuthView and its AppFeature presentation (`.showAuth`), so tokens,
// RevenueCat linking and post-auth task refresh all flow through the same
// pipeline as iOS.

import ComposableArchitecture
import SwiftUI

struct MacAccountView: View {
    @Bindable var store: StoreOf<AppFeature>

    @Environment(\.appTheme) private var theme

    private var isSignedIn: Bool {
        store.cachedUser != nil || store.userEmail != nil
    }

    var body: some View {
        Group {
            if isSignedIn {
                signedIn
            } else {
                signedOut
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(String(localized: "Account"))
        .sheet(item: $store.scope(state: \.auth, action: \.auth)) { authStore in
            NavigationStack {
                AuthView(
                    store: authStore,
                    onAppleSignIn: { info in
                        store.send(.signInWithAppleSucceeded(info))
                    },
                    onAppleSignInFailed: { cancelled in
                        store.send(.signInWithAppleFailed(wasUserCancelled: cancelled))
                    }
                )
            }
            .frame(minWidth: 420, minHeight: 520)
        }
    }

    // MARK: - Signed out

    private var signedOut: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Sign in to Pepinillo")
                .font(.title2.weight(.semibold))

            Text("Sync your tasks and sessions across your iPhone, iPad and Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Button {
                store.send(.showAuth)
            } label: {
                Label("Sign in", systemImage: "person.crop.circle.badge.checkmark")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
    }

    // MARK: - Signed in

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                initialAvatar
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.displayName ?? String(localized: "Signed in"))
                        .font(.title3.weight(.semibold))
                    if let email = store.userEmail {
                        Text(email)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            Divider()

            entitlementRow

            Spacer()

            Button(role: .destructive) {
                confirmSignOut = true
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .confirmationDialog(
                String(localized: "Sign out confirmation", defaultValue: "Sign out of Pepinillo? Your tasks stay on this Mac."),
                isPresented: $confirmSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign out", role: .destructive) {
                    store.send(.signOutTapped)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(32)
        .frame(maxWidth: 560, alignment: .leading)
    }

    @State private var confirmSignOut = false

    private var initialAvatar: some View {
        let initial = String((store.displayName ?? store.userEmail ?? "P").prefix(1)).uppercased()
        return Text(initial)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 56, height: 56)
            .background(Circle().fill(Color.accentColor))
            .accessibilityHidden(true)
    }

    private var entitlementRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(theme.streakColor)
                .accessibilityHidden(true)
            if store.subscriptionState.isPro {
                Text("Pepinillo+")
                    .font(.callout.weight(.semibold))
                Text(String(localized: "Active"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pepinillo \(appVersion)")
                    .font(.callout)
                Button("Upgrade to Pepinillo+") {
                    store.send(.upgradeTapped)
                }
                .buttonStyle(.link)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}
